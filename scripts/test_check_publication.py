#!/usr/bin/env python3
"""Publication checks use disposable repositories and synthetic, runtime fixtures."""

from __future__ import annotations

import importlib.util
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib


SCRIPT = Path(__file__).with_name("check_publication.py")
SPEC = importlib.util.spec_from_file_location("check_publication", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def synthetic_token() -> str:
    return "".join(("gh", "p_", "A" * 36))


def synthetic_email() -> str:
    return "@".join(("publication-fixture", "mailhost.dev"))


def synthetic_webp(*chunks: tuple[bytes, bytes]) -> bytes:
    """Exercise the container policy; payloads are deliberately not decoded images."""
    body = b"WEBP"
    for kind, payload in chunks:
        body += kind + len(payload).to_bytes(4, "little") + payload
        body += b"\0" * (len(payload) % 2)
    return b"RIFF" + len(body).to_bytes(4, "little") + body


def synthetic_png(*chunks: tuple[bytes, bytes]) -> bytes:
    data = b"\x89PNG\r\n\x1a\n"
    for kind, payload in chunks:
        chunk = kind + payload
        data += len(payload).to_bytes(4, "big") + chunk + zlib.crc32(chunk).to_bytes(4, "big")
    return data


PNG_HEADER = bytes((0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0))


def valid_png(payload: bytes = b"fixture") -> bytes:
    # The container parser deliberately does not decompress the pixel payload.
    return synthetic_png((b"IHDR", PNG_HEADER), (b"IDAT", payload), (b"IEND", b""))


def synthetic_font(payload: bytes = b"fixture") -> bytes:
    tables = sorted((b"cmap", b"head", b"hhea", b"hmtx", b"maxp", b"name", b"post", b"loca", b"glyf"))
    count = len(tables)
    power = 1 << (count.bit_length() - 1)
    header = b"\0\1\0\0" + b"".join(value.to_bytes(2, "big") for value in (
        count, power * 16, power.bit_length() - 1, count * 16 - power * 16,
    ))
    directory, body = b"", b""
    for tag in tables:
        start = len(header) + count * 16 + len(body)
        directory += tag + bytes(4) + start.to_bytes(4, "big") + len(payload).to_bytes(4, "big")
        body += payload + bytes((-len(payload)) % 4)
    return header + directory + body


class DocumentationVisualTest(unittest.TestCase):
    path = "docs/demo/comparison-desktop.webp"

    def scan(self, data: bytes, *, approved: bytes | None = None) -> set[str]:
        scanner = MODULE.Scanner()
        scanner.git.run = mock.Mock(side_effect=(str(len(data)).encode(), data))
        hashes = frozenset({hashlib.sha256(approved if approved is not None else data).hexdigest()})
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {self.path: hashes}):
            return {finding.rule for finding in scanner.visual_findings("fixture-object", self.path)}

    def test_exact_reviewed_static_images_are_accepted(self) -> None:
        layouts = (
            ((b"VP8 ", b"fixture"),),
            ((b"VP8L", b"fixture"),),
            ((b"VP8X", bytes(10)), (b"VP8 ", b"fixture")),
            ((b"VP8X", bytes((0x10,)) + bytes(9)), (b"ALPH", b"alpha"), (b"VP8 ", b"fixture")),
        )
        for layout in layouts:
            with self.subTest(layout=layout):
                self.assertEqual(self.scan(synthetic_webp(*layout)), set())

    def test_changed_bytes_require_a_new_reviewed_hash(self) -> None:
        original = synthetic_webp((b"VP8L", b"fixture-a"))
        changed = synthetic_webp((b"VP8L", b"fixture-b"))
        self.assertEqual(self.scan(changed, approved=original), {"unreviewed-documentation-image"})

    def test_reviewed_path_alone_does_not_approve_any_bytes(self) -> None:
        data = synthetic_webp((b"VP8L", b"fixture"))
        scanner = MODULE.Scanner()
        scanner.git.run = mock.Mock(side_effect=(str(len(data)).encode(), data))
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {self.path: frozenset()}):
            rules = {finding.rule for finding in scanner.visual_findings("fixture-object", self.path)}
        self.assertEqual(rules, {"unreviewed-documentation-image"})

    def test_other_paths_keep_the_generic_binary_policy(self) -> None:
        for path in ("docs/demo/other.webp", self.path.upper(), "nested/" + self.path, "docs/demo/other.txt"):
            with self.subTest(path=path):
                data = synthetic_webp((b"VP8L", b"fixture"))
                scanner = MODULE.Scanner()
                scanner.git.run = mock.Mock(side_effect=(str(len(data)).encode(), data))
                scanner.entry("fixture", "100644", "fixture-object", path.encode())
                self.assertTrue(any("binary-file" in error for error in scanner.errors))
                if path.lower().endswith(".webp"):
                    self.assertTrue(any("unapproved-media" in error for error in scanner.errors))

    def test_image_limit_is_checked_before_loading_blob(self) -> None:
        scanner = MODULE.Scanner()
        scanner.git.run = mock.Mock(return_value=str(MODULE.MAX_PUBLIC_VISUAL_BYTES + 1).encode())
        rules = {finding.rule for finding in scanner.visual_findings("fixture-object", self.path)}
        self.assertEqual(rules, {"oversized-documentation-image"})
        scanner.git.run.assert_called_once_with("cat-file", "-s", "fixture-object")

    def test_exact_size_limit_is_accepted(self) -> None:
        overhead = len(synthetic_webp((b"VP8 ", b"")))
        data = synthetic_webp((b"VP8 ", b"F" * (MODULE.MAX_PUBLIC_VISUAL_BYTES - overhead)))
        self.assertEqual(len(data), MODULE.MAX_PUBLIC_VISUAL_BYTES)
        self.assertEqual(self.scan(data), set())

    def test_metadata_animation_and_unknown_chunks_are_rejected_even_with_reviewed_hash(self) -> None:
        for kind in (b"EXIF", b"XMP ", b"ICCP", b"ANIM", b"UNKN"):
            with self.subTest(kind=kind):
                data = synthetic_webp((b"VP8L", b"fixture"), (kind, b"runtime fixture"))
                self.assertIn("image-metadata-or-unsupported-chunk", self.scan(data))
        for flag in (0x20, 0x08, 0x04, 0x02, 0x01, 0x80):
            with self.subTest(flag=flag):
                data = synthetic_webp((b"VP8X", bytes((flag,)) + bytes(9)), (b"VP8 ", b"fixture"))
                self.assertIn("image-metadata-or-unsupported-chunk", self.scan(data))

    def test_malformed_containers_fail_even_with_reviewed_hash(self) -> None:
        valid = synthetic_webp((b"VP8 ", b"odd"))
        malformed = (
            b"", b"RIFF", valid.replace(b"WEBP", b"WAVE", 1),
            valid[:4] + bytes(4) + valid[8:], valid[:-1], valid + b"trailing",
            synthetic_webp(), synthetic_webp((b"VP8 ", b"")),
            synthetic_webp((b"VP8 ", b"first"), (b"VP8 ", b"duplicate")),
            synthetic_webp((b"VP8 ", b"first"), (b"VP8L", b"second")),
            synthetic_webp((b"VP8X", bytes(9)), (b"VP8 ", b"fixture")),
            synthetic_webp((b"VP8X", bytes((0, 1)) + bytes(8)), (b"VP8 ", b"fixture")),
            synthetic_webp((b"VP8 ", b"fixture"), (b"VP8X", bytes(10))),
            synthetic_webp((b"ALPH", b"alpha"), (b"VP8 ", b"fixture")),
            synthetic_webp((b"VP8X", bytes(10)), (b"ALPH", b"alpha"), (b"VP8 ", b"fixture")),
            synthetic_webp((b"VP8X", bytes((0x10,)) + bytes(9)), (b"ALPH", b"alpha"), (b"VP8L", b"fixture")),
            valid[:-1] + b"P",
        )
        for index, data in enumerate(malformed):
            with self.subTest(case=index):
                self.assertIn("invalid-documentation-image", self.scan(data))
        for body in (b"WEBPX", b"WEBPVP8 " + (20).to_bytes(4, "little") + b"short"):
            with self.subTest(body=body):
                data = b"RIFF" + len(body).to_bytes(4, "little") + body
                self.assertIn("invalid-documentation-image", self.scan(data))


