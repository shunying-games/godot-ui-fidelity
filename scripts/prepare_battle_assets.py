#!/usr/bin/env python3
"""Reproduce battle-demo runtime image crops/resizes from reviewed source pixels.

Optional dependency: Pillow. Source art and font licensing are documented in
source-art/GENERATION.md and shared/assets/OFL-Cinzel.txt. No generation API.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def prepare(source: Path, output: Path) -> None:
    manifest = json.loads((source / "ASSETS.json").read_text())
    output.mkdir(parents=True, exist_ok=True)
    for name, entry in manifest["sources"].items():
        if hashlib.sha256((source / entry["file"]).read_bytes()).hexdigest() != entry["sha256"]:
            raise SystemExit("Source hash mismatch: " + name)
    for filename, entry in manifest["runtime"].items():
        if "source" not in entry:
            continue  # Font/license are supplied unchanged from their upstream.
        image = Image.open(source / entry["source"])
        if "cell" in entry:
            image = image.crop(entry["cell"]).crop(entry["alpha_crop"])
        image = image.resize(tuple(entry["resize"]), Image.Resampling.LANCZOS)
        target = output / filename
        if target.suffix == ".webp":
            image.save(target, quality=entry["quality"], method=6)
        else:
            image.save(target, optimize=True)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        print(filename + ": SHA-256 " + digest + "; matches published=" + str(digest == entry["sha256"]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    if output == source or source in output.parents or output.exists() and any(output.iterdir()):
        parser.error("Use a new empty output directory outside source art.")
    prepare(source, output)


if __name__ == "__main__":
    main()
