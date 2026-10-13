"""One-off asset tool: builds the Fireball, Upgrade, Repair, and Barricade cards from sketches/archer.png,
so they share the Archer Tower card's frame.

Runs the archer card's cleanup (cost, second archer, background castle), then paints each card:
- Fireball: a dusk landscape (card_scenery.py) with a flaming meteor falling on a burning road.
- Upgrade: keeps the Archer Tower painting and reinforces the tower with iron straps, corner
  plates, and scaffolding with a hoist lifting a new stone block.
- Repair: a castle wall with a breach, stones rising back into it on golden trails, scaffolding,
  and a glowing hammer.
- Barricade: a spiked wooden barricade across the road through a meadow.
Rewrites the cost, title, description, icon, and the three stat boxes (value and label).
Requires numpy, scipy, and Pillow: python tools/make_spell_cards.py [card names...]
Without names it builds every card.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

import card_scenery as scenery
import edit_archer_card as archer

ROOT = Path(__file__).resolve().parent.parent

# Coordinates below are measured on the finished archer card; the sketch has a 23 × 24 px margin.
OFFSET = np.array([23, 24])
# The painting inside the frame, kept clear of the gold border.
ART_BOX = (70, 66, 770, 836)
# The frame's inner edge, and the corners where its ornaments reach into the painting (sketch coordinates).
OPENING = (70, 70, 804, 868)
ORNAMENT_ZONES = ((660, 60, 810, 230), (60, 280, 140, 500), (60, 740, 170, 880), (730, 680, 810, 880))

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
        "description": ["Hits a small area, then", "leaves the ground burning", "for 10 seconds."],
        "stats": [("3.0", "DAMAGE"), ("2.0", "RADIUS"), ("10s", "BURN")],
    },
    "upgrade": {
        "cost": "3",
        "title": "Upgrade",
        "description": ["Upgrade a tower:", "+50% attack speed", "or +1 ammo."],
        "stats": [("+50%", "ATTACK SPEED"), ("+1", "AMMO"), ("TOWER", "TARGET")],
    },
    "repair": {
        "cost": "2",
        "title": "Repair",
        "description": ["Repairs 5 health of", "your castle, up to its", "full health."],
        "stats": [("+5", "HEALTH"), ("CASTLE", "TARGET"), ("20", "MAX HEALTH")],
    },
    "barricade": {
        "cost": "2",
        "title": "Barricade",
        "description": ["Blocks the road until", "broken. Discard it to", "scatter caltrops."],
        "stats": [("5", "HEALTH"), ("PATH", "TARGET"), ("HALTS", "ENEMIES")],
    },
    "oil_slick": {
        "cost": "1",
        "title": "Oil Slick",
        "description": ["Slows enemies on the", "road. Fire ignites it", "into a raging blaze."],
        "stats": [("40%", "SLOW"), ("PATH", "TARGET"), ("FIRE", "IGNITES")],
    },
    "chill": {
        "cost": "2",
        "title": "Chill",
        "description": ["Slows enemies in an", "area. Chilled enemies", "take +50% cannon hits."],
        "stats": [("5s", "CHILL"), ("50%", "SLOW"), ("ANY", "TARGET")],
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


def frame_window(rgb):
    """Soft mask (floats 0-1) of the painting showing through the frame: everything inside the
    frame's inner gold edge, minus the cost gem and the frame's ornaments that reach into the
    painting (found by color in the corners and along the edge)."""
    h, w, _ = rgb.shape
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = rgb.mean(-1)
    frame = ((r > 120) & (r - b > 55) & (g > 80) & (r > g)) | ((b > r + 18) & (b > g + 6) & (lum < 90)) | (lum < 35)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle(OPENING, radius=24, fill=255)
    rect = np.array(m) > 0
    z = Image.new("L", (w, h), 0)
    for box in ORNAMENT_ZONES:
        ImageDraw.Draw(z).rectangle(box, fill=255)
    zones = (np.array(z) > 0) | ~ndimage.binary_erosion(rect, iterations=12)
    labels, _ = ndimage.label((frame & rect & zones) | ~rect)
    outside = np.unique(labels[~rect])
    keep = np.isin(labels, outside[outside > 0]) & rect
    keep = ndimage.binary_closing(ndimage.binary_opening(keep, iterations=1), iterations=2)
    gem = Image.new("L", (w, h), 0)
    cx, cy = archer.GEM_CENTER
    r = archer.GEM_RADIUS + 6
    ImageDraw.Draw(gem).polygon([(cx + r * np.sin(k * np.pi / 4), cy + 2 - r * np.cos(k * np.pi / 4)) for k in range(8)],
                                fill=255)
    opening = rect & ~keep & ~(np.array(gem) > 0)
    return ndimage.gaussian_filter(opening.astype(np.float64), 1.2)[..., None]


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

DUSK = {
    "sky_top": (34, 22, 44), "sky_horizon": (226, 104, 52), "cloud_lit": (255, 160, 96),
    "cloud_shade": (84, 44, 62), "far_lit": (120, 70, 84), "far_dark": (54, 32, 52),
    "snow": (232, 150, 124), "far_haze": (170, 84, 72), "near_lit": (78, 46, 50),
    "near_dark": (38, 24, 34), "near_haze": (140, 66, 56), "ground_haze": (150, 78, 56),
    "back_pine": ((40, 24, 30), (62, 36, 38)), "front_pine": ((22, 14, 18), (44, 26, 26)),
    "ground_tint": (0.66, 0.44, 0.36),
}
FIRE_CENTER = np.array([420.0, 712.0])  # middle of the burning patch on the road
FIRE_RADII = (300.0, 92.0)


def meteor(img, rng, tail, head, size=1.0):
    """A flaming rock streaking from tail to head (sketch coordinates)."""
    direction = (head - tail) / np.linalg.norm(head - tail)
    side = np.array([-direction[1], direction[0]])
    img.alpha_composite(radial(img.size, head, 330 * size, (255, 140, 40), 0.75))

    def trail_glow(d):
        for t in np.linspace(0, 1, 30):
            p = tail + (head - tail) * t
            r = (10 + 60 * t) * size
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 110, 30, int(40 + 60 * t)))
    glow(img, trail_glow, 22)

    def flames(d):
        for t in np.linspace(0, 1, 90):
            p = tail + (head - tail) * t + side * (np.sin(t * 19) * 9 * (1 - t) + rng.uniform(-4, 4))
            r = (8 + 58 * t ** 1.4) * size
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r],
                      fill=(int(170 + 85 * t), int(40 + 120 * t ** 2), int(10 + 30 * t ** 3), 235))
    glow(img, flames, 4)

    def inner(d):
        for t in np.linspace(0.35, 1, 60):
            p = tail + (head - tail) * t
            r = (4 + 38 * t ** 2) * size
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 214, 110, 220))
    glow(img, inner, 5)

    def core(d):
        for k in range(14):
            ang = k / 14 * 2 * np.pi
            tip = head + (np.array([np.cos(ang), np.sin(ang)]) * rng.uniform(80, 108) - direction * 22) * size
            base1 = head + np.array([np.cos(ang - 0.3), np.sin(ang - 0.3)]) * 58 * size
            base2 = head + np.array([np.cos(ang + 0.3), np.sin(ang + 0.3)]) * 58 * size
            d.polygon([tuple(base1), tuple(tip), tuple(base2)], fill=(255, 150, 40, 230))
        for r, color in ((72, (255, 120, 30)), (57, (255, 196, 70))):
            r *= size
            d.ellipse([head[0] - r, head[1] - r, head[0] + r, head[1] + r], fill=(*color, 255))
        c, r = head - direction * 8 * size, 36 * size
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=(255, 244, 200, 255))
    glow(img, core, 3)

    def embers(d):
        for _ in range(46):
            t = rng.uniform(0.15, 1.0)
            p = tail + (head - tail) * t + side * rng.normal(0, 46) + direction * rng.uniform(-20, 40)
            r = rng.uniform(2, 5.5)
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, int(rng.uniform(150, 230)), 80, 255))
    glow(img, embers, 2)
    glow(img, embers, 0)


def flame(d, x, y, height, width, lean, colors):
    """One licking flame standing on (x, y): a round base narrowing to a curled tip, drawn as
    nested layers from the outer red to the yellow core."""
    for scale, color in zip((1.0, 0.7, 0.42), colors):
        h, w = height * scale, width * scale
        ts = np.linspace(0, 1, 24)
        half = w * (1 - ts) ** 1.3 * (0.75 + 0.25 * np.sin(ts * np.pi * 1.6))
        bend = lean * h * ts ** 2
        left = [(x - hw + b, y - h * t) for t, hw, b in zip(ts, half, bend)]
        right = [(x + hw + b, y - h * t) for t, hw, b in zip(ts, half, bend)][::-1]
        base = [(x + np.cos(a) * w, y + np.sin(a) * w * 0.35) for a in np.linspace(0, np.pi, 12)]
        d.polygon(left + right + base, fill=color)


def burning_ground(img, rng):
    c = FIRE_CENTER + OFFSET
    rx, ry = FIRE_RADII
    # Scorched earth, then a molten glow inside it.
    def scorch(d):
        d.ellipse([c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry], fill=(26, 14, 10, 225))
    glow(img, scorch, 16)
    img.alpha_composite(radial(img.size, c, rx * 1.1, (255, 110, 30), 0.55))

    def cracks(d):
        for _ in range(26):
            a = rng.uniform(0, 2 * np.pi)
            p = c.copy()
            pts = [tuple(p)]
            for _ in range(5):
                a += rng.uniform(-0.6, 0.6)
                p = p + np.array([np.cos(a) * rx, np.sin(a) * ry]) * rng.uniform(0.1, 0.2)
                pts.append(tuple(p))
            d.line(pts, fill=(255, 150, 50, 220), width=3)
    glow(img, cracks, 3)
    glow(img, cracks, 0)

    # Flames across the patch, back rows smaller, all leaning with the wind.
    img.alpha_composite(radial(img.size, c - np.array([0, 60]), rx * 0.9, (255, 150, 50), 0.6))
    flames = []
    for _ in range(34):
        a, r = rng.uniform(0, 2 * np.pi), np.sqrt(rng.uniform(0, 1)) * 0.92
        x, y = c[0] + np.cos(a) * r * rx, c[1] + np.sin(a) * r * ry
        near = (y - (c[1] - ry)) / (2 * ry)
        height = rng.uniform(80, 180) * (0.55 + 0.6 * near) * (1.15 - abs(x - c[0]) / rx * 0.5)
        flames.append((x, y, height, rng.uniform(0.1, 0.35)))
    flames.sort(key=lambda f: f[1])
    def fire(d):
        for x, y, height, lean in flames:
            flame(d, x, y, height, height * 0.36, lean, [(232, 72, 18, 235), (255, 152, 36, 245), (255, 236, 150, 255)])
    glow(img, fire, 18)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fire(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.5)))


def smoke(img, rng):
    c = FIRE_CENTER + OFFSET
    def puffs(d):
        for k in range(40):
            t = k / 40
            x = c[0] + rng.uniform(-200, 200) * (1 - t * 0.4) + t * 120
            y = c[1] - 120 - t * 520 + rng.uniform(-30, 30)
            r = 40 + 70 * t + rng.uniform(-10, 10)
            shade = int(46 + 30 * t)
            d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(shade, shade - 12, shade - 14, int(120 - 60 * t)))
    glow(img, puffs, 18)


def paint_fireball(painting):
    rng = np.random.default_rng(7)
    rgb = scenery.landscape(painting, rng, DUSK)
    img = to_image(rgb)
    smoke(img, rng)
    burning_ground(img, rng)
    meteor(img, rng, np.array([340.0, 30.0]) + OFFSET, np.array([540.0, 440.0]) + OFFSET, 0.85)
    return to_array(img)


def icon_flame(d, cx, cy, color):
    d.polygon([(cx - 4, cy - 44), (cx + 20, cy - 14), (cx + 30, cy + 10), (cx + 22, cy + 34), (cx, cy + 44),
               (cx - 24, cy + 34), (cx - 32, cy + 10), (cx - 22, cy - 10), (cx - 14, cy + 4), (cx - 10, cy - 18)],
              fill=color)


# --- Stone and timber -------------------------------------------------------------------------

STONE = (186, 174, 152)
MORTAR = (86, 74, 62)
WOOD_DARK = (64, 38, 20, 255)
WOOD = (132, 86, 46, 255)
WOOD_LIGHT = (184, 132, 78, 255)
ROPE = (206, 180, 120, 255)
IRON = (62, 64, 72, 255)
IRON_LIGHT = (128, 132, 142, 255)
RIVET = (232, 196, 110, 255)


def block_image(rng, w, h, color=STONE):
    """One dressed stone block with a lit top-left edge, a shadowed bottom-right edge, and grain."""
    w, h = int(w), int(h)
    ys, xs = np.mgrid[:h, :w].astype(np.float64)
    tone = 1.06 - 0.16 * (xs / w * 0.4 + ys / h * 0.6)
    grain = ndimage.gaussian_filter(rng.normal(size=(h, w)), 1.6)
    tone += grain / (grain.std() + 1e-9) * 0.05
    tone *= rng.uniform(0.86, 1.08)
    rgb = np.clip(np.array(color)[None, None] * tone[..., None], 0, 255)
    a = Image.new("L", (w, h), 0)
    ImageDraw.Draw(a).rounded_rectangle([0, 0, w - 1, h - 1], radius=6, fill=255)
    block = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    block.putalpha(a)
    d = ImageDraw.Draw(block)
    d.line([(5, 2), (w - 6, 2)], fill=(238, 228, 206, 200), width=3)
    d.line([(2, 5), (2, h - 6)], fill=(226, 214, 190, 150), width=2)
    d.line([(5, h - 3), (w - 6, h - 3)], fill=(78, 66, 54, 200), width=3)
    d.line([(w - 3, 5), (w - 3, h - 6)], fill=(96, 82, 66, 180), width=2)
    return block


def stone_wall(size, rng, box, course=48, color=STONE):
    """An RGBA layer of staggered stone courses filling box (sketch coordinates)."""
    x0, y0, x1, y1 = (int(v) for v in box)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rectangle([x0, y0, x1, y1], fill=(*MORTAR, 255))
    y = y0
    while y < y1:
        x = x0 - rng.uniform(0, 60)
        while x < x1:
            w = rng.uniform(62, 112)
            layer.alpha_composite(block_image(rng, w - 5, course - 5, color), (int(x + 2), int(y + 2)))
            x += w
        y += course
    clip = Image.new("L", size, 0)
    ImageDraw.Draw(clip).rectangle([x0, y0, x1, y1], fill=255)
    layer.putalpha(Image.fromarray(np.minimum(np.array(layer.getchannel("A")), np.array(clip))))
    return layer


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


def plank(d, x0, y0, x1, y1):
    d.rectangle([x0 - 3, y0 - 3, x1 + 3, y1 + 3], fill=WOOD_DARK)
    d.rectangle([x0, y0, x1, y1], fill=WOOD)
    d.line([(x0, y0 + 3), (x1, y0 + 3)], fill=WOOD_LIGHT, width=4)
    for x in np.arange(x0 + 40, x1, 70):
        d.line([(x, y0), (x + 4, y1)], fill=(96, 60, 30, 255), width=2)


def lashing(d, center, size):
    cx, cy = center
    for k in range(3):
        o = (k - 1) * size * 0.35
        d.line([(cx - size + o * 0.2, cy - size * 0.6 + o), (cx + size + o * 0.2, cy + size * 0.6 + o)], fill=ROPE, width=6)


def scaffold(d, poles, top, bottom, ledgers, deck=None):
    """Timber scaffolding: upright poles, ledgers between them, X braces, and an optional deck."""
    ox, oy = OFFSET
    for x in poles:
        log(d, (x + ox, bottom + oy), (x + ox, top + oy), 22)
    for y in ledgers:
        log(d, (poles[0] - 24 + ox, y + oy), (poles[-1] + 24 + ox, y + oy), 16)
    for a, b in zip(poles, poles[1:]):
        for y_hi, y_lo in zip(ledgers, ledgers[1:]):
            log(d, (a + ox, y_lo + oy), (b + ox, y_hi + oy), 12)
    if deck is not None:
        plank(d, poles[0] - 30 + ox, deck + oy, poles[-1] + 30 + ox, deck + 18 + oy)
    for x in poles:
        for y in ledgers:
            lashing(d, (x + ox, y + oy), 14)


def hammer_image(scale=1.0):
    hammer = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(hammer)
    d.rounded_rectangle([138, 96, 162, 286], radius=8, fill=(110, 70, 34, 255))
    d.rounded_rectangle([143, 100, 151, 280], radius=4, fill=(160, 110, 60, 255))
    for y in (220, 250):
        d.rectangle([136, y, 164, y + 8], fill=(70, 44, 22, 255))
    d.rounded_rectangle([64, 40, 236, 110], radius=12, fill=(60, 62, 70, 255))
    d.rounded_rectangle([70, 46, 230, 104], radius=10, fill=(132, 136, 146, 255))
    d.rectangle([76, 52, 224, 64], fill=(206, 210, 218, 255))
    d.rectangle([60, 46, 74, 104], fill=(96, 98, 108, 255))
    d.rectangle([226, 46, 240, 104], fill=(96, 98, 108, 255))
    return hammer.resize((int(300 * scale), int(300 * scale)), Image.LANCZOS)


def magic_outline(img, layer, color, blur):
    """A soft colored halo behind an RGBA layer's shape, then the layer itself."""
    halo = np.array(layer).astype(np.float64)
    halo[..., :3] = color
    halo[..., 3] = np.minimum(halo[..., 3] * 1.6, 255)
    img.alpha_composite(Image.fromarray(halo.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(blur)))
    img.alpha_composite(layer)