class DemoAssetTest(unittest.TestCase):
    png_path = "demos/battle-comparison/shared/assets/ranger.png"
    webp_path = "demos/battle-comparison/shared/assets/map.webp"
    font_path = "demos/battle-comparison/shared/assets/Cinzel.ttf"

    def scan(self, data: bytes, path: str = png_path, *, approved: bytes | None = None) -> set[str]:
        scanner = MODULE.Scanner()
        scanner.git.run = mock.Mock(side_effect=(str(len(data)).encode(), data))
        hashes = frozenset({hashlib.sha256(approved if approved is not None else data).hexdigest()})
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}):
            return {finding.rule for finding in scanner.visual_findings("fixture-object", path)}

    def test_reviewed_static_demo_png_and_webp_are_accepted(self) -> None:
        for path, data in ((self.png_path, valid_png()), (self.webp_path, synthetic_webp((b"VP8L", b"fixture")))):
            with self.subTest(path=path):
                self.assertEqual(self.scan(data, path), set())

    def test_demo_changes_require_an_explicit_reviewed_hash(self) -> None:
        for path, first, second in (
            (self.png_path, valid_png(b"first"), valid_png(b"second")),
            (self.webp_path, synthetic_webp((b"VP8L", b"first")), synthetic_webp((b"VP8L", b"second"))),
        ):
            with self.subTest(path=path):
                self.assertEqual(self.scan(second, path, approved=first), {"unreviewed-demo-asset"})

    def test_unknown_binary_paths_keep_the_generic_policy(self) -> None:
        for path, data in (
            ("demos/battle-comparison/shared/assets/extra.png", valid_png()),
            (self.png_path.upper(), valid_png()),
            ("nested/" + self.png_path, valid_png()),
            ("demos/battle-comparison/shared/assets/extra.ttf", synthetic_font()),
            ("demos/battle-comparison/captures/frame.png", valid_png()),
        ):
            with self.subTest(path=path):
                scanner = MODULE.Scanner()
                scanner.git.run = mock.Mock(side_effect=(str(len(data)).encode(), data))
                scanner.entry("fixture", "100644", "fixture-object", path.encode())
                self.assertTrue(any("unapproved-media" in error for error in scanner.errors))
                self.assertTrue(any("binary-file" in error or "non-utf8-file" in error for error in scanner.errors))

    def test_digest_approval_without_a_path_cap_does_not_create_an_exemption(self) -> None:
        path = "demos/battle-comparison/shared/assets/extra.png"
        data = valid_png()
        hashes = frozenset({hashlib.sha256(data).hexdigest()})
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}):
            self.assertFalse(MODULE.approved_media(path))
            self.assertIn("unapproved-media", {finding.rule for finding in MODULE.path_findings(path, "100644")})
            self.assertEqual(self.scan(data, path), {"unapproved-media"})

    def test_each_demo_path_limit_is_enforced_before_loading_bytes(self) -> None:
        for path, cap in MODULE.PUBLIC_MEDIA_LIMITS.items():
            if not path.startswith("demos/"):
                continue
            with self.subTest(path=path):
                scanner = MODULE.Scanner()
                scanner.git.run = mock.Mock(return_value=str(cap + 1).encode())
                rules = {finding.rule for finding in scanner.visual_findings("fixture-object", path)}
                self.assertEqual(rules, {"oversized-demo-asset"})
                scanner.git.run.assert_called_once_with("cat-file", "-s", "fixture-object")

    def test_runtime_caps_are_individual_and_exact_boundary_is_accepted(self) -> None:
        overhead = len(valid_png(b""))
        for path in (self.png_path, "demos/battle-comparison/shared/assets/beetle.png"):
            with self.subTest(path=path):
                cap = MODULE.PUBLIC_MEDIA_LIMITS[path]
                data = valid_png(b"F" * (cap - overhead))
                self.assertEqual(len(data), cap)
                self.assertEqual(self.scan(data, path), set())
        self.assertLess(MODULE.PUBLIC_MEDIA_LIMITS[self.png_path], MODULE.MAX_BLOB_BYTES)
        self.assertNotEqual(MODULE.PUBLIC_MEDIA_LIMITS[self.png_path], MODULE.PUBLIC_MEDIA_LIMITS[self.webp_path])

    def test_png_metadata_chunks_are_rejected_even_with_reviewed_hash(self) -> None:
        for kind in (b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"caBX", b"iCCP", b"UNKN"):
            with self.subTest(kind=kind):
                data = synthetic_png((b"IHDR", PNG_HEADER), (kind, b"runtime fixture"), (b"IDAT", b"pixel"), (b"IEND", b""))
                self.assertIn("image-metadata-or-unsupported-chunk", self.scan(data))

    def test_png_bad_crc_trailing_bytes_and_malformed_structure_fail(self) -> None:
        valid = valid_png()
        malformed = (
            b"", b"PNG", b"bad-signature" + valid[8:], valid[:-1], valid + b"trailing",
            valid[:-1] + bytes((valid[-1] ^ 1,)),
            synthetic_png(), synthetic_png((b"IHDR", PNG_HEADER)),
            synthetic_png((b"IDAT", b"pixel"), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER), (b"IHDR", PNG_HEADER), (b"IDAT", b"pixel"), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER[:-1]), (b"IDAT", b"pixel"), (b"IEND", b"")),
            synthetic_png((b"IHDR", bytes(4) + PNG_HEADER[4:]), (b"IDAT", b"pixel"), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER[:9] + bytes((3,)) + PNG_HEADER[10:]), (b"IDAT", b"pixel"), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER), (b"IDAT", b""), (b"IEND", b"")),
            synthetic_png((b"IHDR", PNG_HEADER), (b"IDAT", b"pixel"), (b"IEND", b"payload")),
        )
        for index, data in enumerate(malformed):
            with self.subTest(case=index):
                self.assertIn("invalid-demo-asset", self.scan(data))

    def test_pinned_font_uses_structure_and_hash_without_scanning_font_strings(self) -> None:
        data = synthetic_font(synthetic_email().encode())
        self.assertEqual(self.scan(data, self.font_path), set())

    def test_changed_font_binary_requires_a_new_reviewed_hash(self) -> None:
        first, second = synthetic_font(b"first"), synthetic_font(b"other")
        self.assertEqual(self.scan(second, self.font_path, approved=first), {"unreviewed-demo-asset"})

    def test_invalid_font_container_is_rejected_even_with_reviewed_hash(self) -> None:
        valid = synthetic_font()
        malformed = (
            b"", b"ttcf" + valid[4:], valid[:11], valid[:4] + bytes(2) + valid[6:],
            valid[:6] + bytes(2) + valid[8:], valid[:-20],
            valid[:20] + (len(valid) + 4).to_bytes(4, "big") + valid[24:],
        )
        for index, data in enumerate(malformed):
            with self.subTest(case=index):
                self.assertIn("invalid-demo-asset", self.scan(data, self.font_path))


