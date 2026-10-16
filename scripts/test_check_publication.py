#!/usr/bin/env python3
"""Publication checks use disposable repositories and synthetic, runtime fixtures."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("check_publication.py")
SPEC = importlib.util.spec_from_file_location("check_publication", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def synthetic_token() -> str:
    return "".join(("gh", "p_", "A" * 36))


def synthetic_email() -> str:
    return "@".join(("publication-fixture", "mailhost.dev"))


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
