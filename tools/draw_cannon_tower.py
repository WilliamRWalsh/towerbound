"""Asset tool: draws the stone Cannon Tower in the same cartoon style as the wooden Archer Tower
(dark ink outlines, flat cel shading, blue-and-gold banner). The cannon itself is drawn by the
game on the open roof so it can turn. Writes assets/towers/cannon_tower.png.
Requires numpy and Pillow: python tools/draw_cannon_tower.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from draw_archer_tower import (BLUE, BLUE_LIGHT, GOLD, H, INK, OUTLINE, P, SS, STONE, STONE_DARK,
                               STONE_LIGHT, W, line, pennant, poly, shade, stone_base)

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets/towers/cannon_tower.png"

MORTAR = (112, 106, 98, 255)
STONE_DEEP = (96, 92, 88, 255)
ROOF = (88, 78, 66, 255)
ROOF_LIGHT = (120, 106, 88, 255)


def blocks(img, rng, x_at, y0, y1, row_h, width_range):
    """Stone courses between y0 and y1. x_at(y) gives the face's (left, right) at that height."""
    d = ImageDraw.Draw(img, "RGBA")
    y = y0
    row = 0
    while y < y1 - 2:
        bottom = min(y1, y + row_h)
        left, right = x_at((y + bottom) / 2)
        x = left - (rng.uniform(0, width_range[0]) if row % 2 else 0)
        while x < right:
            w = rng.uniform(*width_range)
            x0, x1 = max(x, left), min(x + w, right)
            tint = rng.uniform(-14, 14)
            d.rectangle(P([(x0 + 0.6, y + 0.6), (x1 - 0.6, bottom - 0.6)]),
                        fill=tuple(int(np.clip(c + tint, 0, 255)) for c in STONE[:3]) + (255,))
            d.line(P([(x0 + 1, y + 1.2), (x1 - 1.5, y + 1.2)]), fill=(255, 255, 255, 40), width=int(1.0 * SS))
            if x1 < right:
                d.line(P([(x1, y), (x1, bottom)]), fill=MORTAR, width=int(1.1 * SS))
            x += w
        d.line(P([(left, bottom), (right, bottom)]), fill=MORTAR, width=int(1.2 * SS))
        y = bottom
        row += 1


def body(img, rng):
    d = ImageDraw.Draw(img)
    # A round-shouldered stone keep, slightly wider at the foot, with a darker right side.
    front = [(30, 78), (90, 78), (94, 166), (26, 166)]
    side = [(90, 78), (102, 84), (104, 160), (94, 166)]
    poly(d, side, STONE_DARK)
    poly(d, front, STONE)
    blocks(img, rng, lambda y: (30 - 4 * (y - 78) / 88 + 1.5, 90 + 4 * (y - 78) / 88 - 1.5), 80, 164, 11, (12, 20))
    d = ImageDraw.Draw(img)
    for y in range(88, 160, 11):
        line(d, [(92 + 4 * (y - 78) / 88, y), (103, y + 2)], fill=STONE_DEEP, width=1.0)
    d.polygon(P(front), outline=INK, width=int(OUTLINE))
    d.polygon(P(side), outline=INK, width=int(OUTLINE))
    # Narrow window.
    poly(d, [(55, 104), (65, 104), (65, 124), (55, 124)], (30, 26, 24, 255), width=2 * SS)
    d.pieslice(P([(55, 99), (65, 109)]), 180, 360, fill=(30, 26, 24, 255), outline=INK, width=2 * SS)


def banner(d):
    """Blue banner with a gold cannonball, matching the card."""
    pts = [(46, 80), (66, 80), (66, 128), (56, 120), (46, 128)]
    d.polygon(P(pts), fill=GOLD, outline=INK)
    inner = [(49, 82), (63, 82), (63, 122), (56, 116), (49, 122)]
    d.polygon(P(inner), fill=BLUE)
    d.polygon(P([(50, 83), (53, 83), (53, 118), (50, 121)]), fill=BLUE_LIGHT)
    d.ellipse(P([(51, 92), (61, 102)]), fill=GOLD, outline=INK, width=SS)
    d.ellipse(P([(53, 94), (56, 97)]), fill=(255, 236, 170, 255))
    line(d, [(59, 93), (62, 89)], fill=INK, width=1.0)
    line(d, [(44, 80), (68, 80)], fill=STONE_DEEP, width=2.4)