class RulesTest(unittest.TestCase):
    def rules(self, value: str, suffix: str = "") -> set[str]:
        return {finding.rule for finding in MODULE.content_findings(value, suffix)}

    def test_provider_private_key_and_literal_assignments(self) -> None:
        self.assertIn("provider-token", self.rules(synthetic_token()))
        header = " ".join(("-----BEGIN", "RSA", "PRIVATE", "KEY-----"))
        self.assertIn("private-key", self.rules(header))
        assignment = " = ".join(("password", repr("runtime-fixture-value")))
        self.assertIn("credential-assignment", self.rules(assignment))
        yaml_assignment = ": ".join(("access_token", "runtime-fixture-value"))
        self.assertIn("credential-assignment", self.rules(yaml_assignment, ".yaml"))
        dotted_assignment = ": ".join(("password", "runtime.fixture.value"))
        self.assertIn("credential-assignment", self.rules(dotted_assignment, ".yaml"))
        dotted_text = "=".join(("password", "runtime.fixture.value"))
        self.assertIn("credential-assignment", self.rules(dotted_text, ".txt"))
        typed_assignment = ": str = ".join(("password", repr("runtime-fixture-value")))
        self.assertIn("credential-assignment", self.rules(typed_assignment, ".py"))

    def test_explicit_examples_and_code_references_are_accepted(self) -> None:
        examples = [
            " = ".join(("api_key", repr("YOUR_API_KEY"))),
            ": ".join(("password", "<replace-me>")),
            " = ".join(("access_token", "os.getenv('TOKEN')")),
            ": ".join(("password", "${EXAMPLE_VALUE}")),
            ": ".join(("api_key", "str")),
            "dev@example.com", "publisher@users.noreply.github.com", "noreply@github.com",
            "git@github.com:organization/project.git",
        ]
        for example in examples:
            with self.subTest(example=example):
                self.assertEqual(self.rules(example, ".py"), set())

    def test_private_paths_urls_and_personal_email(self) -> None:
        home_path = "/".join(("", "Users", "fixture-person", "workspace"))
        private_url = "://".join(("https", "192.168.10.20/status"))
        loopback_url = "://".join(("http", "localhost:8080"))
        credential_url = "://".join(("https", "fixture-user:fixture-value@public.example.com"))
        self.assertIn("home-path", self.rules(home_path))
        self.assertIn("private-network-url", self.rules(private_url))
        self.assertIn("private-network-url", self.rules(loopback_url))
        self.assertIn("url-credential", self.rules(credential_url))
        self.assertIn("personal-email", self.rules(synthetic_email()))

    def test_guard_and_its_tests_do_not_flag_their_own_source(self) -> None:
        for source in (SCRIPT, Path(__file__)):
            self.assertEqual(MODULE.content_findings(source.read_text(), ".py"), [], source.name)