# --- Upgrade ----------------------------------------------------------------------------------

def iron_band(d, x0, x1, y, slope=0.0, height=18):
    """A riveted iron strap from x0 to x1 (card coordinates) whose top sits at y."""
    ox, oy = OFFSET
    y0, y1 = y + slope * (x0 - x0), y + slope * (x1 - x0)
    d.polygon([(x0 + ox, y0 + oy - 2), (x1 + ox, y1 + oy - 2), (x1 + ox, y1 + height + oy + 2), (x0 + ox, y0 + height + oy + 2)],
              fill=(28, 26, 30, 255))
    d.polygon([(x0 + ox, y0 + oy), (x1 + ox, y1 + oy), (x1 + ox, y1 + height + oy), (x0 + ox, y0 + height + oy)], fill=IRON)
    d.line([(x0 + ox, y0 + oy + 3), (x1 + ox, y1 + oy + 3)], fill=IRON_LIGHT, width=3)
    for x in np.arange(x0 + 10, x1 - 4, 26):
        yy = y + slope * (x - x0) + height / 2
        d.ellipse([x - 4 + ox, yy - 4 + oy, x + 4 + ox, yy + 4 + oy], fill=RIVET)


def paint_upgrade(painting):
    img = to_image(painting)
    ox, oy = OFFSET
    rng = np.random.default_rng(11)
    img.alpha_composite(radial(img.size, np.array([420.0, 600.0]) + OFFSET, 420, (255, 206, 110), 0.25))

    # Riveted iron straps around the stone shaft; the banner hangs in front of them.
    def straps(d):
        for y in (560, 676):
            iron_band(d, 334, 452, y, slope=0.02)
            iron_band(d, 452, 506, y + 2, slope=0.12)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    straps(ImageDraw.Draw(layer))
    banner = archer.polygon_mask((img.size[1], img.size[0]), at([(196, 448), (336, 448), (336, 700), (270, 760), (196, 700)]))
    a = np.array(layer.getchannel("A"))
    a[banner] = 0
    layer.putalpha(Image.fromarray(a))
    img.alpha_composite(layer)

    # Scaffolding against the tower's right side, with a hoist lifting a new stone block.
    def frame(d):
        scaffold(d, [574, 676], 392, 850, [470, 640, 800], deck=626)
        log(d, (548 + ox, 402 + oy), (752 + ox, 402 + oy), 18)          # hoist beam
        d.ellipse([718 + ox, 396 + oy, 740 + ox, 418 + oy], fill=(60, 50, 40, 255))
        d.line([(729 + ox, 408 + oy), (729 + ox, 500 + oy)], fill=ROPE, width=5)
        d.line([(740 + ox, 408 + oy), (752 + ox, 430 + oy), (752 + ox, 626 + oy)], fill=ROPE, width=4)
    glow(img, frame, 0)
    img.alpha_composite(block_image(rng, 84, 56), (int(688 + ox), int(508 + oy)))
    d = ImageDraw.Draw(img)
    for x in (696, 764):
        d.line([(729 + ox, 500 + oy), (x + ox, 512 + oy)], fill=ROPE, width=4)
    # Fresh blocks stacked on the scaffold deck.
    for x, y in ((556, 580), (618, 580), (588, 536)):
        img.alpha_composite(block_image(rng, 60, 46), (x + ox, y + oy))

    sparkles(img, rng, 18, (140, 520, 700, 720), (255, 236, 170, 255), (4, 9))
    return to_array(img)