def parapet(img, rng):
    d = ImageDraw.Draw(img)
    # Corbels under the overhanging top, stepped out from the keep.
    poly(d, [(20, 66), (108, 66), (100, 80), (28, 80)], STONE_DARK)
    for x in range(26, 104, 12):
        poly(d, [(x, 68), (x + 7, 68), (x + 6, 78), (x + 1, 78)], STONE_DEEP, width=1.6 * SS)
    # Open roof where the cannon stands, seen over the front wall.
    d.ellipse(P([(18, 18), (110, 54)]), fill=STONE_DARK, outline=INK, width=int(OUTLINE))
    d.ellipse(P([(26, 22), (102, 50)]), fill=ROOF, outline=INK, width=int(2 * SS))
    d.ellipse(P([(30, 24), (90, 44)]), fill=ROOF_LIGHT)
    for x in range(38, 96, 12):
        line(d, [(x, 25), (x - 4, 49)], fill=(70, 62, 52, 255), width=1.0)
    # Front wall of the parapet.
    poly(d, [(12, 40), (116, 40), (116, 68), (12, 68)], STONE)
    blocks(img, rng, lambda y: (13.5, 114.5), 42, 66, 8, (14, 22))
    d = ImageDraw.Draw(img)
    d.polygon(P([(12, 40), (116, 40), (116, 68), (12, 68)]), outline=INK, width=int(OUTLINE))
    # Crenellations along the front, lit on top.
    for x0 in (10, 38, 66, 94):
        poly(d, [(x0, 30), (x0 + 3, 26), (x0 + 27, 26), (x0 + 24, 30)], STONE_LIGHT, width=2 * SS)
        poly(d, [(x0, 30), (x0 + 24, 30), (x0 + 24, 46), (x0, 46)], STONE)
        d.polygon(P([(x0 + 2, 32), (x0 + 7, 32), (x0 + 7, 44), (x0 + 2, 44)]), fill=STONE_LIGHT)
        line(d, [(x0 + 1, 38), (x0 + 23, 38)], fill=MORTAR, width=1.0)


def main():
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    rng = np.random.default_rng(11)
    d = ImageDraw.Draw(img)
    stone_base(d)
    shade(img, [(18, 162), (110, 162), (110, 196), (18, 196)], (90, 86, 82), "right", 0.45, 0.4)
    body(img, rng)
    # Rounded light across the keep, and shadow under the overhang.
    shade(img, [(30, 78), (90, 78), (94, 166), (26, 166)], (60, 56, 52), "right", 0.45, 0.35)
    ao = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ao).rectangle(P([(26, 76), (104, 90)]), fill=(30, 26, 22, 120))
    ao = ao.filter(ImageFilter.GaussianBlur(SS * 3))
    body_mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(body_mask).polygon(P([(30, 78), (102, 78), (104, 160), (94, 166), (26, 166)]), fill=255)
    img.paste(Image.alpha_composite(img, ao), mask=body_mask)
    d = ImageDraw.Draw(img)
    banner(d)
    parapet(img, rng)
    shade(img, [(12, 40), (116, 40), (116, 68), (12, 68)], (60, 56, 52), "right", 0.35, 0.4)

    # Subtle painted grain so the flat fills sit with the map's texture.
    arr = np.array(img).astype(np.float64)
    noise = rng.normal(0, 5, arr.shape[:2])
    noise = np.array(Image.fromarray(((noise + 128).clip(0, 255)).astype(np.uint8)).filter(ImageFilter.GaussianBlur(SS * 0.7))).astype(np.float64) - 128
    arr[..., :3] = np.clip(arr[..., :3] + noise[..., None] * 1.5, 0, 255)
    img = Image.fromarray(arr.astype(np.uint8))

    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
