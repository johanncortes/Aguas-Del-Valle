#!/usr/bin/env python3
"""Generates the app icon: a white water drop on the brand's dark blue.

Pure Python (no Pillow needed). Writes:
  assets/app_icon.png             1024x1024, opaque (iOS and legacy Android)
  assets/app_icon_foreground.png  1024x1024, transparent drop sized for the
                                  Android adaptive icon safe zone

Run from the project root:  python3 tool/generate_app_icon.py
Then:                       dart run flutter_launcher_icons
"""

import math
import os
import struct
import zlib

SIZE = 1024
BACKGROUND = (0x0D, 0x47, 0xA1)  # AppTheme.primaryBlue
DROP = (0xFF, 0xFF, 0xFF)


def drop_shape(scale):
    """Teardrop = circle + the triangle from the tip to its tangent points.

    Returns an `inside(x, y)` test and a `near_edge(x, y)` test (pixels whose
    center is close to the outline get supersampled for smooth edges).
    """
    radius = 230 * scale
    height = 660 * scale  # tip to bottom of the circle
    cx = SIZE / 2
    # Center the whole drop vertically
    tip_y = SIZE / 2 - height / 2
    cy = tip_y + height - radius

    # Tangent points: the sides from the tip touch the circle where the
    # radius is perpendicular to them, at angle acos(r / d) from vertical.
    theta = math.acos(radius / (cy - tip_y))
    lx, ly = cx - radius * math.sin(theta), cy - radius * math.cos(theta)
    rx, ry = cx + radius * math.sin(theta), ly

    def side(ax, ay, bx, by, px, py):
        return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

    def in_triangle(px, py):
        d1 = side(cx, tip_y, lx, ly, px, py)
        d2 = side(lx, ly, rx, ry, px, py)
        d3 = side(rx, ry, cx, tip_y, px, py)
        has_neg = d1 < 0 or d2 < 0 or d3 < 0
        has_pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (has_neg and has_pos)

    def inside(px, py):
        if (px - cx) ** 2 + (py - cy) ** 2 <= radius * radius:
            return True
        return in_triangle(px, py)

    def line_distance(ax, ay, bx, by, px, py):
        length = math.hypot(bx - ax, by - ay)
        return abs(side(ax, ay, bx, by, px, py)) / length

    def near_edge(px, py):
        if abs(math.hypot(px - cx, py - cy) - radius) < 2:
            return True
        if py <= ly + 2 and (
                line_distance(cx, tip_y, lx, ly, px, py) < 2 or
                line_distance(cx, tip_y, rx, ry, px, py) < 2):
            return True
        return False

    return inside, near_edge


def render(scale, background):
    inside, near_edge = drop_shape(scale)
    samples = [(i + 0.5) / 4 for i in range(4)]
    rows = []
    for y in range(SIZE):
        row = bytearray([0])  # PNG filter type: none
        for x in range(SIZE):
            if near_edge(x + 0.5, y + 0.5):
                hits = sum(inside(x + sx, y + sy)
                           for sx in samples for sy in samples)
                coverage = hits / 16
            else:
                coverage = 1.0 if inside(x + 0.5, y + 0.5) else 0.0

            if background is None:
                row += bytes((*DROP, round(255 * coverage)))
            else:
                row += bytes(round(d * coverage + b * (1 - coverage))
                             for d, b in zip(DROP, background)) + b'\xff'
        rows.append(bytes(row))
    return b''.join(rows)


def write_png(path, raw_rgba):
    def chunk(kind, data):
        body = kind + data
        return (struct.pack('>I', len(data)) + body +
                struct.pack('>I', zlib.crc32(body) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) +
           chunk(b'IDAT', zlib.compress(raw_rgba, 9)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)


def main():
    os.makedirs('assets', exist_ok=True)
    # Full icon: drop at 75% of the canvas height
    write_png('assets/app_icon.png', render(1.0, BACKGROUND))
    # Adaptive foreground (Android 8+). flutter_launcher_icons insets it by
    # 16% per side, so the drop ends up ~2/3 of the visible icon, well
    # inside the safe zone launchers keep when cropping to circles,
    # squircles, etc.
    write_png('assets/app_icon_foreground.png', render(1.0, None))
    print('Wrote assets/app_icon.png and assets/app_icon_foreground.png')


if __name__ == '__main__':
    main()