@unittest.skipUnless(shutil.which("git"), "Git is required")
class RepositoryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="publication-check-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = os.environ.copy()
        for key in tuple(self.environment):
            if key.startswith("GIT_"):
                del self.environment[key]
        self.environment.update({
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_AUTHOR_NAME": "Publication Test", "GIT_COMMITTER_NAME": "Publication Test",
            "GIT_AUTHOR_EMAIL": "publisher@users.noreply.github.com",
            "GIT_COMMITTER_EMAIL": "publisher@users.noreply.github.com",
        })
        self.git("init", "-q")

    def git(self, *args: str, environment: dict[str, str] | None = None) -> str:
        result = subprocess.run(
            ["git", *args], cwd=self.root, env=environment or self.environment,
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        return result.stdout.strip()

    def write(self, name: str, value: str) -> None:
        destination = self.root / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(value)

    def commit(self, message: str = "Public documentation", environment: dict[str, str] | None = None) -> str:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message, environment=environment)
        return self.git("rev-parse", "HEAD")

    def check(self, *args: str, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args], cwd=self.root, env=self.environment,
            input=stdin, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )

    def push_record(self, oid: str, old: str | None = None) -> str:
        return " ".join(("refs/heads/published", oid, "refs/heads/published", old or "0" * 40)) + "\n"

    def test_staged_snapshot_is_independent_of_working_tree(self) -> None:
        self.write("README.md", "Safe documentation\n")
        self.git("add", "README.md")
        self.write("README.md", synthetic_token())
        self.assertEqual(self.check("--staged").returncode, 0)
        self.git("add", "README.md")
        self.write("README.md", "Safe documentation\n")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 1)
        self.assertIn("provider-token", result.stderr)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)

    def test_entire_index_is_checked_even_when_no_changes_are_staged(self) -> None:
        self.write("README.md", synthetic_token())
        self.commit()
        self.assertEqual(self.check("--staged").returncode, 1)

    def test_invocation_from_subdirectory_still_checks_the_entire_repository(self) -> None:
        self.write("README.md", synthetic_token())
        self.write("nested/guide.md", "Safe nested content")
        self.git("add", "-A")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--staged"], cwd=self.root / "nested", env=self.environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("provider-token", result.stderr)

    def test_history_catches_removed_old_content(self) -> None:
        self.write("old.md", synthetic_token())
        old = self.commit()
        (self.root / "old.md").unlink()
        self.write("README.md", "Safe tip\n")
        self.commit()
        self.assertEqual(self.check("--staged").returncode, 0)
        result = self.check("--history", "HEAD")
        self.assertEqual(result.returncode, 1)
        self.assertIn(old[:12], result.stderr)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)

    def test_pre_push_checks_actual_non_head_ref(self) -> None:
        self.write("README.md", "Safe base\n")
        base = self.commit()
        current_branch = self.git("symbolic-ref", "--short", "HEAD")
        self.git("checkout", "-q", "-b", "other-ref")
        self.write("unsafe.md", synthetic_token())
        outgoing = self.commit()
        self.git("checkout", "-q", current_branch)
        self.assertEqual(self.git("rev-parse", "HEAD"), base)
        result = self.check("--pre-push", stdin=self.push_record(outgoing, base))
        self.assertEqual(result.returncode, 1)
        self.assertIn(outgoing[:12], result.stderr)

    def test_initial_push_checks_upstream_initial_ancestry(self) -> None:
        self.write("README.md", "Initial public file\n")
        identity = dict(self.environment)
        identity["GIT_AUTHOR_EMAIL"] = synthetic_email()
        initial = self.commit(environment=identity)
        self.write("README.md", "Safe final file\n")
        tip = self.commit()
        result = self.check("--pre-push", stdin=self.push_record(tip))
        self.assertEqual(result.returncode, 1)
        self.assertIn(initial[:12], result.stderr)
        self.assertIn("personal-email", result.stderr)
        self.assertNotIn(synthetic_email(), result.stdout + result.stderr)

    def test_existing_remote_ancestry_is_excluded_when_available(self) -> None:
        self.write("old.md", synthetic_token())
        old = self.commit()
        (self.root / "old.md").unlink()
        self.write("README.md", "Safe new content\n")
        tip = self.commit()
        result = self.check("--pre-push", stdin=self.push_record(tip, old))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_remote_object_scans_full_ancestry(self) -> None:
        self.write("old.md", synthetic_token())
        self.commit()
        (self.root / "old.md").unlink()
        self.write("README.md", "Safe tip\n")
        tip = self.commit()
        result = self.check("--pre-push", stdin=self.push_record(tip, "1" * 40))
        self.assertEqual(result.returncode, 1)

    def test_messages_and_committer_identity_are_scanned(self) -> None:
        self.write("README.md", "Safe content\n")
        identity = dict(self.environment)
        identity["GIT_COMMITTER_EMAIL"] = synthetic_email()
        self.commit("Message " + synthetic_token(), identity)
        result = self.check("--history", "HEAD")
        self.assertEqual(result.returncode, 1)
        self.assertIn("personal-email", result.stderr)
        self.assertIn("provider-token", result.stderr)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)
        self.assertNotIn(synthetic_email(), result.stdout + result.stderr)

    def test_path_policy_covers_nested_files_media_reports_and_symlinks(self) -> None:
        self.write("nested/.env.local", "harmless fixture")
        self.write("nested/screenshot.png", "text fixture")
        self.write("nested/test-results/result.txt", "test output")
        (self.root / "linked.md").symlink_to("nested/.env.local")
        self.git("add", "-A")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 1)
        for rule in ("sensitive-filename", "unapproved-media", "local-artifact-path", "symlink"):
            self.assertIn(rule, result.stderr)

    def test_sensitive_filename_is_redacted(self) -> None:
        filename = synthetic_token() + ".md"
        self.write(filename, "Safe content")
        self.git("add", "-A")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 1)
        self.assertIn("redacted-path", result.stderr)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)

    def test_binary_and_oversized_files_are_rejected(self) -> None:
        (self.root / "data.txt").write_bytes(bytes((0, 1, 2)))
        self.write("large.txt", "A" * (MODULE.MAX_BLOB_BYTES + 1))
        self.git("add", "-A")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 1)
        self.assertIn("binary-file", result.stderr)
        self.assertIn("oversized-file", result.stderr)

    def test_reviewed_visual_uses_the_staged_bytes(self) -> None:
        path = DocumentationVisualTest.path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        approved = synthetic_webp((b"VP8L", b"reviewed fixture"))
        destination.write_bytes(approved)
        self.git("add", "-A")
        destination.write_bytes(synthetic_webp((b"VP8L", b"unreviewed fixture")))
        scanner = MODULE.Scanner()
        scanner.git.root = str(self.root)
        hashes = frozenset({hashlib.sha256(approved).hexdigest()})
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}), mock.patch.dict(os.environ, self.environment, clear=True):
            scanner.staged()
        self.assertEqual(scanner.errors, set())
        self.git("add", "-A")
        scanner = MODULE.Scanner()
        scanner.git.root = str(self.root)
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}), mock.patch.dict(os.environ, self.environment, clear=True):
            scanner.staged()
        self.assertTrue(any("unreviewed-documentation-image" in error for error in scanner.errors))

    def test_visual_history_requires_each_reviewed_revision(self) -> None:
        path = DocumentationVisualTest.path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        first = synthetic_webp((b"VP8L", b"first reviewed fixture"))
        second = synthetic_webp((b"VP8L", b"second reviewed fixture"))
        destination.write_bytes(first)
        initial = self.commit()
        destination.write_bytes(second)
        tip = self.commit()
        first_digest, second_digest = (hashlib.sha256(data).hexdigest() for data in (first, second))
        for hashes, should_pass in ((frozenset({first_digest, second_digest}), True), (frozenset({second_digest}), False)):
            with self.subTest(retains_prior_review=should_pass):
                scanner = MODULE.Scanner()
                scanner.git.root = str(self.root)
                with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}), mock.patch.dict(os.environ, self.environment, clear=True):
                    scanner.history(tip)
                if should_pass:
                    self.assertEqual(scanner.errors, set())
                else:
                    self.assertTrue(any(initial[:12] in error and "unreviewed-documentation-image" in error for error in scanner.errors))

    def test_removed_unreviewed_visual_is_still_found_in_history(self) -> None:
        path = DocumentationVisualTest.path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        destination.write_bytes(synthetic_webp((b"VP8L", b"old unreviewed fixture")))
        initial = self.commit()
        destination.unlink()
        self.write("README.md", "Safe final documentation")
        tip = self.commit()
        scanner = MODULE.Scanner()
        scanner.git.root = str(self.root)
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: frozenset()}), mock.patch.dict(os.environ, self.environment, clear=True):
            scanner.staged()
            self.assertEqual(scanner.errors, set())
            scanner.history(tip)
        self.assertTrue(any(initial[:12] in error and "unreviewed-documentation-image" in error for error in scanner.errors))

    def test_demo_png_approval_uses_index_bytes(self) -> None:
        path = DemoAssetTest.png_path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        approved, changed = valid_png(b"reviewed pixels"), valid_png(b"changed pixels")
        destination.write_bytes(approved)
        self.git("add", "-A")
        destination.write_bytes(changed)
        hashes = frozenset({hashlib.sha256(approved).hexdigest()})
        for should_pass in (True, False):
            if not should_pass:
                self.git("add", "-A")
                destination.write_bytes(approved)
            scanner = MODULE.Scanner()
            scanner.git.root = str(self.root)
            with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}), mock.patch.dict(os.environ, self.environment, clear=True):
                scanner.staged()
            if should_pass:
                self.assertEqual(scanner.errors, set())
            else:
                self.assertTrue(any("unreviewed-demo-asset" in error for error in scanner.errors))

    def test_pre_push_scans_modified_font_at_the_actual_outgoing_ref(self) -> None:
        path = DemoAssetTest.font_path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        approved, changed = synthetic_font(b"reviewed font"), synthetic_font(b"changed font")
        destination.write_bytes(approved)
        base = self.commit()
        destination.write_bytes(changed)
        outgoing = self.commit()
        self.git("checkout", "-q", "--detach", base)
        scanner = MODULE.Scanner()
        scanner.git.root = str(self.root)
        hashes = frozenset({hashlib.sha256(approved).hexdigest()})
        with mock.patch.dict(MODULE.PUBLIC_MEDIA, {path: hashes}), mock.patch.dict(os.environ, self.environment, clear=True):
            scanner.pre_push(self.push_record(outgoing, base))
        self.assertTrue(any(outgoing[:12] in error and "unreviewed-demo-asset" in error for error in scanner.errors))

    def test_removed_unreviewed_demo_asset_is_checked_in_full_history(self) -> None:
        path = DemoAssetTest.png_path
        destination = self.root / path
        destination.parent.mkdir(parents=True)
        destination.write_bytes(valid_png(b"old unreviewed pixels"))
        initial = self.commit()
        destination.unlink()
        self.write("README.md", "Safe final documentation")
        self.commit()
        self.assertEqual(self.check("--staged").returncode, 0)
        result = self.check("--history", "HEAD")
        self.assertEqual(result.returncode, 1)
        self.assertIn(initial[:12], result.stderr)
        self.assertIn("unreviewed-demo-asset", result.stderr)

    def test_annotated_tag_message_is_checked(self) -> None:
        self.write("README.md", "Safe content")
        self.commit()
        self.git("tag", "-a", "release", "-m", synthetic_token())
        oid = self.git("rev-parse", "release")
        result = self.check("--pre-push", stdin=self.push_record(oid))
        self.assertEqual(result.returncode, 1)
        self.assertIn("tag " + oid[:12], result.stderr)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)

    def test_git_errors_and_invalid_pre_push_input_fail_closed(self) -> None:
        self.assertEqual(self.check("--history", "missing-ref").returncode, 2)
        for record in ("bad input", self.push_record("2" * 40)):
            result = self.check("--pre-push", stdin=record)
            self.assertEqual(result.returncode, 2)
            self.assertIn("failed closed", result.stderr)

    def test_shallow_history_cannot_be_reported_complete(self) -> None:
        self.write("README.md", "Safe initial content")
        oid = self.commit()
        (self.root / ".git" / "shallow").write_text(oid + "\n")
        self.assertEqual(self.check("--staged").returncode, 0)
        for arguments, record in ((("--history", "HEAD"), None), (("--pre-push",), self.push_record(oid))):
            result = self.check(*arguments, stdin=record)
            self.assertEqual(result.returncode, 2)
            self.assertIn("shallow", result.stderr)


if __name__ == "__main__":
    unittest.main()
