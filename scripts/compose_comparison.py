#!/usr/bin/env python3
"""Compose compact README figures from actual, matched browser screenshots.

Requires Pillow only for this optional documentation step. No UI is redrawn.
"""
import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(path, size):
    if path:
        return ImageFont.truetype(str(path), size)
    for name in ('DejaVuSans.ttf', 'Arial.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    raise SystemExit('Supply --font with a local Latin TTF for the figure captions.')


def compose(captures, output, mobile, font_path):
    names = ('a-portrait.jpg', 'b-portrait.jpg') if mobile else ('a-desktop.jpg', 'b-desktop.jpg')
    images = [Image.open(captures / name).convert('RGB') for name in names]
    expected = (390, 844) if mobile else (1280, 800)
    if any(image.size != expected for image in images):
        raise SystemExit('Source screenshot dimensions do not match the frozen viewport.')
    if mobile:
        pane_width, pane_height, margin, gap = 390, 844, 20, 20
    else:
        # Identical center crop preserves each complete modal, at readable scale.
        images = [image.crop((260, 40, 1020, 760)) for image in images]
        pane_width, pane_height, margin, gap = 690, 654, 20, 20
        images = [image.resize((pane_width, pane_height), Image.Resampling.LANCZOS) for image in images]
    width = 2 * margin + 2 * pane_width + gap
    top, bottom = 96, 40
    canvas = Image.new('RGB', (width, top + pane_height + bottom), '#12272b')
    draw = ImageDraw.Draw(canvas)
    draw.text((margin, 16), 'Same brief. Two native Godot interfaces.', font=font(font_path, 23), fill='#f5eddd')
    for index, (title, image) in enumerate(zip(('WITHOUT SKILL', 'WITH SKILL'), images)):
        x = margin + index * (pane_width + gap)
        draw.text((x, 59), title, font=font(font_path, 17), fill='#c8b582' if index == 0 else '#b4d4bc')
        canvas.paste(image, (x, top))
    caption = '390 x 844 | fresh launch | initial English state' if mobile else '1280 x 800 | same center crop | initial English state'
    draw.text((margin, top + pane_height + 11), caption, font=font(font_path, 14), fill='#aabbb5')
    output.mkdir(parents=True, exist_ok=True)
    destination = output / ('comparison-mobile.webp' if mobile else 'comparison-desktop.webp')
    for quality in (90, 86, 82, 78):
        canvas.save(destination, 'WEBP', quality=quality, method=6, exif=b'', xmp=b'')
        if destination.stat().st_size <= 200_000:
            break
    if destination.stat().st_size > 200_000:
        raise SystemExit('Figure exceeds the 200 KB target; inspect before selecting a smaller presentation.')
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    print(destination.name + ': ' + str(destination.stat().st_size) + ' bytes; SHA-256 ' + digest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--font', type=Path)
    args = parser.parse_args()
    for mobile in (False, True):
        compose(args.captures, args.output, mobile, args.font)


if __name__ == '__main__':
    main()
