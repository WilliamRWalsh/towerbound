"""One-off asset tool: builds the Fireball, Upgrade, Heal, and Barricade cards from sketches/archer.png, so
they share the Archer Tower card's frame and painting.

Runs the archer card's cleanup (cost, second archer, background castle), then paints each
card's subject over the painting:
- Fireball: a dusk-red sky and a flaming meteor streaking down past the tower.
- Upgrade: a golden aura, a glowing smith's hammer, and rising chevrons.
- Heal: a soft green light around the tower, light rays, and a glowing heart.
- Barricade: a spiked wooden barricade across the foreground, lashed with rope.
Rewrites the cost, title, description, icon, and the three stat boxes (value and label).
Requires numpy, scipy, and Pillow: python tools/make_spell_cards.py [card names...]
Without names it builds every card.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import edit_archer_card as archer

ROOT = Path(__file__).resolve().parent.parent

# Coordinates below are measured on the finished archer card; the sketch has a 23 × 24 px margin.
OFFSET = np.array([23, 24])
# The painting inside the frame, kept clear of the gold border.
ART_BOX = (70, 66, 770, 836)

TITLE_FONT = ("/System/Library/Fonts/Supplemental/Baskerville.ttc", 1)  # Baskerville Bold
BODY_FONT = ("/System/Library/Fonts/Palatino.ttc", 0)
STAT_FONT = ("/System/Library/Fonts/Palatino.ttc", 0)
INK = (36, 28, 22)
STAT_INK = (238, 228, 205)
LABEL_INK = (226, 206, 160)
PARCHMENT = (226, 206, 168)

# Stat boxes: x range of each dark panel's interior, and the shared y range.
STAT_BOXES = ((66, 276), (312, 538), (566, 750))
STAT_TOP, STAT_BOTTOM = 1238, 1350

CARDS = {
    "fireball": {
        "cost": "3",
        "title": "Fireball",
        "description": ["Hurls a ball of fire that", "burns every enemy in a", "small area."],
        "stats": [("3.0", "DAMAGE"), ("2.0", "RADIUS"), ("ANY", "TARGET")],
    },
    "upgrade": {
        "cost": "3",
        "title": "Upgrade",
        "description": ["Upgrades one of your", "towers to attack 50%", "faster. Once per tower."],
        "stats": [("+50%", "ATTACK SPEED"), ("TOWER", "TARGET"), ("1", "PER TOWER")],
    },
    "heal": {
        "cost": "2",
        "title": "Heal",
        "description": ["Restores 5 health to", "your castle, up to its", "full health."],
        "stats": [("+5", "HEALTH"), ("CASTLE", "TARGET"), ("20", "MAX HEALTH")],
    },
    "barricade": {
        "cost": "2",
        "title": "Barricade",
        "description": ["Blocks the road. Enemies", "must break through it", "before moving on."],
        "stats": [("5", "HEALTH"), ("PATH", "TARGET"), ("HALTS", "ENEMIES")],
    },
}


def at(points):
    """Card coordinates to sketch coordinates."""
    return [(x + OFFSET[0], y + OFFSET[1]) for x, y in points]


def fill(rgb, points, grow=2, guide=None):
    return archer.poisson_fill(rgb, archer.polygon_mask(rgb.shape, at(points), grow=grow), guide)


def font(spec, size):
    return ImageFont.truetype(spec[0], size, index=spec[1])


def to_image(rgb):
    return Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")


def to_array(img):
    return np.array(img.convert("RGB")).astype(np.float64)


def art_mask(size, feather=18):
    """Soft mask over the painting inside the frame, as floats 0-1."""
    x0, y0, x1, y1 = (v + o for v, o in zip(ART_BOX, (*OFFSET, *OFFSET)))
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([x0, y0, x1, y1], radius=40, fill=255)
    return np.array(m.filter(ImageFilter.GaussianBlur(feather))).astype(np.float64)[..., None] / 255


def glow(img, draw_fn, blur):
    """Draws onto a fresh layer, blurs it, and composites it over the image."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)) if blur else layer)


