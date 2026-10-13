"""Asset tool: draws the wooden Archer Tower in the map's cartoon style (dark ink outlines,
flat cel shading, blue-and-gold banner). Writes assets/towers/archer_tower.png.
Requires numpy and Pillow: python tools/draw_archer_tower.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets/towers/archer_tower.png"

SS = 4  # supersampling factor
W, H = 128, 210  # final size in pixels
INK = (38, 30, 26, 255)
WOOD = (156, 104, 56, 255)
WOOD_LIGHT = (196, 140, 80, 255)
WOOD_DARK = (110, 70, 38, 255)
WOOD_DEEP = (78, 48, 28, 255)
STONE = (176, 172, 164, 255)
STONE_LIGHT = (212, 208, 198, 255)
STONE_DARK = (130, 126, 120, 255)
BLUE = (44, 86, 176, 255)
BLUE_LIGHT = (78, 128, 214, 255)
GOLD = (236, 184, 56, 255)
IRON = (70, 72, 80, 255)
OUTLINE = 3.2 * SS  # ink line width


def P(points):
    return [(x * SS, y * SS) for x, y in points]


def poly(d, points, fill, width=OUTLINE):
    d.polygon(P(points), fill=fill, outline=INK, width=int(width))


def line(d, points, fill=INK, width=1.6):
    d.line(P(points), fill=fill, width=int(width * SS), joint="curve")


def shade(img, points, color, direction, strength, start=0.0):
    """Paints a soft gradient of `color` over a polygon. direction is "right" or "down"; the
    gradient runs from transparent at `start` to `strength` alpha at the far edge."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(P(points), fill=255)
    m = np.array(mask).astype(np.float64) / 255.0
    ys, xs = np.nonzero(m)
    if direction == "right":
        coord, lo, hi = np.arange(img.size[0])[None, :], xs.min(), xs.max()
    else:
        coord, lo, hi = np.arange(img.size[1])[:, None], ys.min(), ys.max()
    t = np.clip((coord - lo) / max(1, hi - lo), 0, 1)
    t = np.clip((t - start) / max(1e-6, 1 - start), 0, 1)
    alpha = m * t * strength
    arr = np.array(img).astype(np.float64)
    for c in range(3):
        arr[..., c] = arr[..., c] * (1 - alpha) + color[c] * alpha
    img.paste(Image.fromarray(arr.astype(np.uint8)))


def grain(img, x0, x1, y0, y1, rng, count):
    """Faint vertical wood-grain streaks."""
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(count):
        x = rng.uniform(x0, x1)
        top = rng.uniform(y0, y1 - 10)
        length = rng.uniform(8, y1 - top)
        d.line(P([(x, top), (x + rng.uniform(-0.6, 0.6), top + length)]), fill=(70, 40, 20, 60), width=int(0.7 * SS))


def stone_base(d):
    # A short drum of stone blocks the tower stands on.
    d.ellipse(P([(18, 172), (110, 204)]), fill=STONE_DARK, outline=INK, width=int(OUTLINE))
    d.rectangle(P([(18, 162), (110, 188)]), fill=STONE)
    d.line(P([(18, 162), (18, 188)]), fill=INK, width=int(OUTLINE))
    d.line(P([(110, 162), (110, 188)]), fill=INK, width=int(OUTLINE))
    d.ellipse(P([(18, 150), (110, 176)]), fill=STONE_LIGHT, outline=INK, width=int(OUTLINE))
    d.rectangle(P([(86, 166), (108, 190)]), fill=STONE_DARK)
    for x in (38, 62, 86):
        line(d, [(x, 175), (x, 188)], width=1.2)
    line(d, [(20, 182), (108, 182)], fill=(110, 106, 100, 255), width=1.0)


def body(d):
    # Tapered plank tower: front face plus a darker right side for depth.
    front = [(34, 72), (84, 72), (88, 166), (30, 166)]
    side = [(84, 72), (98, 78), (100, 160), (88, 166)]
    poly(d, side, WOOD_DARK)
    poly(d, front, WOOD)
    # Light along the left edge, plank seams, and iron bands.
    d.polygon(P([(36, 74), (46, 74), (44, 164), (33, 164)]), fill=WOOD_LIGHT)
    for t in (0.33, 0.66):
        top_x, bottom_x = 34 + 50 * t, 30 + 58 * t
        line(d, [(top_x, 74), (bottom_x, 164)], fill=WOOD_DEEP, width=1.2)
    for y in (98, 140):
        line(d, [(32, y), (86, y)], fill=IRON, width=2.6)
        line(d, [(86, y), (99, y + 1)], fill=IRON, width=2.6)
    # Arrow slit.
    poly(d, [(56, 104), (62, 104), (62, 128), (56, 128)], WOOD_DEEP, width=2 * SS)


