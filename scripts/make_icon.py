#!/usr/bin/env python3
"""
Generate a starter 1024x1024 app icon (Resources/icon-1024.png).

A simple "cascading workspace panes" mark on a diagonal gradient — recognizable
at menu-bar size and easy to replace later with your own artwork. Pure Pillow,
no external assets.

Usage:  python3 scripts/make_icon.py
"""
from PIL import Image, ImageDraw
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "icon-1024.png")


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(top, bottom, t)
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def main():
    # macOS-style squircle-ish rounded square with a diagonal indigo→violet wash.
    bg = diagonal_gradient(SIZE, (99, 102, 241), (139, 92, 246))  # indigo → violet
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), rounded_mask(SIZE, int(SIZE * 0.22)))

    draw = ImageDraw.Draw(icon)

    # Three cascading "window" panes, back to front.
    pane_w, pane_h = int(SIZE * 0.46), int(SIZE * 0.34)
    radius = int(SIZE * 0.045)
    offsets = [(int(SIZE * 0.20), int(SIZE * 0.22)),
               (int(SIZE * 0.27), int(SIZE * 0.33)),
               (int(SIZE * 0.34), int(SIZE * 0.44))]
    fills = [(255, 255, 255, 90), (255, 255, 255, 160), (255, 255, 255, 245)]

    for (ox, oy), fill in zip(offsets, fills):
        box = [ox, oy, ox + pane_w, oy + pane_h]
        draw.rounded_rectangle(box, radius=radius, fill=fill)
        # Title-bar dot on the frontmost pane only.
        if fill[3] > 200:
            cx, cy = ox + int(pane_w * 0.10), oy + int(pane_h * 0.16)
            r = int(SIZE * 0.018)
            for k in range(3):
                draw.ellipse([cx + k * r * 3 - r, cy - r, cx + k * r * 3 + r, cy + r],
                             fill=(139, 92, 246, 255))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT)
    print(f"Wrote {os.path.abspath(OUT)} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
