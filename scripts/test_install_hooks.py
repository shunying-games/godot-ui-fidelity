import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


class HookInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        source = pathlib.Path(__file__).resolve().parent.parent
        (self.root / 'scripts').mkdir()
        shutil.copy2(source / 'scripts' / 'install_hooks.py', self.root / 'scripts')
        shutil.copytree(source / '.githooks', self.root / '.githooks')

    def install(self):
        return subprocess.run([sys.executable, str(self.root / 'scripts' / 'install_hooks.py')],
                              cwd=self.root, capture_output=True, text=True)

    def test_installs_and_is_repeatable(self):
        for _ in range(2):
            result = self.install()
            self.assertEqual(result.returncode, 0, result.stderr)
        path = subprocess.check_output(['git', 'config', '--get', 'core.hooksPath'],
                                       cwd=self.root, text=True).strip()
        self.assertEqual(path, '.githooks')
        self.assertTrue((self.root / '.githooks' / 'pre-push').stat().st_mode & 0o111)

    def test_preserves_active_default_hook(self):
        hook = self.root / '.git' / 'hooks' / 'pre-commit'
        hook.write_text('#!/bin/sh\nexit 7\n')
        hook.chmod(0o755)
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual(hook.read_text(), '#!/bin/sh\nexit 7\n')
        configured = subprocess.run(['git', 'config', '--get', 'core.hooksPath'],
                                    cwd=self.root, capture_output=True)
        self.assertEqual(configured.returncode, 1)

    def test_preserves_custom_hook_path(self):
        subprocess.run(['git', 'config', 'core.hooksPath', 'custom-hooks'],
                       cwd=self.root, check=True)
        self.assertNotEqual(self.install().returncode, 0)
        path = subprocess.check_output(['git', 'config', '--get', 'core.hooksPath'],
                                       cwd=self.root, text=True).strip()
        self.assertEqual(path, 'custom-hooks')


if __name__ == '__main__':
    unittest.main()
