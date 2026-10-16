#!/usr/bin/env python3
"""Run the 90 common battle-model assertions in a fresh silent project."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
STUDY = ROOT / "demos" / "battle-comparison"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="godot-battle-model-") as directory:
        project = Path(directory)
        shutil.copy2(STUDY / "shared" / "battle_model.gd", project / "battle_model.gd")
        shutil.copy2(STUDY / "harness" / "test_battle_model.gd", project / "test_battle_model.gd")
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Battle model checks"\n'
            'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="GodotUIFidelityDemo/'
            + project.name + '"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        command = [str(args.godot.expanduser().resolve()), "--headless", "--audio-driver", "Dummy",
                   "--path", str(project), "--log-file", str(project / "checks.log"),
                   "--script", "res://test_battle_model.gd"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        print(output, end="")
        marker = "Shared battle model: 90 passed, 0 failed"
        return 0 if result.returncode == 0 and marker in output and "SCRIPT ERROR" not in output else 1


if __name__ == "__main__":
    raise SystemExit(main())