def radial(size, center, radius, color, strength=1.0):
    """Layer with a soft radial glow fading out at `radius`."""
    h, w = size[1], size[0]
    ys, xs = np.mgrid[:h, :w].astype(np.float64)
    d = np.hypot(xs - center[0], ys - center[1]) / radius
    alpha = np.clip(1.0 - d, 0, 1) ** 1.8 * 255 * strength
    rgba = np.zeros((h, w, 4))
    rgba[..., :3] = color
    rgba[..., 3] = alpha
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def sparkles(img, rng, count, box, color, size_range=(4, 11)):
    def draw(d):
        x0, y0, x1, y1 = box
        for _ in range(count):
            cx, cy = rng.uniform(x0, x1) + OFFSET[0], rng.uniform(y0, y1) + OFFSET[1]
            r = rng.uniform(*size_range)
            d.polygon([(cx, cy - r), (cx + r * 0.25, cy - r * 0.25), (cx + r, cy), (cx + r * 0.25, cy + r * 0.25),
                       (cx, cy + r), (cx - r * 0.25, cy + r * 0.25), (cx - r, cy), (cx - r * 0.25, cy - r * 0.25)],
                      fill=color)
    glow(img, draw, 3)
    glow(img, draw, 0)


# --- Fireball ---------------------------------------------------------------------------------

def paint_fireball(rgb):
    # Dusk: warm the whole painting toward red-orange and darken it slightly.
    mask = art_mask((rgb.shape[1], rgb.shape[0]))
    rows = np.linspace(0, 1, rgb.shape[0])[:, None, None]
    warm = rgb * np.array([1.05, 0.62, 0.45]) + np.array([40, 8, 0])
    warm = warm * (0.78 + 0.12 * rows)
    rgb = rgb * (1 - mask * 0.85) + warm * mask * 0.85
    img = to_image(np.clip(rgb, 0, 255))

    head = np.array([610.0, 340.0]) + OFFSET
    tail = np.array([380.0, 30.0]) + OFFSET
    direction = (head - tail) / np.linalg.norm(head - tail)
    side = np.array([-direction[1], direction[0]])

    # Big soft glow around the meteor and along its trail.
    img.alpha_composite(radial(img.size, head, 330, (255, 140, 40), 0.75))
    def trail_glow(d):
        for t in np.linspace(0, 1, 30):
            p = tail + (head - tail) * t
            r = 10 + 60 * t
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 110, 30, int(40 + 60 * t)))
    glow(img, trail_glow, 22)

    # Flame trail: a tapered tongue built from overlapping blobs, hot near the head.
    rng = np.random.default_rng(7)
    def flames(d):
        for t in np.linspace(0, 1, 90):
            wobble = np.sin(t * 19) * 9 * (1 - t)
            p = tail + (head - tail) * t + side * (wobble + rng.uniform(-4, 4))
            r = 8 + 58 * t ** 1.4
            color = (int(170 + 85 * t), int(40 + 120 * t ** 2), int(10 + 30 * t ** 3), 235)
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)
    glow(img, flames, 4)
    def inner(d):
        for t in np.linspace(0.35, 1, 60):
            p = tail + (head - tail) * t
            r = 4 + 38 * t ** 2
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 214, 110, 220))
    glow(img, inner, 5)

    # Head: molten rock core with a white-hot center and licking flames around it.
    def core(d):
        for k in range(14):
            ang = k / 14 * 2 * np.pi
            tip = head + np.array([np.cos(ang), np.sin(ang)]) * rng.uniform(80, 108) - direction * 22
            base1 = head + np.array([np.cos(ang - 0.3), np.sin(ang - 0.3)]) * 58
            base2 = head + np.array([np.cos(ang + 0.3), np.sin(ang + 0.3)]) * 58
            d.polygon([tuple(base1), tuple(tip), tuple(base2)], fill=(255, 150, 40, 230))
        d.ellipse([head[0] - 72, head[1] - 72, head[0] + 72, head[1] + 72], fill=(255, 120, 30, 255))
        d.ellipse([head[0] - 57, head[1] - 57, head[0] + 57, head[1] + 57], fill=(255, 196, 70, 255))
        c = head - direction * 8
        d.ellipse([c[0] - 36, c[1] - 36, c[0] + 36, c[1] + 36], fill=(255, 244, 200, 255))
    glow(img, core, 3)

    # Embers drifting off the trail.
    def embers(d):
        for _ in range(46):
            t = rng.uniform(0.15, 1.0)
            p = tail + (head - tail) * t + side * rng.normal(0, 46) + direction * rng.uniform(-20, 40)
            r = rng.uniform(2, 5.5)
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, int(rng.uniform(150, 230)), 80, 255))
    glow(img, embers, 2)
    glow(img, embers, 0)
    return to_array(img)