def icon_upgrade(d, cx, cy, color):
    for dy in (14, -14):
        y = cy + dy
        d.polygon([(cx - 32, y + 18), (cx, y - 14), (cx + 32, y + 18), (cx + 32, y + 32), (cx, y), (cx - 32, y + 32)],
                  fill=color)


# --- Repair -----------------------------------------------------------------------------------

WALL_TOP = 430
WALL_BOTTOM = 792
BREACH = [(318, WALL_TOP - 52), (352, 470), (380, 520), (420, 560), (470, 548), (512, 506), (540, 452), (566, WALL_TOP - 52)]


def paint_repair(painting):
    rng = np.random.default_rng(5)
    rgb = scenery.landscape(painting, rng, horizon=600)
    img = to_image(rgb)
    ox, oy = OFFSET
    size = img.size

    # The castle wall: a stone curtain with merlons, a shadowed walkway lip, and a darker base.
    wall = stone_wall(size, rng, (0, WALL_TOP + oy, size[0], WALL_BOTTOM + oy))
    merlons = stone_wall(size, rng, (0, WALL_TOP - 52 + oy, size[0], WALL_TOP + oy), course=52)
    keep = Image.new("L", size, 0)
    kd = ImageDraw.Draw(keep)
    for x in range(40, 800, 104):
        kd.rectangle([x + ox, WALL_TOP - 52 + oy, x + 62 + ox, WALL_TOP + oy], fill=255)
    merlons.putalpha(Image.fromarray(np.minimum(np.array(merlons.getchannel("A")), np.array(keep))))
    wall.alpha_composite(merlons)
    # Weathering: blotchy grime, darker low down.
    grime = ndimage.gaussian_filter(rng.normal(size=(size[1], size[0])), 18)
    grime = 1 + grime / grime.std() * 0.09
    w_rgba = np.array(wall).astype(np.float64)
    w_rgba[..., :3] *= grime[..., None]
    wall = Image.fromarray(np.clip(w_rgba, 0, 255).astype(np.uint8), "RGBA")
    # Knock the breach out of the wall.
    hole = Image.new("L", size, 0)
    ImageDraw.Draw(hole).polygon(at(BREACH), fill=255)
    hole_a = np.array(hole) > 0
    a = np.array(wall.getchannel("A"))
    a[hole_a] = 0
    wall.putalpha(Image.fromarray(a))
    shade = np.zeros((size[1], size[0], 4), np.uint8)
    ys = np.arange(size[1])[:, None]
    shade[..., 3] = (np.clip((ys - WALL_TOP - oy) / (WALL_BOTTOM - WALL_TOP), 0, 1) ** 1.5 * 120).astype(np.uint8)
    shade[..., 3] = np.minimum(shade[..., 3], a)
    # The wall's thickness shows along the breach's lower right edge.
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).polygon(at([(x + 14, y + 12) for x, y in BREACH]), fill=(70, 58, 48, 255))
    edge_a = np.array(edge.getchannel("A"))
    edge_a[hole_a & (np.array(edge.getchannel("A")) > 0)] = 255
    img.alpha_composite(Image.fromarray(np.dstack([np.array(edge)[..., :3], np.where(hole_a, 0, edge_a)]).astype(np.uint8), "RGBA"))
    img.alpha_composite(wall)
    img.alpha_composite(Image.fromarray(shade, "RGBA"))
    def lip(d):
        d.rectangle([0, WALL_TOP + oy - 2, size[0], WALL_TOP + oy + 6], fill=(60, 50, 42, 120))
    glow(img, lip, 3)

    # Rubble at the foot of the breach.
    for _ in range(14):
        b = block_image(rng, rng.uniform(26, 58), rng.uniform(18, 34)).rotate(rng.uniform(-35, 35), expand=True,
                                                                              resample=Image.BICUBIC)
        img.alpha_composite(b, (int(rng.uniform(330, 560) + ox), int(rng.uniform(770, 812) + oy)))

    # Stones rising back into the gap on trails of golden light.
    def trails(d):
        for sx, ex, ey in ((380, 372, 500), (450, 432, 546), (520, 506, 488), (470, 470, 430)):
            pts = [(sx + (ex - sx) * t + np.sin(t * 6) * 10 + ox, 800 - (800 - ey) * t + oy) for t in np.linspace(0, 1, 16)]
            d.line(pts, fill=(255, 226, 140, 140), width=10)
    glow(img, trails, 10)
    for (x, y, w, h, ang) in ((344, 470, 70, 44, -8), (412, 520, 84, 46, 6), (486, 456, 72, 46, -12), (430, 404, 80, 44, 10)):
        b = block_image(rng, w, h).rotate(ang, expand=True, resample=Image.BICUBIC)
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        layer.alpha_composite(b, (x + ox, y + oy))
        magic_outline(img, layer, (255, 222, 130), 9)

    # Scaffolding against the wall on the left, and a hammer setting a stone on the right.
    def frame(d):
        scaffold(d, [110, 236], 330, 850, [420, 580, 740], deck=566)
    glow(img, frame, 0)
    for x, y in ((112, 520), (176, 520)):
        img.alpha_composite(block_image(rng, 60, 44), (x + ox, y + oy))
    hammer = hammer_image(0.8).rotate(38, expand=True, resample=Image.BICUBIC)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.alpha_composite(hammer, (int(560 + ox - hammer.width / 2), int(330 + oy - hammer.height / 2)))
    img.alpha_composite(radial(size, np.array([560.0, 330.0]) + OFFSET, 150, (255, 230, 150), 0.45))
    magic_outline(img, layer, (255, 222, 130), 12)

    sparkles(img, rng, 30, (300, 340, 640, 800), (255, 244, 200, 255))
    return to_array(img)


