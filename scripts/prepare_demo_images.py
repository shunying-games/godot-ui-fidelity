#!/usr/bin/env python3
"""Encode a small design preview and a complete skill-assisted runtime capture.

Optional dependency: Pillow. Does not paint, crop or retouch runtime UI pixels.
"""
import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageOps


def save_small(image, path, limit):
    for quality in (88, 84, 80, 76, 72, 68):
        image.save(path, 'WEBP', quality=quality, method=6, exif=b'', xmp=b'')
        if path.stat().st_size <= limit:
            print(path.name + ': ' + str(path.stat().st_size) + ' bytes; SHA-256 '
                  + hashlib.sha256(path.read_bytes()).hexdigest())
            return
    raise SystemExit('Image exceeds the size target.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--design', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    capture = Image.open(args.capture).convert('RGB')
    if capture.size != (1280, 720):
        parser.error('Use an actual full-viewport 1280x720 capture.')
    reference = ImageOps.contain(Image.open(args.design).convert('RGB'), (960, 540), Image.Resampling.LANCZOS)
    save_small(reference, args.output / 'reference.webp', 100_000)
    save_small(capture, args.output / 'with-skill.webp', 200_000)


if __name__ == '__main__':
    main()