def icon_flame(d, cx, cy, color):
    d.polygon([(cx - 4, cy - 44), (cx + 20, cy - 14), (cx + 30, cy + 10), (cx + 22, cy + 34), (cx, cy + 44),
               (cx - 24, cy + 34), (cx - 32, cy + 10), (cx - 22, cy - 10), (cx - 14, cy + 4), (cx - 10, cy - 18)],
              fill=color)


# --- Upgrade ----------------------------------------------------------------------------------

def paint_upgrade(rgb):
    img = to_image(rgb)
    tower = np.array([372.0, 520.0]) + OFFSET
    img.alpha_composite(radial(img.size, tower, 420, (255, 210, 90), 0.55))

    # Rising golden chevrons beside the tower.
    def chevrons(d):
        for i, (x, y) in enumerate([(682, 660), (682, 560), (682, 460)]):
            x, y = x + OFFSET[0], y + OFFSET[1]
            w, h, th = 62, 40, 24
            a = 255 - i * 30
            d.polygon([(x - w, y + h), (x, y), (x + w, y + h), (x + w, y + h + th), (x, y + th), (x - w, y + h + th)],
                      fill=(255, 214, 90, a))
    glow(img, chevrons, 14)
    glow(img, chevrons, 0)

    # A smith's hammer in the sky, tilted as if mid-swing, glowing gold.
    hammer = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(hammer)
    d.rounded_rectangle([138, 96, 162, 286], radius=8, fill=(110, 70, 34, 255))
    d.rounded_rectangle([143, 100, 151, 280], radius=4, fill=(160, 110, 60, 255))
    for y in (220, 250):
        d.rectangle([136, y, 164, y + 8], fill=(70, 44, 22, 255))
    d.rounded_rectangle([64, 40, 236, 110], radius=12, fill=(120, 84, 24, 255))
    d.rounded_rectangle([70, 46, 230, 104], radius=10, fill=(236, 186, 70, 255))
    d.rectangle([76, 52, 224, 66], fill=(255, 232, 150, 255))
    d.rectangle([60, 46, 74, 104], fill=(196, 146, 46, 255))
    d.rectangle([226, 46, 240, 104], fill=(196, 146, 46, 255))
    hammer = hammer.rotate(-22, resample=Image.BICUBIC, expand=True)
    pos = (int(640 + OFFSET[0] - hammer.width / 2), int(215 + OFFSET[1] - hammer.height / 2))
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    halo.alpha_composite(hammer, pos)
    tint = np.array(halo).astype(np.float64)
    tint[..., :3] = (255, 220, 110)
    halo = Image.fromarray(tint.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(16))
    img.alpha_composite(radial(img.size, (640 + OFFSET[0], 215 + OFFSET[1]), 200, (255, 236, 160), 0.7))
    img.alpha_composite(halo)
    img.alpha_composite(hammer, pos)

    sparkles(img, np.random.default_rng(11), 30, (120, 90, 760, 760), (255, 244, 190, 255))
    return to_array(img)