def banner(d):
    pts = [(48, 78), (70, 78), (70, 128), (59, 120), (48, 128)]
    d.polygon(P(pts), fill=GOLD, outline=INK)
    inner = [(51, 80), (67, 80), (67, 122), (59, 116), (51, 122)]
    d.polygon(P(inner), fill=BLUE)
    d.polygon(P([(52, 81), (56, 81), (56, 118), (52, 121)]), fill=BLUE_LIGHT)
    # Gold arrowhead emblem.
    d.polygon(P([(59, 88), (64, 98), (60.5, 97), (60.5, 108), (57.5, 108), (57.5, 97), (54, 98)]), fill=GOLD)
    line(d, [(46, 78), (72, 78)], fill=WOOD_DEEP, width=2.4)


def braces(d):
    # Angled struts carrying the overhanging platform, like the card art.
    poly(d, [(24, 66), (30, 66), (40, 92), (35, 94)], WOOD_DARK, width=2.4 * SS)
    poly(d, [(96, 66), (102, 66), (90, 96), (85, 94)], WOOD_DEEP, width=2.4 * SS)


def platform(d):
    # Deck front, plus the inner back wall of the parapet seen over the front merlons.
    poly(d, [(14, 34), (114, 34), (114, 44), (14, 44)], WOOD_DEEP)
    poly(d, [(12, 54), (116, 54), (112, 70), (16, 70)], WOOD_DARK)
    for x in (34, 54, 74, 94):
        line(d, [(x, 56), (x - 0.5, 69)], fill=WOOD_DEEP, width=1.2)
    poly(d, [(10, 40), (118, 40), (118, 56), (10, 56)], WOOD)
    d.polygon(P([(12, 42), (116, 42), (116, 45), (12, 45)]), fill=WOOD_LIGHT)
    # Front merlons, with their lit tops showing.
    for x0 in (10, 38, 66, 94):
        poly(d, [(x0, 24), (x0 + 3, 20), (x0 + 27, 20), (x0 + 24, 24)], WOOD_LIGHT, width=2 * SS)
        poly(d, [(x0, 24), (x0 + 24, 24), (x0 + 24, 44), (x0, 44)], WOOD)
        d.polygon(P([(x0 + 2, 26), (x0 + 8, 26), (x0 + 8, 42), (x0 + 2, 42)]), fill=WOOD_LIGHT)
        line(d, [(x0 + 12, 26), (x0 + 12, 42)], fill=WOOD_DEEP, width=1.0)
    for x in (24, 52, 80, 104):
        d.ellipse(P([(x - 1.6, 48 - 1.6), (x + 1.6, 48 + 1.6)]), fill=IRON)


def pennant(d):
    line(d, [(64, 2), (64, 30)], fill=INK, width=3.4)
    line(d, [(64, 3), (64, 30)], fill=WOOD_LIGHT, width=1.4)
    d.polygon(P([(65, 4), (98, 9), (88, 13), (99, 18), (65, 20)]), fill=BLUE, outline=INK, width=int(2 * SS))
    d.polygon(P([(66, 6), (88, 9), (66, 11)]), fill=BLUE_LIGHT)
    d.ellipse(P([(61.5, 0), (66.5, 5)]), fill=GOLD, outline=INK, width=SS)


def main():
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(5)
    stone_base(d)
    shade(img, [(18, 162), (110, 162), (110, 196), (18, 196)], (90, 86, 82), "right", 0.45, 0.4)
    body(d)
    grain(img, 34, 86, 76, 164, rng, 40)
    # Rounded light: darker toward the right, and shadow under the overhanging platform.
    shade(img, [(34, 72), (84, 72), (88, 166), (30, 166)], (70, 40, 20), "right", 0.4, 0.35)
    shade(img, [(30, 166), (88, 166), (84, 72), (34, 72)], (60, 34, 18), "down", 0.0)
    shade(img, [(34, 70), (100, 70), (100, 96), (34, 96)], (255, 255, 255), "down", 0.0)
    d = ImageDraw.Draw(img)
    ao = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ao).rectangle(P([(30, 70), (100, 84)]), fill=(40, 22, 10, 110))
    ao = ao.filter(ImageFilter.GaussianBlur(SS * 3))
    body_mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(body_mask).polygon(P([(34, 72), (84, 72), (88, 166), (30, 166), (30, 72), (100, 72), (100, 160)]), fill=255)
    img.paste(Image.alpha_composite(img, ao), mask=body_mask)
    d = ImageDraw.Draw(img)
    banner(d)
    braces(d)
    pennant(d)
    platform(d)
    grain(img, 12, 116, 26, 68, rng, 50)
    shade(img, [(10, 40), (118, 40), (118, 70), (10, 70)], (70, 40, 20), "right", 0.3, 0.4)

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
