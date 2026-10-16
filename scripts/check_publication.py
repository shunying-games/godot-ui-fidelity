#!/usr/bin/env python3
"""Check the exact Git snapshots about to become public, without logging values."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import re
import subprocess
import sys
import zlib
from dataclasses import dataclass
from pathlib import PurePosixPath
from urllib.parse import urlsplit


MAX_BLOB_BYTES = 2 * 1024 * 1024
HASH = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
MEDIA_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".psd", ".blend",
    ".mp3", ".wav", ".ogg", ".flac", ".m4a", ".mp4", ".mov", ".webm",
    ".zip", ".gz", ".7z", ".pdf", ".docx", ".xlsx", ".pptx",
    ".ttf", ".otf", ".woff", ".woff2",
}
# Only these exact reviewed paths AND hashes may contain binary assets.
# Keep approved older hashes for full-history verification. There are no globs,
# directory exemptions or command-line exclusions. Runtime art belongs solely to
# this standalone original demo; raw captures and game-project assets stay out.
PUBLIC_MEDIA: dict[str, frozenset[str]] = {
    "docs/demo/comparison-desktop.webp": frozenset({"a8f51d3a53ed9a24eb0f3574bd3df40a92fc05ca4e1a53301303c06c6b12384a"}),
    "docs/demo/comparison-mobile.webp": frozenset({"79c8c3bfbf054d6668b29216964791f1fe95ee1cb9b68a6cf181e32e8c771ae2"}),
    "docs/battle/reference.webp": frozenset({"6ae90fa8e2e65a75bee50efac2a66259b409a5ff7eac53b64e4cc393cc63b67c"}),
    "docs/battle/with-skill.webp": frozenset({"a97a4373cf9b6b5798cb3f20eb8b7fe037780dcdbf41ab781e96f897e272e419"}),
    "docs/battle/comparison.webp": frozenset({"cc63cfc1517ae54e810e95bf0fa0efb91e329b1ed4b1db76f135e63ccd870921"}),
    "docs/battle/compact.webp": frozenset({"fe8d5f7097bc2bfe8512673b8b3e1daafe9491c1d1a68cdd455571885cc61a76"}),
    "demos/battle-comparison/source-art/design.png": frozenset({"afc7a84abb340f3b25a0b6c1c347e5ba5b55910d6b6be802e895acabefc8e461"}),
    "demos/battle-comparison/source-art/map.png": frozenset({"7cc4f6b06646cab5a9daa38cd2c064801295ff68c6f24f7edc40af46faad50e9"}),
    "demos/battle-comparison/source-art/actors.png": frozenset({"fb73c74b7361b57aa8d2fb400782829538918c5f58e8bf5ecc672f6790427669"}),
    "demos/battle-comparison/source-art/chrome.png": frozenset({"7bbb4ac6833837cfa55f72ccfab67d512aa2eb36f0a7604defdc707d56eb0f70"}),
    "demos/battle-comparison/shared/assets/map.webp": frozenset({"48ab748ef6ad147591fa5018f4bda1030caa7621127251ad940f012b6acd0a2b"}),
    "demos/battle-comparison/shared/assets/ranger.png": frozenset({"9495d9810f774b4319399ee6702cfdfe09c2ed77865087421858e325df96ea2c"}),
    "demos/battle-comparison/shared/assets/ember.png": frozenset({"4808296a24d5105c07447bf8f056c63926ed5b56d8007912e67788459e9c6f53"}),
    "demos/battle-comparison/shared/assets/frost.png": frozenset({"6eaf9067ea969a6817315febcc383f3d68d0b3d4d01a979dc060ab0a052f96b6"}),
    "demos/battle-comparison/shared/assets/beetle.png": frozenset({"8c77e5f63933b83d76f3cea899d058ad02047c85d62100e5b651e6f7824f699c"}),
    "demos/battle-comparison/shared/assets/wood.png": frozenset({"27dc8969aae9cd9713e833e2bf9325d33c5fca9099e0577c14c824b011a3d833"}),
    "demos/battle-comparison/shared/assets/gold.png": frozenset({"b9663cb77855d1c00c0c84b3ddd6510acc1a517f07d823063d0d0dc6b9022023"}),
    "demos/battle-comparison/shared/assets/crest.png": frozenset({"df0bdca5cdf77e1f119c7803c80ab630a83c9a5ed132ed7352f3afa43a4584bc"}),
    # Official Google Fonts Cinzel, distributed with its adjacent OFL license.
    # Fetched from the official main branch; this exact binary hash is pinned.
    # https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf
    "demos/battle-comparison/shared/assets/Cinzel.ttf": frozenset({"f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34"}),
}
MAX_PUBLIC_VISUAL_BYTES = 220_000
# Each entry needs its own cap as well as its reviewed digest. A new path does
# not inherit a larger source-art, runtime-art or font allowance by extension.
PUBLIC_MEDIA_LIMITS: dict[str, int] = {
    "docs/demo/comparison-desktop.webp": MAX_PUBLIC_VISUAL_BYTES,
    "docs/demo/comparison-mobile.webp": MAX_PUBLIC_VISUAL_BYTES,
    "docs/battle/reference.webp": MAX_PUBLIC_VISUAL_BYTES,
    "docs/battle/with-skill.webp": MAX_PUBLIC_VISUAL_BYTES,
    "docs/battle/comparison.webp": MAX_PUBLIC_VISUAL_BYTES,
    "docs/battle/compact.webp": MAX_PUBLIC_VISUAL_BYTES,
    "demos/battle-comparison/source-art/design.png": 3_000_000,
    "demos/battle-comparison/source-art/map.png": 3_000_000,
    "demos/battle-comparison/source-art/actors.png": 1_400_000,
    "demos/battle-comparison/source-art/chrome.png": 1_500_000,
    "demos/battle-comparison/shared/assets/map.webp": 400_000,
    "demos/battle-comparison/shared/assets/ranger.png": 140_000,
    "demos/battle-comparison/shared/assets/ember.png": 120_000,
    "demos/battle-comparison/shared/assets/frost.png": 140_000,
    "demos/battle-comparison/shared/assets/beetle.png": 40_000,
    "demos/battle-comparison/shared/assets/wood.png": 600_000,
    "demos/battle-comparison/shared/assets/gold.png": 350_000,
    "demos/battle-comparison/shared/assets/crest.png": 40_000,
    "demos/battle-comparison/shared/assets/Cinzel.ttf": 130_000,
}
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


def approved_media(path: str) -> bool:
    return path in PUBLIC_MEDIA and path in PUBLIC_MEDIA_LIMITS


def png_findings(data: bytes, invalid_rule: str) -> list[Finding]:
    """Accept only metadata-free static IHDR/IDAT/IEND PNG containers."""
    invalid = [Finding(invalid_rule)]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return invalid
    offset = 8
    chunks: list[bytes] = []
    findings = []
    while offset < len(data):
        if offset + 12 > len(data):
            return findings + invalid
        length = int.from_bytes(data[offset:offset + 4], "big")
        kind = data[offset + 4:offset + 8]
        payload_end = offset + 8 + length
        end = payload_end + 4
        if end > len(data) or zlib.crc32(data[offset + 4:payload_end]) != int.from_bytes(data[payload_end:end], "big"):
            return findings + invalid
        if kind not in {b"IHDR", b"IDAT", b"IEND"}:
            findings.append(Finding("image-metadata-or-unsupported-chunk"))
        if not chunks and kind != b"IHDR":
            return findings + invalid
        if kind == b"IHDR":
            if chunks or length != 13:
                return findings + invalid
            header = data[offset + 8:payload_end]
            width, height = int.from_bytes(header[:4], "big"), int.from_bytes(header[4:8], "big")
            allowed_depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 4: {8, 16}, 6: {8, 16}}
            if not width or not height or max(width, height) > 16_384:
                return findings + invalid
            if header[8] not in allowed_depths.get(header[9], set()) or header[10:12] != bytes(2) or header[12] not in {0, 1}:
                return findings + invalid
        elif kind == b"IDAT":
            if not length or chunks[-1] not in {b"IHDR", b"IDAT"}:
                return findings + invalid
        elif kind == b"IEND":
            if length or b"IDAT" not in chunks or end != len(data):
                return findings + invalid
        chunks.append(kind)
        offset = end
    if not chunks or chunks[-1] != b"IEND":
        return findings + invalid
    return findings


def font_findings(data: bytes, invalid_rule: str) -> list[Finding]:
    """Validate the pinned TrueType container; never treat font bytes as text."""
    invalid = [Finding(invalid_rule)]
    if len(data) < 12 or data[:4] != b"\x00\x01\x00\x00":
        return invalid
    count = int.from_bytes(data[4:6], "big")
    if not 1 <= count <= 128 or 12 + 16 * count > len(data):
        return invalid
    power = 1 << (count.bit_length() - 1)
    expected = (power * 16, power.bit_length() - 1, count * 16 - power * 16)
    if tuple(int.from_bytes(data[start:start + 2], "big") for start in (6, 8, 10)) != expected:
        return invalid
    tables = set()
    for offset in range(12, 12 + 16 * count, 16):
        tag = data[offset:offset + 4]
        start = int.from_bytes(data[offset + 8:offset + 12], "big")
        length = int.from_bytes(data[offset + 12:offset + 16], "big")
        if tag in tables or any(byte < 32 or byte > 126 for byte in tag):
            return invalid
        if start % 4 or start < 12 + 16 * count or start + length > len(data):
            return invalid
        tables.add(tag)
    if not {b"cmap", b"head", b"hhea", b"hmtx", b"maxp", b"name", b"post", b"loca", b"glyf"} <= tables:
        return invalid
    return []


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
    if PurePosixPath(path).suffix.lower() in MEDIA_EXTENSIONS and not approved_media(path):
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

    def visual_findings(self, oid: str, path: str) -> list[Finding]:
        size = int(self.git.run("cat-file", "-s", oid).strip())
        is_documentation = path.startswith("docs/")
        oversized = "oversized-documentation-image" if is_documentation else "oversized-demo-asset"
        unreviewed = "unreviewed-documentation-image" if is_documentation else "unreviewed-demo-asset"
        invalid = "invalid-documentation-image" if is_documentation else "invalid-demo-asset"
        if not approved_media(path):
            return [Finding("unapproved-media")]
        if size > PUBLIC_MEDIA_LIMITS[path]:
            return [Finding(oversized)]
        data = self.git.run("cat-file", "blob", oid)
        findings = []
        if hashlib.sha256(data).hexdigest() not in PUBLIC_MEDIA[path]:
            findings.append(Finding(unreviewed))
        suffix = PurePosixPath(path).suffix.lower()
        if suffix == ".png":
            return findings + png_findings(data, invalid)
        if suffix == ".ttf":
            return findings + font_findings(data, invalid)
        if suffix != ".webp":
            return findings + [Finding(invalid)]
        if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WEBP" or int.from_bytes(data[4:8], "little") + 8 != len(data):
            return findings + [Finding(invalid)]
        offset = 12
        chunks = []
        while offset < len(data):
            if offset + 8 > len(data):
                return findings + [Finding(invalid)]
            kind = data[offset:offset + 4]
            length = int.from_bytes(data[offset + 4:offset + 8], "little")
            payload_end = offset + 8 + length
            end = payload_end + (length % 2)
            if end > len(data):
                return findings + [Finding(invalid)]
            if length % 2 and data[payload_end] != 0:
                return findings + [Finding(invalid)]
            if kind not in {b"VP8 ", b"VP8L", b"VP8X", b"ALPH"}:
                findings.append(Finding("image-metadata-or-unsupported-chunk"))
            if not length or kind in chunks:
                return findings + [Finding(invalid)]
            if kind == b"VP8X":
                if chunks or length != 10 or any(data[offset + 9:offset + 12]):
                    return findings + [Finding(invalid)]
                # Only alpha is supported. Metadata and animation flags are excluded.
                if data[offset + 8] & ~0x10:
                    findings.append(Finding("image-metadata-or-unsupported-chunk"))
            if kind == b"ALPH" and chunks != [b"VP8X"]:
                return findings + [Finding(invalid)]
            chunks.append(kind)
            offset = end
        if sum(kind in {b"VP8 ", b"VP8L"} for kind in chunks) != 1:
            findings.append(Finding(invalid))
        if b"ALPH" in chunks and (chunks[-1] != b"VP8 " or not data[20] & 0x10):
            findings.append(Finding(invalid))
        return findings

    def entry(self, context: str, mode: str, oid: str, path_bytes: bytes) -> None:
        path = path_bytes.decode("utf-8", "surrogateescape")
        location = context + " " + safe_path(path)
        self.entries += 1
        self.report(location, path_findings(path, mode))
        if mode in {"100644", "100755"}:
            if approved_media(path):
                self.report(location, self.visual_findings(oid, path))
            else:
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
