#!/usr/bin/env python3
"""Check the exact Git snapshots about to become public, without logging values."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import PurePosixPath
from urllib.parse import urlsplit


MAX_BLOB_BYTES = 2 * 1024 * 1024
HASH = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
MEDIA_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".psd", ".blend",
    ".mp3", ".wav", ".ogg", ".flac", ".m4a", ".mp4", ".mov", ".webm",
    ".zip", ".gz", ".7z", ".pdf", ".docx", ".xlsx", ".pptx",
}
# This package ships text only. There is deliberately no command-line exclusion.
PUBLIC_MEDIA: frozenset[str] = frozenset()
LOCAL_DIRECTORIES = {
    ".aws", ".ssh", ".godot", ".pytest_cache", "__pycache__", "node_modules",
    "local-artifacts", "screenshots", "captures", "test-results", "htmlcov",
    "coverage", "build", "dist", "exports",
}
SENSITIVE_NAME = re.compile(
    r"(?:\.env.*|id_(?:rsa|dsa|ecdsa|ed25519)(?:\..*)?|\.netrc|\.npmrc|"
    r"\.pypirc|\.ds_store|credentials(?:\..*)?|secrets?(?:\..*)?|"
    r"service[-_]account(?:\..*)?|.*\.(?:pem|p12|pfx|key|keystore))\Z", re.I
)
REPORT_NAME = re.compile(
    r"(?:\.coverage.*|(?:test[-_]?report|qa[-_]?report|junit|coverage)(?:[._-].*)?|"
    r".*\.(?:log|junit|sarif))\Z", re.I
)
TOKEN_RULES = (
    ("private-key", re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----")),
    ("provider-token", re.compile(
        r"\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}|"
        r"(?:sk|rk)_live_[A-Za-z0-9]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|"
        r"github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|"
        r"xox[baprs]-[A-Za-z0-9-]{16,}|AIza[A-Za-z0-9_-]{30,}|"
        r"(?:AKIA|ASIA)[A-Z0-9]{16})\b"
    )),
    ("home-path", re.compile(r"/(?:Users|home)/[^/\s\"'<>]+|[A-Za-z]:\\Users\\[^\\\s\"'<>]+")),
)
ASSIGNMENT = re.compile(
    r"(?i)(?<![\w])['\"]?(?:password|passwd|pwd|secret|client_secret|"
    r"api[-_]?key|api[-_]?secret|secret[-_]?key|token|access[-_]?token|refresh[-_]?token|auth[-_]?token|"
    r"private[-_]?key|aws_secret_access_key|database_url|connection_string)"
    r"['\"]?\s*(?::\s*[A-Za-z_]\w*(?:\[[^\]\r\n]+\])?\s*(?==))?(?P<operator>[:=])\s*"
    r"(?:(?P<quote>['\"])(?P<quoted>[^'\"\r\n]*)(?P=quote)|(?P<bare>\$\{[^}\r\n]+\}|[^\s,;#}]+))"
)
CODE_REFERENCE = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*|\[[^\[\]\r\n]+\])*(?:\([^()\r\n]*\))?\Z")
EMAIL = re.compile(r"(?<![\w@])[A-Za-z0-9.!#$%&'*+/=?^_`{|}~\[\]-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
URL = re.compile(r"\b(?:https?|ssh)://[^\s<>\"']+", re.I)
EXAMPLE_NETWORKS = tuple(ipaddress.ip_network(cidr) for cidr in (
    "192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24", "2001:db8::/32",
))


@dataclass(frozen=True)
class Finding:
    rule: str
    line: int = 0


class CheckError(Exception):
    """An operational failure must prevent publication."""


def placeholder(value: str) -> bool:
    normalized = value.strip().strip("`")
    return (
        not normalized
        or normalized in {"...", "***", "REPLACE_ME", "example", "placeholder"}
        or bool(re.fullmatch(r"<[^<>]+>|\$\{[^{}]+\}|\$[A-Za-z_]\w*", normalized))
        or bool(re.fullmatch(r"YOUR_[A-Z0-9_]+", normalized))
    )


def public_email(address: str) -> bool:
    address = address.lower()
    domain = address.rsplit("@", 1)[-1]
    return (
        domain in {"example.com", "example.org", "example.net"}
        or domain.endswith((".example.com", ".example.org", ".example.net"))
        or domain.endswith((".example", ".invalid", ".test"))
        or domain in {"users.noreply.github.com", "noreply.github.com"}
        # Git's public SSH transport account is not a person's address.
        or address in {"git@github.com", "noreply@github.com"}
    )


def content_findings(text: str, suffix: str = "") -> list[Finding]:
    findings: set[Finding] = set()
    for line_no, line in enumerate(text.splitlines(), 1):
        for rule, pattern in TOKEN_RULES:
            if pattern.search(line):
                findings.add(Finding(rule, line_no))
        for match in ASSIGNMENT.finditer(line):
            value = match.group("quoted") if match.group("quote") else match.group("bare")
            if placeholder(value):
                continue
            if not match.group("quote"):
                # Code references and annotations are not literal credentials.
                if suffix in {".py", ".ts", ".js"} and CODE_REFERENCE.fullmatch(value):
                    continue
            findings.add(Finding("credential-assignment", line_no))
        if any(not public_email(match.group()) for match in EMAIL.finditer(line)):
            findings.add(Finding("personal-email", line_no))
        for match in URL.finditer(line):
            try:
                parsed = urlsplit(match.group().rstrip(".,);"))
                host = (parsed.hostname or "").lower().rstrip(".")
                if parsed.password is not None or (parsed.username and parsed.scheme != "ssh"):
                    findings.add(Finding("url-credential", line_no))
                if host == "localhost" or host.endswith((".localhost", ".local", ".internal", ".lan")):
                    findings.add(Finding("private-network-url", line_no))
                else:
                    try:
                        address = ipaddress.ip_address(host)
                    except ValueError:
                        address = None
                    if address is not None and (address.is_private or address.is_loopback or address.is_link_local):
                        if not any(address.version == network.version and address in network for network in EXAMPLE_NETWORKS):
                            findings.add(Finding("private-network-url", line_no))
            except ValueError:
                findings.add(Finding("malformed-url", line_no))
    return sorted(findings, key=lambda item: (item.line, item.rule))


def path_findings(path: str, mode: str) -> list[Finding]:
    parts = PurePosixPath(path).parts
    findings = []
    if mode == "120000":
        findings.append(Finding("symlink"))
    elif mode not in {"100644", "100755"}:
        findings.append(Finding("unsupported-entry"))
    if any(part.lower() in LOCAL_DIRECTORIES for part in parts):
        findings.append(Finding("local-artifact-path"))
    if any(SENSITIVE_NAME.fullmatch(part) for part in parts):
        findings.append(Finding("sensitive-filename"))
    if REPORT_NAME.fullmatch(parts[-1]):
        findings.append(Finding("raw-test-report"))
    if PurePosixPath(path).suffix.lower() in MEDIA_EXTENSIONS and path not in PUBLIC_MEDIA:
        findings.append(Finding("unapproved-media"))
    if any(ord(char) < 32 for char in path):
        findings.append(Finding("control-character-path"))
    findings.extend(Finding("path-" + item.rule) for item in content_findings(path))
    return findings


def safe_path(path: str) -> str:
    if content_findings(path) or any(ord(char) < 32 for char in path):
        digest = hashlib.sha256(path.encode("utf-8", "surrogateescape")).hexdigest()[:12]
        return "<redacted-path:" + digest + ">"
    return path


class Git:
    def __init__(self) -> None:
        self.root: str | None = None

    def run(self, *args: str, data: bytes | None = None) -> bytes:
        try:
            result = subprocess.run(
                ["git", "--no-replace-objects", *(["-C", self.root] if self.root else []), *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                check=False,
            )
        except OSError as error:
            raise CheckError("Git could not be started") from error
        if result.returncode:
            # Git stderr may contain a sensitive ref, remote URL or filename.
            raise CheckError("Git operation failed: " + args[0])
        return result.stdout

    def object_type(self, oid: str) -> str | None:
        output = self.run("cat-file", "--batch-check=%(objecttype)", data=(oid + "\n").encode()).strip()
        if output == (oid + " missing").encode():
            return None
        if output in {b"commit", b"tag", b"blob", b"tree"}:
            return output.decode()
        raise CheckError("Unexpected Git object lookup result")

    def commit_oid(self, revision: str) -> str:
        oid = self.run("rev-parse", "--verify", "--end-of-options", revision + "^{commit}").strip().decode("ascii")
        if not HASH.fullmatch(oid):
            raise CheckError("Unexpected Git revision result")
        return oid


class Scanner:
    def __init__(self) -> None:
        self.git = Git()
        self.errors: set[str] = set()
        self.blobs: dict[tuple[str, str], list[Finding]] = {}
        self.commits: set[str] = set()
        self.entries = 0

    def report(self, location: str, findings: list[Finding]) -> None:
        for finding in findings:
            line = ":" + str(finding.line) if finding.line else ""
            self.errors.add(location + line + " [" + finding.rule + "]")

    def blob_findings(self, oid: str, suffix: str) -> list[Finding]:
        key = (oid, suffix)
        if key not in self.blobs:
            size = int(self.git.run("cat-file", "-s", oid).strip())
            if size > MAX_BLOB_BYTES:
                findings = [Finding("oversized-file")]
            else:
                data = self.git.run("cat-file", "blob", oid)
                try:
                    text = data.decode("utf-8")
                    findings = [Finding("binary-file")] if b"\0" in data else content_findings(text, suffix)
                except UnicodeDecodeError:
                    findings = [Finding("non-utf8-file")]
            self.blobs[key] = findings
        return self.blobs[key]

    def entry(self, context: str, mode: str, oid: str, path_bytes: bytes) -> None:
        path = path_bytes.decode("utf-8", "surrogateescape")
        location = context + " " + safe_path(path)
        self.entries += 1
        self.report(location, path_findings(path, mode))
        if mode in {"100644", "100755"}:
            self.report(location, self.blob_findings(oid, PurePosixPath(path).suffix.lower()))

    def staged(self) -> None:
        for record in self.git.run("ls-files", "--stage", "-z").split(b"\0"):
            if not record:
                continue
            header, path = record.split(b"\t", 1)
            mode, oid, stage = header.decode("ascii").split()
            if stage != "0":
                raise CheckError("The Git index contains unresolved conflicts")
            self.entry("index", mode, oid, path)

    def tag_chain(self, oid: str) -> str:
        visited = set()
        while self.git.object_type(oid) == "tag":
            if oid in visited:
                raise CheckError("Cyclic annotated tag")
            visited.add(oid)
            data = self.git.run("cat-file", "tag", oid)
            text = data.decode("utf-8", "replace")
            self.report("tag " + oid[:12], content_findings(text))
            first = data.split(b"\n", 1)[0]
            if not first.startswith(b"object "):
                raise CheckError("Malformed annotated tag")
            oid = first[7:].decode("ascii")
            if not HASH.fullmatch(oid):
                raise CheckError("Malformed tag object ID")
        if self.git.object_type(oid) != "commit":
            raise CheckError("Outgoing ref does not resolve to a commit")
        return oid

    def history(self, tip: str, exclude: str | None = None) -> None:
        args = ["rev-list", tip]
        if exclude:
            args.append("^" + exclude)
        args.append("--")
        for oid_bytes in self.git.run(*args).splitlines():
            oid = oid_bytes.decode("ascii")
            if not HASH.fullmatch(oid):
                raise CheckError("Unexpected Git history result")
            if oid in self.commits:
                continue
            self.commits.add(oid)
            raw_commit = self.git.run("cat-file", "commit", oid)
            # Include author, committer, signatures and the complete commit message.
            self.report("commit " + oid[:12], content_findings(raw_commit.decode("utf-8", "replace")))
            for record in self.git.run("ls-tree", "-r", "-z", "--full-tree", oid).split(b"\0"):
                if record:
                    header, path = record.split(b"\t", 1)
                    mode, _kind, blob_oid = header.decode("ascii").split()
                    self.entry("commit " + oid[:12], mode, blob_oid, path)

    def pre_push(self, input_text: str) -> None:
        for line in input_text.splitlines():
            fields = line.split()
            if len(fields) != 4 or not HASH.fullmatch(fields[1]) or not HASH.fullmatch(fields[3]):
                raise CheckError("Malformed pre-push input")
            local_oid, remote_oid = fields[1], fields[3]
            if set(local_oid) == {"0"}:  # Deleting a remote ref publishes no objects.
                continue
            tip = self.tag_chain(local_oid)
            exclude = None
            if set(remote_oid) != {"0"} and self.git.object_type(remote_oid) is not None:
                exclude = self.git.commit_oid(remote_oid)
            self.history(tip, exclude)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Block likely private data in public Git snapshots. Matched values are never printed.",
        epilog="Run inside the public skill repository. No network requests or exclusion switches are used.",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--staged", action="store_true", help="scan every entry in the Git index, not working-tree files")
    mode.add_argument("--history", metavar="REV", help="scan all commits and trees reachable from REV")
    mode.add_argument("--pre-push", action="store_true", help="read Git pre-push ref records from stdin; scan each outgoing ref's ancestry")
    args = parser.parse_args(argv)
    scanner = Scanner()
    try:
        scanner.git.root = scanner.git.run("rev-parse", "--show-toplevel").rstrip(b"\n").decode("utf-8", "surrogateescape")
        if not args.staged and scanner.git.run("rev-parse", "--is-shallow-repository").strip() != b"false":
            raise CheckError("Complete history is required; shallow repositories cannot be verified")
        if args.staged:
            scanner.staged()
        elif args.history:
            # Scan an annotated tag's metadata too when REV names a tag.
            resolved = scanner.git.run("rev-parse", "--verify", "--end-of-options", args.history).strip().decode("ascii")
            if not HASH.fullmatch(resolved):
                raise CheckError("Unexpected Git revision result")
            scanner.history(scanner.tag_chain(resolved))
        else:
            scanner.pre_push(sys.stdin.read())
    except (CheckError, UnicodeError, ValueError) as error:
        # Exceptions from parsing are intentionally not rendered; they can include input.
        message = str(error) if isinstance(error, CheckError) else "Invalid Git data"
        print("Publication check failed closed: " + message, file=sys.stderr)
        return 2
    if scanner.errors:
        print("Publication blocked: " + str(len(scanner.errors)) + " finding(s). Values are redacted.", file=sys.stderr)
        for error in sorted(scanner.errors)[:40]:
            print("  " + error, file=sys.stderr)
        if len(scanner.errors) > 40:
            print("  Additional findings omitted.", file=sys.stderr)
        return 1
    print("Publication check passed (" + str(len(scanner.commits)) + " commits, " + str(scanner.entries) + " file snapshots).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
