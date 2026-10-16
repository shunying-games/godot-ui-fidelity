#!/usr/bin/env python3
"""Enable this checkout's publication hooks without replacing another hook setup."""
from pathlib import Path
import os
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parent.parent
    actual = subprocess.check_output(
        ['git', 'rev-parse', '--show-toplevel'], cwd=root, text=True).strip()
    if Path(actual).resolve() != root:
        raise SystemExit('Run from a standalone checkout of this skill repository.')
    previous = subprocess.run(
        ['git', 'config', '--get', 'core.hooksPath'], cwd=root,
        text=True, capture_output=True, check=False)
    if previous.returncode not in (0, 1):
        raise SystemExit('Could not inspect existing Git hook configuration.')
    if previous.returncode == 0 and previous.stdout.strip() != '.githooks':
        raise SystemExit('An existing hook setup is configured; integrate the publication checks into it first.')
    if previous.returncode == 1:
        default_hooks = Path(subprocess.check_output(
            ['git', 'rev-parse', '--git-path', 'hooks'], cwd=root, text=True).strip())
        if not default_hooks.is_absolute():
            default_hooks = root / default_hooks
        if default_hooks.is_dir() and any(
                p.is_file() and not p.name.endswith('.sample') and os.access(p, os.X_OK)
                for p in default_hooks.iterdir()):
            raise SystemExit('Active default Git hooks exist; integrate the publication checks into them first.')
    for name in ('pre-commit', 'pre-push'):
        hook = root / '.githooks' / name
        if not hook.is_file():
            raise SystemExit('Publication hook is missing.')
        hook.chmod(hook.stat().st_mode | 0o111)
    subprocess.run(['git', 'config', '--local', 'core.hooksPath', '.githooks'],
                   cwd=root, check=True)
    print('Enabled staged-file and outgoing-history publication checks for this checkout.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
