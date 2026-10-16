#!/usr/bin/env python3
"""Encode a small design preview and full-frame real Godot comparisons.

Optional dependency: Pillow. Runtime UI pixels are never painted or retouched.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def save_small(image, path, limit=180_000):
    for quality in (88, 84, 80, 76, 72, 68):
        image.save(path, 'WEBP', quality=quality, method=6, exif=b'', xmp=b'')
        if path.stat().st_size <= limit:
            print(path.name + ': ' + str(path.stat().st_size) + ' bytes; SHA-256 '
                  + hashlib.sha256(path.read_bytes()).hexdigest())
            return
    raise SystemExit('Image exceeds the target; inspect a smaller presentation.')


def compose(captures, design, output, font_path):
    output.mkdir(parents=True, exist_ok=True)
    reference = ImageOps.contain(Image.open(design).convert('RGB'), (960, 540), Image.Resampling.LANCZOS)
    save_small(reference, output / 'reference.webp', 100_000)
    heading = ImageFont.truetype(str(font_path), 18)
    small = ImageFont.truetype(str(font_path), 13)
    for compact, name in ((False, 'comparison.webp'), (True, 'compact.webp')):
        suffix = 'compact' if compact else 'desktop'
        expected = (960, 540) if compact else (1280, 720)
        images = [Image.open(captures / (variant + '-' + suffix + '.jpg')).convert('RGB')
                  for variant in ('without', 'with')]
        if any(im.size != expected for im in images):
            raise SystemExit('Screenshot sizes differ from the declared viewport.')
        pane = (704, 396)  # Exact 16:9; both source viewports use uniform scale.
        images = [im.resize(pane, Image.Resampling.LANCZOS) for im in images]
        canvas = Image.new('RGB', (1448, 480), '#102228')
        draw = ImageDraw.Draw(canvas)
        draw.text((14, 9), 'One GPT Image design. Two actual Godot implementations.', font=heading, fill='#f5e9ce')
        for index, (label, im) in enumerate(zip(('WITHOUT SKILL', 'WITH SKILL'), images)):
            x = 14 + index * 716
            draw.text((x, 36), label, font=small, fill='#d7bf91' if index == 0 else '#9dd9cf')
            canvas.paste(im, (x, 59))
        draw.text((14, 460), str(expected[0]) + ' x ' + str(expected[1])
                  + ' | full viewport | shared paused-active wave 3', font=small, fill='#b4c4c3')
        save_small(canvas, output / name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--design', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--font', type=Path, required=True)
    args = parser.parse_args()
    compose(args.captures, args.design, args.output, args.font)


if __name__ == '__main__':
    main()