def icon_hammer(d, cx, cy, color):
    head = [(-34, -30), (14, -30), (14, -6), (-34, -6)]
    handle = [(-6, -6), (6, -6), (6, 42), (-6, 42)]
    ang = np.deg2rad(-35)
    rot = lambda p: (cx + p[0] * np.cos(ang) - p[1] * np.sin(ang) + 4, cy + p[0] * np.sin(ang) + p[1] * np.cos(ang) - 4)
    d.polygon([rot(p) for p in [(x + 10, y) for x, y in head]], fill=color)
    d.polygon([rot(p) for p in handle], fill=color)


# --- Barricade --------------------------------------------------------------------------------

def paint_barricade(painting):
    rng = np.random.default_rng(9)
    img = to_image(scenery.landscape(painting, rng))
    ox, oy = OFFSET

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


# --- Oil Slick --------------------------------------------------------------------------------

def blob_points(cx, cy, rx, ry, rng, n=48, jitter=0.12):
    """An irregular puddle outline around an ellipse."""
    angles = np.linspace(0, 2 * np.pi, n, endpoint=False)
    wobble = 1 + jitter * np.sin(angles * 3 + rng.uniform(0, 6)) + jitter * 0.6 * np.sin(angles * 7 + rng.uniform(0, 6))
    return [(cx + np.cos(a) * rx * w, cy + np.sin(a) * ry * w) for a, w in zip(angles, wobble)]