def icon_upgrade(d, cx, cy, color):
    for dy in (14, -14):
        y = cy + dy
        d.polygon([(cx - 32, y + 18), (cx, y - 14), (cx + 32, y + 18), (cx + 32, y + 32), (cx, y), (cx - 32, y + 32)],
                  fill=color)


# --- Heal -------------------------------------------------------------------------------------

def heart_points(cx, cy, size, n=80):
    t = np.linspace(0, 2 * np.pi, n, endpoint=False)
    x = 16 * np.sin(t) ** 3
    y = -(13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t))
    return [(cx + xi * size / 16, cy + yi * size / 16) for xi, yi in zip(x, y)]


def paint_heal(rgb):
    # A gentle green-gold cast over the painting.
    mask = art_mask((rgb.shape[1], rgb.shape[0]))
    tinted = rgb * np.array([0.9, 1.04, 0.9]) + np.array([0, 14, 4])
    rgb = rgb * (1 - mask * 0.6) + tinted * mask * 0.6
    img = to_image(np.clip(rgb, 0, 255))

    heart_center = np.array([640.0, 220.0]) + OFFSET
    tower = np.array([372.0, 500.0]) + OFFSET
    img.alpha_composite(radial(img.size, tower, 380, (150, 255, 150), 0.5))

    # Light rays fanning down from the heart.
    def rays(d):
        for k in range(9):
            ang = np.deg2rad(60 + k * 16)
            far = heart_center + np.array([np.cos(ang), np.sin(ang)]) * 700
            spread = np.array([-np.sin(ang), np.cos(ang)]) * 40
            d.polygon([tuple(heart_center), tuple(far + spread), tuple(far - spread)], fill=(220, 255, 200, 46))
    glow(img, rays, 12)

    img.alpha_composite(radial(img.size, heart_center, 230, (200, 255, 190), 0.85))
    def heart(d):
        d.polygon(heart_points(*heart_center, 98), fill=(30, 110, 50, 255))
        d.polygon(heart_points(*heart_center, 88), fill=(96, 220, 110, 255))
        d.polygon(heart_points(heart_center[0] - 6, heart_center[1] - 8, 64), fill=(170, 250, 170, 255))
        cx, cy = heart_center[0] - 30, heart_center[1] - 34
        d.ellipse([cx - 14, cy - 10, cx + 14, cy + 10], fill=(240, 255, 236, 255))
        # Plus sign in the middle.
        px, py = heart_center[0], heart_center[1] + 6
        d.rounded_rectangle([px - 34, py - 11, px + 34, py + 11], radius=6, fill=(255, 255, 250, 255))
        d.rounded_rectangle([px - 11, py - 34, px + 11, py + 34], radius=6, fill=(255, 255, 250, 255))
    glow(img, heart, 18)
    glow(img, heart, 0)

    sparkles(img, np.random.default_rng(5), 34, (100, 120, 760, 800), (230, 255, 220, 255))
    return to_array(img)


def icon_heart(d, cx, cy, color):
    d.polygon(heart_points(cx, cy + 2, 40), fill=color)


# --- Barricade --------------------------------------------------------------------------------

WOOD_DARK = (64, 38, 20, 255)
WOOD = (132, 86, 46, 255)
WOOD_LIGHT = (184, 132, 78, 255)
ROPE = (206, 180, 120, 255)


