"""One-off asset tool: builds art/cards/cannon_tower.png from sketches/archer.png, so the
Cannon Tower card shares the Archer Tower card's frame, painting, and stone tower.

Runs the archer card's cleanup (cost, second archer, background castle), then paints out the
archer, bow, and flag, and paints in an iron cannon firing a puff of smoke, a powder keg, and a
cannonball emblem on the banner. Rewrites the cost, title, description, icon, and stats.
Requires numpy, scipy, and Pillow: python tools/edit_cannon_card.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import edit_archer_card as archer

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "art/cards/cannon_tower.png"

# Coordinates below are measured on the finished archer card; the sketch has a 23 × 24 px margin.
OFFSET = np.array([23, 24])
COST = "3"
TITLE = "Cannon Tower"
DESCRIPTION = ["A sturdy stone tower that", "fires slow, heavy shots that", "crush enemies."]
STATS = {(206, 1280): "3.0", (440, 1280): "0.6", (706, 1280): "5.0"}

TITLE_FONT = ("/System/Library/Fonts/Supplemental/Baskerville.ttc", 1)  # Baskerville Bold
BODY_FONT = ("/System/Library/Fonts/Palatino.ttc", 0)
STAT_FONT = ("/System/Library/Fonts/Palatino.ttc", 0)
INK = (36, 28, 22)
STAT_INK = (238, 228, 205)

IRON_DARK = np.array([24, 26, 32])
IRON = np.array([64, 68, 80])
IRON_LIGHT = np.array([168, 172, 186])
WOOD = (120, 78, 44)
WOOD_DARK = (74, 46, 26)


def at(points):
    """Card coordinates to sketch coordinates."""
    return [(x + OFFSET[0], y + OFFSET[1]) for x, y in points]


def fill(rgb, points, grow=2, guide=None):
    return archer.poisson_fill(rgb, archer.polygon_mask(rgb.shape, at(points), grow=grow), guide)


def remove_archer(rgb):
    """The archer, bow, arrow, quiver, and flag above the battlements. The bow and the archer's
    body get a smooth fill (the cannon, keg, and smoke cover them); the open sky where the flag
    was copies the clouds from the right side of the painting."""
    rgb = fill(rgb, [
        (455, 132), (470, 126), (502, 136), (532, 164), (554, 204), (562, 242), (624, 240),
        (628, 264), (566, 270), (558, 306), (542, 344), (532, 384), (510, 396), (488, 374),
        (472, 354), (372, 350), (368, 366), (374, 420), (330, 424), (302, 404), (296, 330),
        (312, 292), (300, 250), (455, 250),
    ], grow=3)
    return fill(rgb, [(276, 96), (345, 90), (400, 118), (458, 128), (462, 254), (300, 254), (276, 204), (270, 140)],
                grow=3, guide=archer.shifted(rgb, 300, 0))


def replace_emblem(rgb):
    """Swaps the banner's gold trident for a gold cannonball."""
    rgb = fill(rgb, [(242, 500), (314, 500), (314, 658), (242, 658)], grow=1)
    img = Image.fromarray(rgb.astype(np.uint8))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = at([(279, 572)])[0]
    d.ellipse([cx - 27, cy - 27, cx + 27, cy + 27], fill=(120, 84, 30, 255))
    d.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(214, 164, 72, 255))
    d.ellipse([cx - 18, cy - 20, cx + 8, cy + 4], fill=(236, 196, 110, 255))
    d.ellipse([cx - 13, cy - 15, cx - 3, cy - 6], fill=(250, 226, 160, 255))
    # Fuse with a little spark.
    d.line([(cx + 14, cy - 20), (cx + 22, cy - 34)], fill=(120, 84, 30, 255), width=5)
    d.polygon([(cx + 23, cy - 46), (cx + 27, cy - 37), (cx + 36, cy - 36), (cx + 28, cy - 31),
               (cx + 30, cy - 22), (cx + 23, cy - 28), (cx + 16, cy - 23), (cx + 18, cy - 32),
               (cx + 11, cy - 37), (cx + 20, cy - 37)], fill=(236, 196, 110, 255))
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    return np.array(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")).astype(np.float64)


def barrel_layer(length, breech_r, muzzle_r, ss=3):
    """A horizontal cannon barrel lit from above, breech on the left. Returns an RGBA image
    whose breech center sits at (pad, height / 2)."""
    L, pad = length * ss, 14 * ss
    rmax = (breech_r + 6) * ss
    w, h = L + 2 * pad, 2 * rmax + 2 * pad
    ys, xs = np.mgrid[:h, :w].astype(np.float64)
    cy = h / 2
    u = (xs - pad) / L  # 0 at the breech, 1 at the muzzle
    radius = (breech_r + (muzzle_r - breech_r) * np.clip(u, 0, 1)) * ss
    # Reinforcing rings and the flared muzzle lip.
    for ring, extra in ((0.04, 4), (0.32, 3), (0.62, 3), (0.97, 5)):
        radius = np.where(np.abs(u - ring) < 0.035, radius + extra * ss, radius)
    t = (ys - cy) / radius
    inside = (np.abs(t) <= 1) & (u >= 0) & (u <= 1)
    # Cascabel knob behind the breech.
    knob = np.hypot(xs - (pad - 8 * ss), ys - cy) < 9 * ss
    knob_t = np.clip((ys - cy) / (9 * ss), -1, 1)
    t = np.where(knob & ~inside, knob_t, t)
    inside |= knob
    light = np.clip(0.5 - 0.5 * t, 0, 1) ** 1.6
    color = IRON_DARK[None, None] + (IRON[None, None] - IRON_DARK[None, None]) * (light[..., None] * 1.6).clip(0, 1)
    color += (IRON_LIGHT - IRON)[None, None] * np.exp(-((t + 0.55) / 0.14) ** 2)[..., None]
    rim = np.clip((np.abs(t) - 0.82) / 0.18, 0, 1)
    color = color * (1 - 0.7 * rim[..., None])
    alpha = inside.astype(np.float64) * 255
    out = np.dstack([color.clip(0, 255), alpha]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    # Bore at the muzzle.
    d = ImageDraw.Draw(img)
    mx = pad + L
    mr = (muzzle_r + 5) * ss
    d.ellipse([mx - 6 * ss, cy - mr, mx + 6 * ss, cy + mr], fill=(52, 55, 64, 255))
    d.ellipse([mx - 4 * ss, cy - mr * 0.62, mx + 4 * ss, cy + mr * 0.62], fill=(8, 8, 10, 255))
    img = img.resize((w // ss, h // ss), Image.LANCZOS)
    return img, (pad // ss, h / 2 / ss)


def puff(layer, center, radius, tone, rng):
    """One rounded smoke billow, lit from the upper left, with a soft edge and faint texture."""
    cx, cy = center
    box = (int(cx - radius) - 1, int(cy - radius) - 1, int(cx + radius) + 2, int(cy + radius) + 2)
    ys, xs = np.mgrid[box[1]:box[3], box[0]:box[2]].astype(np.float64)
    d = np.hypot(xs - cx, ys - cy) / radius
    lit = np.clip(-((xs - cx) * 0.5 + (ys - cy)) / radius, -1, 1)
    texture = rng.normal(0, 1, d.shape)
    texture = np.array(Image.fromarray(((texture * 30 + 128).clip(0, 255)).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))).astype(np.float64) - 128
    shade = 0.8 + 0.2 * lit + texture / 400
    color = np.clip(np.array(tone, dtype=np.float64)[None, None] * shade[..., None], 0, 255)
    edge = np.clip((1.0 - d) / 0.3, 0, 1)
    alpha = edge * edge * (3 - 2 * edge) * 225
    patch = Image.fromarray(np.dstack([color, alpha]).astype(np.uint8), "RGBA")
    layer.alpha_composite(patch, (box[0], box[1]))


def paint_cannon(rgb):
    img = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    ox, oy = OFFSET

    # Powder keg where the archer knelt, left of the front merlon.
    keg = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(keg)
    kx, ky = 306 + ox, 344 + oy
    d.rounded_rectangle([kx, ky, kx + 58, ky + 76], radius=16, fill=WOOD_DARK)
    d.rounded_rectangle([kx + 3, ky + 3, kx + 55, ky + 73], radius=14, fill=WOOD)
    d.rectangle([kx + 8, ky + 6, kx + 18, ky + 70], fill=(150, 104, 62))
    for y in (ky + 14, ky + 60):
        d.rectangle([kx + 1, y, kx + 57, y + 5], fill=(58, 60, 66))
    d.ellipse([kx + 4, ky - 6, kx + 54, ky + 10], fill=(96, 62, 34))
    d.ellipse([kx + 8, ky - 4, kx + 50, ky + 7], fill=(138, 94, 54))
    img.alpha_composite(keg.filter(ImageFilter.GaussianBlur(0.7)))

    # Carriage: a dark wooden cheek under the breech and a spoked wheel over the merlon.
    carriage = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(carriage)
    d.polygon(at([(386, 352), (392, 326), (430, 316), (466, 322), (470, 352)]), fill=WOOD_DARK)
    wx, wy = at([(444, 342)])[0]
    d.ellipse([wx - 22, wy - 22, wx + 22, wy + 22], fill=(48, 50, 56))
    d.ellipse([wx - 18, wy - 18, wx + 18, wy + 18], fill=WOOD)
    for k in range(6):
        ang = k * np.pi / 3
        d.line([(wx, wy), (wx + np.cos(ang) * 17, wy + np.sin(ang) * 17)], fill=WOOD_DARK, width=4)
    d.ellipse([wx - 6, wy - 6, wx + 6, wy + 6], fill=(58, 60, 66))
    img.alpha_composite(carriage.filter(ImageFilter.GaussianBlur(0.6)))

    barrel, (bx, by) = barrel_layer(length=190, breech_r=28, muzzle_r=20)
    angle = 17.0
    rotated = barrel.rotate(angle, resample=Image.BICUBIC, expand=True)
    # Where the breech center lands after rotating about the layer center.
    w, h = barrel.size
    rw, rh = rotated.size
    vx, vy = bx - w / 2, by - h / 2
    a = np.deg2rad(angle)
    rx, ry = vx * np.cos(a) + vy * np.sin(a), -vx * np.sin(a) + vy * np.cos(a)
    breech = np.array([404, 312]) + OFFSET
    img.alpha_composite(rotated, (int(breech[0] - (rx + rw / 2)), int(breech[1] - (ry + rh / 2))))
    muzzle = breech + np.array([np.cos(a), -np.sin(a)]) * 190

    # Muzzle flash, then billowing smoke rolling forward and up.
    flash = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(flash)
    mx, my = muzzle
    for r, color in ((46, (255, 150, 40, 150)), (32, (255, 196, 80, 220)), (18, (255, 244, 190, 255))):
        spikes = []
        for i in range(16):
            ang = np.deg2rad(-17 + i * 22.5)
            rr = r * (1.0 if i % 2 == 0 else 0.5)
            spikes.append((mx + 8 + np.cos(ang) * rr * 1.3, my - 2 + np.sin(ang) * rr))
        d.polygon(spikes, fill=color)
    img.alpha_composite(flash.filter(ImageFilter.GaussianBlur(2.5)))

    smoke = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rng = np.random.default_rng(3)
    # Billows grow and pale as they roll away from the muzzle and drift upward.
    aim = np.array([np.cos(a), -np.sin(a)])
    side = np.array([aim[1], -aim[0]])
    for i in range(26):
        t = i / 25
        center = muzzle + aim * (34 + 150 * t) + side * rng.uniform(-30, 30) * (0.4 + t) + np.array([0, -70 * t * t])
        radius = 20 + 26 * t + rng.uniform(-4, 4)
        gray = 168 + 60 * t + rng.uniform(-6, 6)
        puff(smoke, center, radius, (gray, gray - 2, gray - 5), rng)
    img.alpha_composite(smoke.filter(ImageFilter.GaussianBlur(1.0)))
    return np.array(img.convert("RGB")).astype(np.float64)


def font(spec, size):
    return ImageFont.truetype(spec[0], size, index=spec[1])


def draw_text(img, xy, text, fnt, fill_color, anchor="ls"):
    ImageDraw.Draw(img).text(xy, text, font=fnt, fill=fill_color, anchor=anchor)


def rewrite_text(rgb):
    # Clear the title, description, icon arrows, and stat numbers.
    rgb = fill(rgb, [(196, 894), (642, 894), (642, 954), (196, 954)], grow=0)
    for top in (1046, 1096, 1146):
        rgb = fill(rgb, [(266, top), (744, top), (744, top + 46), (266, top + 46)], grow=0)
    for x0, x1 in ((170, 244), (402, 478), (666, 746)):
        rgb = fill(rgb, [(x0, 1256), (x1, 1256), (x1, 1304), (x0, 1304)], grow=0)
    img = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    ox, oy = OFFSET

    # Icon: repaint the dark disc and draw a cannonball with a lit fuse.
    d = ImageDraw.Draw(img)
    icx, icy = 162 + ox, 1107 + oy
    disc = tuple(int(v) for v in rgb[icy + 52, icx])
    d.ellipse([icx - 62, icy - 62, icx + 62, icy + 62], fill=disc)
    parchment = (226, 206, 168)
    d.ellipse([icx - 34, icy - 22, icx + 26, icy + 38], fill=parchment)
    d.ellipse([icx - 22, icy - 10, icx - 8, icy + 4], fill=disc)
    d.rectangle([icx + 8, icy - 26, icx + 22, icy - 14], fill=parchment)
    d.line([(icx + 15, icy - 22), (icx + 26, icy - 36)], fill=parchment, width=5)
    d.polygon([(icx + 30, icy - 56), (icx + 35, icy - 44), (icx + 47, icy - 42), (icx + 36, icy - 36),
               (icx + 39, icy - 24), (icx + 29, icy - 32), (icx + 19, icy - 26), (icx + 23, icy - 38),
               (icx + 14, icy - 45), (icx + 26, icy - 45)], fill=parchment)

    # Title in small caps: bigger initials, like the archer card.
    big, small = font(TITLE_FONT, 60), font(TITLE_FONT, 47)
    pieces = []
    for word_i, word in enumerate(TITLE.upper().split()):
        if word_i:
            pieces.append((" ", small))
        pieces.append((word[0], big))
        pieces.append((word[1:], small))
    total = sum(d.textlength(text, font=f) for text, f in pieces)
    x = 418 + ox - total / 2
    baseline = 947 + oy
    for text, f in pieces:
        draw_text(img, (x, baseline), text, f, INK)
        x += d.textlength(text, font=f)

    body = font(BODY_FONT, 38)
    for i, line in enumerate(DESCRIPTION):
        draw_text(img, (272 + ox, 1080 + oy + i * 50), line, body, INK)

    stat = font(STAT_FONT, 62)
    for (sx, sy), text in STATS.items():
        draw_text(img, (sx + ox, sy + oy), text, stat, STAT_INK, anchor="mm")
    return np.array(img.convert("RGB")).astype(np.float64)


def draw_cost(rgb):
    card = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    cx, cy = archer.GEM_CENTER
    card = Image.alpha_composite(card, archer.number_layer(card.size, (cx, cy + 2), COST))
    return np.array(card.convert("RGB")).astype(np.float64)


def main():
    rgb = np.array(Image.open(archer.SOURCE).convert("RGB")).astype(np.float64)
    rgb = archer.erase_cost(rgb)
    rgb = draw_cost(rgb)
    rgb = archer.remove_second_archer(rgb)
    rgb = archer.remove_background_castle(rgb)
    rgb = remove_archer(rgb)
    rgb = replace_emblem(rgb)
    rgb = paint_cannon(rgb)
    rgb = rewrite_text(rgb)
    card = archer.cut_out_card(rgb)
    card.save(OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)} {card.size}")


if __name__ == "__main__":
    main()