def paint_oil_slick(rgb):
    img = to_image(rgb)
    ox, oy = OFFSET
    rng = np.random.default_rng(11)
    # Shade the foreground so the dark pool reads against the rocks.
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse([20 + ox, 620 + oy, 820 + ox, 960 + oy], fill=(10, 6, 14, 130))
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(30)))

    pool = blob_points(450 + ox, 755 + oy, 330, 78, rng)
    def puddle(d):
        d.polygon([(x + 6, y + 10) for x, y in pool], fill=(0, 0, 0, 150))
    glow(img, puddle, 10)
    def oil(d):
        d.polygon(pool, fill=(16, 12, 22, 255))
    glow(img, oil, 1)
    # Rainbow sheen: soft arcs of purple, teal, and gold floating on the oil.
    def sheen(d):
        for (cx, cy, rx, ry, color) in [(380, 742, 150, 30, (140, 90, 200, 150)), (520, 770, 120, 24, (60, 170, 160, 140)),
                                        (330, 775, 90, 16, (200, 160, 70, 110)), (600, 735, 80, 16, (150, 100, 210, 120))]:
            d.arc([cx - rx + ox, cy - ry + oy, cx + rx + ox, cy + ry + oy], 190, 340, fill=color, width=9)
    glow(img, sheen, 5)
    def highlights(d):
        for (cx, cy, rx, ry) in [(400, 735, 120, 22), (540, 765, 70, 12)]:
            d.arc([cx - rx + ox, cy - ry + oy, cx + rx + ox, cy + ry + oy], 210, 300, fill=(235, 230, 255, 200), width=4)
    glow(img, highlights, 1)

    # A barrel tipped on its side at the left, oil pouring from its open end into the pool.
    def barrel(d):
        body = [(120 + ox, 600 + oy), (300 + ox, 640 + oy), (300 + ox, 760 + oy), (120 + ox, 720 + oy)]
        d.polygon([(x + 8, y + 14) for x, y in body], fill=(0, 0, 0, 120))
        d.polygon(body, fill=(112, 70, 36, 255))
        for k in range(1, 5):
            t0 = k / 5
            d.line([(120 + ox + 180 * t0, 600 + oy + 40 * t0), (120 + ox + 180 * t0, 720 + oy + 40 * t0)],
                   fill=(70, 42, 20, 255), width=3)
        for t0 in (0.18, 0.82):
            d.line([(120 + ox + 180 * t0, 600 + oy + 40 * t0), (120 + ox + 180 * t0, 720 + oy + 40 * t0)],
                   fill=(54, 52, 56, 255), width=12)
        d.ellipse([268 + ox, 636 + oy, 332 + ox, 764 + oy], fill=(90, 56, 28, 255), outline=(54, 52, 56, 255), width=10)
        d.ellipse([284 + ox, 660 + oy, 318 + ox, 740 + oy], fill=(14, 10, 18, 255))
        # The pour: a glossy black tongue from the barrel mouth down into the pool.
        d.polygon([(300 + ox, 690 + oy), (318 + ox, 700 + oy), (360 + ox, 760 + oy), (300 + ox, 770 + oy)],
                  fill=(16, 12, 22, 255))
        d.line([(306 + ox, 698 + oy), (340 + ox, 752 + oy)], fill=(170, 150, 210, 200), width=3)
    glow(img, barrel, 0)
    # Drips on the pool.
    def drips(d):
        for _ in range(10):
            x, y = rng.uniform(260, 680) + ox, rng.uniform(720, 800) + oy
            r = rng.uniform(4, 9)
            d.ellipse([x - r, y - r * 0.45, x + r, y + r * 0.45], outline=(120, 100, 160, 160), width=2)
    glow(img, drips, 0)
    return to_array(img)