def log(d, a, b, width, sharpen_b=False):
    """A round log from a to b (sketch coordinates) with an outline, a lit edge, and a shadowed
    edge; `sharpen_b` carves b into a pale point."""
    a, b = np.array(a, float), np.array(b, float)
    along = (b - a) / np.linalg.norm(b - a)
    side = np.array([-along[1], along[0]]) * width / 2
    b_in = b - along * width * 1.1 if sharpen_b else b

    def outline(grow):
        s = side * (1 + grow * 2 / width)
        end = [tuple(b_in + s), tuple(b + along * grow), tuple(b_in - s)] if sharpen_b else [tuple(b + s), tuple(b - s)]
        return [tuple(a - s), tuple(a + s)] + end

    d.polygon(outline(4), fill=WOOD_DARK)
    d.polygon(outline(0), fill=WOOD)
    d.line([tuple(a + side * 0.45), tuple(b_in + side * 0.45)], fill=WOOD_LIGHT, width=max(3, int(width * 0.22)))
    d.line([tuple(a - side * 0.35), tuple(b_in - side * 0.35)], fill=(98, 62, 32, 255), width=2)
    if sharpen_b:
        d.polygon([tuple(b), tuple(b_in + side * 0.9), tuple(b_in - side * 0.9)], fill=(222, 192, 140, 255))


def lashing(d, center, size):
    cx, cy = center
    for k in range(3):
        o = (k - 1) * size * 0.35
        d.line([(cx - size + o * 0.2, cy - size * 0.6 + o), (cx + size + o * 0.2, cy + size * 0.6 + o)], fill=ROPE, width=6)


def paint_barricade(rgb):
    img = to_image(rgb)
    ox, oy = OFFSET
    # Shade the foreground so the barricade stands out against the rocks.
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse([20 + ox, 610 + oy, 820 + ox, 940 + oy], fill=(20, 12, 6, 120))
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(30)))

    def shadow(d):
        d.ellipse([90 + ox, 760 + oy, 760 + ox, 850 + oy], fill=(0, 0, 0, 150))
    glow(img, shadow, 14)

    def frame(d):
        # Crossed stakes (cheval de frise): pairs of sharpened logs leaning both ways.
        for x in (150, 300, 450, 600, 740):
            log(d, (x - 92 + ox, 830 + oy), (x + 70 + ox, 610 + oy), 30, sharpen_b=True)
            log(d, (x + 92 + ox, 830 + oy), (x - 70 + ox, 610 + oy), 30, sharpen_b=True)
        # Two long rails tying the stakes together.
        log(d, (70 + ox, 742 + oy), (790 + ox, 728 + oy), 40)
        log(d, (80 + ox, 800 + oy), (780 + ox, 792 + oy), 34)
        for x in (150, 300, 450, 600, 740):
            lashing(d, (x + ox, 735 + oy), 22)
    glow(img, frame, 0)
    return to_array(img)


def icon_barricade(d, cx, cy, color):
    for dx in (-26, 0, 26):
        d.polygon([(cx + dx - 8, cy + 36), (cx + dx - 8, cy - 22), (cx + dx, cy - 42), (cx + dx + 8, cy - 22),
                   (cx + dx + 8, cy + 36)], fill=color)
    d.rectangle([cx - 44, cy - 6, cx + 44, cy + 8], fill=color)
    d.rectangle([cx - 44, cy + 18, cx + 44, cy + 30], fill=color)


ICONS = {"fireball": icon_flame, "upgrade": icon_upgrade, "heal": icon_heart, "barricade": icon_barricade}
PAINTERS = {"fireball": paint_fireball, "upgrade": paint_upgrade, "heal": paint_heal, "barricade": paint_barricade}


# --- Text -------------------------------------------------------------------------------------

def clear_stat_box(rgb, x0, x1):
    """Paints a stat panel's interior with its own dark color, as a chamfered shape with a soft
    edge (a smooth fill would pull in the gold rim at the corners)."""
    ox, oy = OFFSET
    top, bottom, c = STAT_TOP + 4, STAT_BOTTOM - 4, 14
    patch = rgb[top + oy:bottom + oy, x0 + ox:x1 + ox].reshape(-1, 3)
    dark = patch[patch.sum(axis=1) < np.percentile(patch.sum(axis=1), 50)]
    color = tuple(int(v) for v in np.median(dark, axis=0))
    layer = Image.new("RGBA", (rgb.shape[1], rgb.shape[0]), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(at([(x0 + c, top), (x1 - c, top), (x1, top + c), (x1, bottom - c), (x1 - c, bottom),
                                      (x0 + c, bottom), (x0, bottom - c), (x0, top + c)]), fill=(*color, 255))
    img = to_image(rgb)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.5)))
    return to_array(img)


def rewrite_text(rgb, spec, icon):
    # Clear the title, description, icon arrows, and the whole interior of each stat box.
    rgb = fill(rgb, [(196, 894), (642, 894), (642, 954), (196, 954)], grow=0)
    for top in (1046, 1096, 1146):
        rgb = fill(rgb, [(266, top), (744, top), (744, top + 46), (266, top + 46)], grow=0)
    for x0, x1 in STAT_BOXES:
        rgb = clear_stat_box(rgb, x0, x1)
    img = to_image(rgb)
    ox, oy = OFFSET
    d = ImageDraw.Draw(img)

    icx, icy = 162 + ox, 1107 + oy
    disc = tuple(int(v) for v in rgb[icy + 52, icx])
    d.ellipse([icx - 62, icy - 62, icx + 62, icy + 62], fill=disc)
    icon(d, icx, icy, PARCHMENT)

    # Title in small caps: bigger initials, like the archer card.
    big, small = font(TITLE_FONT, 60), font(TITLE_FONT, 47)
    pieces = []
    for word_i, word in enumerate(spec["title"].upper().split()):
        if word_i:
            pieces.append((" ", small))
        pieces.append((word[0], big))
        pieces.append((word[1:], small))
    total = sum(d.textlength(text, font=f) for text, f in pieces)
    x = 418 + ox - total / 2
    for text, f in pieces:
        d.text((x, 947 + oy), text, font=f, fill=INK, anchor="ls")
        x += d.textlength(text, font=f)

    body = font(BODY_FONT, 38)
    for i, line in enumerate(spec["description"]):
        d.text((272 + ox, 1080 + oy + i * 50), line, font=body, fill=INK, anchor="ls")

    label_font = font(TITLE_FONT, 26)
    for (x0, x1), (value, label) in zip(STAT_BOXES, spec["stats"]):
        cx = (x0 + x1) / 2 + ox
        size = 62
        while d.textlength(value, font=font(STAT_FONT, size)) > (x1 - x0) - 36:
            size -= 2
        d.text((cx, 1282 + oy), value, font=font(STAT_FONT, size), fill=STAT_INK, anchor="mm")
        d.text((cx, 1330 + oy), label, font=label_font, fill=LABEL_INK, anchor="mm")
    return to_array(img)


def draw_cost(rgb, cost):
    card = to_image(rgb)
    cx, cy = archer.GEM_CENTER
    card = Image.alpha_composite(card, archer.number_layer(card.size, (cx, cy + 2), cost))
    return to_array(card)


def main():
    base = np.array(Image.open(archer.SOURCE).convert("RGB")).astype(np.float64)
    base = archer.erase_cost(base)
    base = archer.remove_second_archer(base)
    base = archer.remove_background_castle(base)
    # Keeps each card's painting (glows included) inside the frame.
    window = art_mask((base.shape[1], base.shape[0]), feather=3)
    names = sys.argv[1:] or list(CARDS)
    for name in names:
        spec = CARDS[name]
        rgb = base * (1 - window) + PAINTERS[name](base.copy()) * window
        rgb = rewrite_text(rgb, spec, ICONS[name])
        rgb = draw_cost(rgb, spec["cost"])
        card = archer.cut_out_card(rgb)
        output = ROOT / f"assets/cards/{name}.png"
        card.save(output)
        print(f"Saved {output.relative_to(ROOT)} {card.size}")


if __name__ == "__main__":
    main()