def icon_drop(d, cx, cy, color):
    d.polygon([(cx, cy - 46), (cx + 18, cy - 14), (cx - 18, cy - 14)], fill=color)
    d.ellipse([cx - 30, cy - 26, cx + 30, cy + 34], fill=color)
    d.ellipse([cx + 4, cy - 2, cx + 16, cy + 16], fill=(80, 70, 66))


# --- Chill ------------------------------------------------------------------------------------

def snowflake(d, cx, cy, size, color, width):
    for k in range(6):
        a = np.pi / 3 * k + np.pi / 2
        dx, dy = np.cos(a), np.sin(a)
        d.line([(cx, cy), (cx + dx * size, cy + dy * size)], fill=color, width=width)
        for along in (0.45, 0.72):
            bx, by = cx + dx * size * along, cy + dy * size * along
            for turn in (0.75, -0.75):
                ex = bx + np.cos(a + turn) * size * 0.28
                ey = by + np.sin(a + turn) * size * 0.28
                d.line([(bx, by), (ex, ey)], fill=color, width=max(2, width - 2))


def paint_chill(rgb):
    # Freeze the painting: shift toward icy blue and lift the shadows.
    mask = art_mask((rgb.shape[1], rgb.shape[0]))
    cold = rgb * np.array([0.72, 0.88, 1.08]) + np.array([20, 42, 70])
    rgb = rgb * (1 - mask * 0.8) + np.clip(cold, 0, 255) * mask * 0.8
    img = to_image(np.clip(rgb, 0, 255))
    ox, oy = OFFSET
    rng = np.random.default_rng(5)

    # Frost creeping in from the edges of the painting: a pale, blurred rim.
    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x0, y0, x1, y1 = (v + o for v, o in zip(ART_BOX, (*OFFSET, *OFFSET)))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle([x0, y0, x1, y1], radius=40, outline=(225, 242, 255, 210), width=70)
    img.alpha_composite(rim.filter(ImageFilter.GaussianBlur(28)))
    # Frost ferns: branching crystal lines growing in from the corners.
    def ferns(d):
        for (sx, sy, ang) in [(80, 80, 0.8), (760, 80, 2.35), (80, 830, -0.8), (760, 830, -2.35),
                              (80, 450, 0.0), (760, 450, np.pi)]:
            for _ in range(5):
                a = ang + rng.uniform(-0.5, 0.5)
                length = rng.uniform(90, 170)
                ex, ey = sx + np.cos(a) * length, sy + np.sin(a) * length
                d.line([(sx + ox, sy + oy), (ex + ox, ey + oy)], fill=(235, 248, 255, 230), width=3)
                for t0 in np.linspace(0.25, 0.85, 4):
                    bx, by = sx + np.cos(a) * length * t0, sy + np.sin(a) * length * t0
                    for turn in (0.6, -0.6):
                        bl = length * 0.22 * (1 - t0 * 0.5)
                        d.line([(bx + ox, by + oy), (bx + np.cos(a + turn) * bl + ox, by + np.sin(a + turn) * bl + oy)],
                               fill=(235, 248, 255, 200), width=2)
    glow(img, ferns, 2)
    glow(img, ferns, 0)

    # A burst of frost: a glowing ring and a big snowflake over the right side of the sky.
    center = np.array([590.0, 330.0]) + OFFSET
    img.alpha_composite(radial(img.size, center, 260, (190, 230, 255), 0.85))
    def burst(d):
        cx, cy = center
        for r, a, w in [(150, 200, 10), (110, 140, 5)]:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(225, 245, 255, a), width=w)
        for k in range(16):
            ang = k / 16 * 2 * np.pi + rng.uniform(-0.1, 0.1)
            r0, r1 = 120, rng.uniform(170, 215)
            p0 = (cx + np.cos(ang) * r0, cy + np.sin(ang) * r0)
            p1 = (cx + np.cos(ang) * r1, cy + np.sin(ang) * r1)
            side = np.array([-np.sin(ang), np.cos(ang)]) * 7
            d.polygon([p1, (p0[0] + side[0], p0[1] + side[1]), (p0[0] - side[0], p0[1] - side[1])],
                      fill=(220, 242, 255, 220))
    glow(img, burst, 3)
    glow(img, burst, 0)
    def flake(d):
        snowflake(d, center[0], center[1], 92, (60, 120, 190, 255), 16)
        snowflake(d, center[0], center[1], 88, (240, 250, 255, 255), 9)
    glow(img, flake, 6)
    glow(img, flake, 0)
    sparkles(img, rng, 26, (90, 90, 750, 820), (245, 252, 255, 230), (3, 9))
    return to_array(img)


def icon_snowflake(d, cx, cy, color):
    snowflake(d, cx, cy, 44, color, 9)


ICONS = {"fireball": icon_flame, "upgrade": icon_upgrade, "repair": icon_hammer, "barricade": icon_barricade,
         "oil_slick": icon_drop, "chill": icon_snowflake}
PAINTERS = {"fireball": paint_fireball, "upgrade": paint_upgrade, "repair": paint_repair, "barricade": paint_barricade,
            "oil_slick": paint_oil_slick, "chill": paint_chill}


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
    window = frame_window(base)
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
