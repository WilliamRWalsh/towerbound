"""Painted scenery for the spell cards (used by make_spell_cards.py): a sky with clouds, two
mountain ranges, pine forests, and a perspective view of the woodland map's meadow and road.

Works on arrays the size of sketches/archer.png; positions are card coordinates, shifted by the
sketch's 23 × 24 px margin. Requires numpy, scipy, and Pillow.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "assets/maps/woodland.png"
OX, OY = 23, 24
BOTTOM = 846  # bottom of the painting, card coordinates


def lerp(a, b, t):
    return np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t


def over(rgb, color, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    return rgb * (1 - a) + np.broadcast_to(np.asarray(color, float), rgb.shape) * a


def detail_texture(painting, shape, box, strength=1.0):
    """High-pass luminance of a patch of the painting, mirror-tiled over the image (around 1.0)."""
    x0, y0, x1, y1 = box[0] + OX, box[1] + OY, box[2] + OX, box[3] + OY
    patch = painting[y0:y1, x0:x1].mean(-1)
    hp = patch / (ndimage.gaussian_filter(patch, 12) + 1)
    tile = np.block([[hp, hp[:, ::-1]], [hp[::-1], hp[::-1, ::-1]]])
    reps = (shape[0] // tile.shape[0] + 1, shape[1] // tile.shape[1] + 1)
    return 1 + (np.tile(tile, reps)[:shape[0], :shape[1]] - 1) * strength


def sky(shape, rng, top, horizon, horizon_y, cloud_lit, cloud_shade, cover=0.0):
    h, w = shape
    ys = np.arange(h)[:, None, None]
    t = np.clip((ys - 66 - OY) / (horizon_y - 66), 0, 1) ** 0.9
    rgb = np.broadcast_to(lerp(top, horizon, t), (h, w, 3)).copy()
    # Clouds: horizontally stretched noise, lit from above, thinning toward the horizon.
    n = np.zeros((h, w))
    for sy, sx, wgt in ((10, 40, 1.0), (5, 16, 0.5), (2, 6, 0.25)):
        g = ndimage.gaussian_filter(rng.normal(size=(h, w)), (sy, sx), mode="wrap")
        n += g / g.std() * wgt
    n /= 1.75
    alpha = np.clip((n - 0.35 + cover) * 2.2, 0, 1)
    alpha *= np.clip(1 - (ys[..., 0] - OY - 80) / (horizon_y - 80), 0.15, 1)
    shade = np.clip(-np.gradient(ndimage.gaussian_filter(n, 4), axis=0) * 40 + 0.5, 0, 1)
    return over(rgb, lerp(cloud_shade, cloud_lit, shade[..., None]), alpha * 0.9)


def mountains(rgb, rng, base_y, height, peaks, lit, dark, snow=None, haze=None, haze_amt=0.0, jag=1.0, texture=None):
    """A range of peaks (x, top y, slope) above base_y, lit from the left."""
    h, w, _ = rgb.shape
    xs = np.arange(w, dtype=float)
    best = np.full(w, np.inf)
    left = np.zeros(w, bool)
    for px, py, slope in peaks:
        y = py + OY + np.abs(xs - px - OX) * slope
        better = y < best
        best = np.where(better, y, best)
        left = np.where(better, xs < px + OX, left)
    walk = np.cumsum(rng.normal(size=w))
    ridge = np.minimum(base_y + OY, best + (walk - ndimage.gaussian_filter1d(walk, 30)) * 1.6 * jag)
    ys = np.arange(h)[:, None]
    depth = np.clip((ys - ridge[None, :]) / height, 0, 1)
    side = ndimage.gaussian_filter(left[None, :].astype(float), (0, 2))
    streak = ndimage.gaussian_filter(rng.normal(size=(h, w)), (10, 4))
    streak /= streak.std()
    ledge = ndimage.gaussian_filter(rng.normal(size=(h, w)), (3, 12))
    ledge /= ledge.std()
    tone = np.clip(side * 0.75 + streak * 0.18 + (1 - depth) * 0.15, 0, 1)
    color = lerp(dark, lit, tone[..., None])
    if snow is not None:
        cap = ndimage.gaussian_filter((depth < 0.1 + streak * 0.05 + side * 0.07 + ledge * 0.06).astype(float), 1.2)
        snow_tone = lerp(np.asarray(snow) * 0.72, snow, np.clip(side + streak * 0.2, 0, 1)[..., None])
        color = lerp(color, snow_tone, cap[..., None])
    if haze is not None:
        color = lerp(color, haze, haze_amt + depth[..., None] * 0.25)
    if texture is not None:
        color = color * texture[..., None]
    mask = ndimage.gaussian_filter((ys >= ridge[None, :]).astype(float), 0.7)
    return lerp(rgb, color, mask[..., None])


def _road_mask(mapimg):
    r, g, b = mapimg[..., 0], mapimg[..., 1], mapimg[..., 2]
    m = (r > 150) & (r - b > 60) & (r - g > 25) & (g > 100)
    return ndimage.binary_dilation(ndimage.binary_closing(m, iterations=4), iterations=10)


def _grass_only(mapimg):
    """The map with its road covered by grass shifted in from the side."""
    road = _road_mask(mapimg)
    out = mapimg.copy()
    for shift in (220, -220, 330, -330):
        take = road & ~np.roll(road, shift, axis=1)
        out[take] = np.roll(mapimg, shift, axis=1)[take]
        road = road & ~take
    return out


def _sample(img, u, v):
    return np.stack([ndimage.map_coordinates(img[..., c], [v, u], order=1) for c in range(3)], -1)


def _pingpong(a, lo, hi):
    span = hi - lo
    k = np.mod(a - lo, 2 * span)
    return lo + np.where(k < span, k, 2 * span - k)


def ground(rgb, horizon_y, haze, tint=(1.0, 1.0, 1.0), road=True, center_u=470, near_v=1470, far_v=360, near_width=560, card_cx=420):
    """The woodland meadow in perspective, as if standing on the map and looking up the road.
    Fades into `haze` toward the horizon. Returns the image and the depth (1 at the bottom)."""
    mapimg = np.array(Image.open(MAP).convert("RGB")).astype(np.float64)
    grass = _grass_only(mapimg)
    h, w, _ = rgb.shape
    ys, xs = np.mgrid[:h, :w].astype(np.float64)
    hy = horizon_y + OY
    z = (BOTTOM + OY - hy) / np.maximum(ys - hy, 0.5)
    v = _pingpong(near_v - (z - 1) * (near_v - far_v) / 8.0, 330, 1480)
    u = center_u + (xs - card_cx - OX) / 700 * near_width * z
    middle = (u >= 150) & (u <= 800) & road
    out = np.where(middle[..., None], _sample(mapimg, np.clip(u, 150, 800), v), _sample(grass, _pingpong(u, 150, 800), v))
    # Tone the bright game map toward the painting: a little less saturated and warmer.
    grey = out.mean(-1, keepdims=True)
    out = lerp(grey, out, 0.8) * np.array([1.02, 0.97, 0.9]) * np.array(tint)
    out = lerp(out, haze, (np.clip((z - 1) / 14, 0, 1) ** 0.7 * 0.8)[..., None])
    below = ys > hy
    return np.where(below[..., None], out, rgb), np.where(below, z, np.inf)


def pine(d, rng, cx, cy, hgt, dark, lit, trunk=(46, 32, 22)):
    """A pine of drooping branch tiers, lit from the left."""
    d.rectangle([cx - hgt * 0.025, cy - hgt * 0.18, cx + hgt * 0.025, cy], fill=trunk)
    tiers = int(rng.integers(6, 9))
    for k in range(tiers):
        t = k / (tiers - 1)
        y = cy - hgt * (0.12 + 0.8 * t)
        wid = hgt * 0.46 * (1 - t) ** 0.85 + hgt * 0.05
        drop = hgt * 0.2
        for side in (-1, 1):
            pts = [(cx, y - drop * 0.9)]
            for j in range(1, 5):
                f = j / 4
                pts.append((cx + side * wid * f, y + drop * (0.1 + 0.3 * f) + rng.uniform(-2, 2)))
                if j < 4:
                    pts.append((cx + side * wid * (f + 0.08), y + drop * (0.05 + 0.15 * f) - rng.uniform(2, 6)))
            pts += [(cx + side * wid * 0.3, y + drop * 0.18), (cx, y + drop * 0.2)]
            jitter = rng.uniform(0.88, 1.08)
            d.polygon(pts, fill=tuple(int(c * jitter) for c in (lit if side < 0 else dark)))
    d.polygon([(cx, cy - hgt * 1.02), (cx - hgt * 0.04, cy - hgt * 0.86), (cx + hgt * 0.04, cy - hgt * 0.86)], fill=dark)


def forest(size, rng, base_y, count, x_range, height, dark, lit, jitter=10, texture=None, blur=0.7):
    """A row of pines along base_y as an RGBA layer."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x in np.sort(rng.uniform(*x_range, count)):
        pine(d, rng, x + OX, base_y + OY + rng.uniform(-jitter, jitter), height * rng.uniform(0.7, 1.3), dark, lit)
    if texture is not None:
        a = np.array(layer).astype(np.float64)
        a[..., :3] *= texture[..., None]
        layer = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return layer.filter(ImageFilter.GaussianBlur(blur))


DAY = {
    "sky_top": (88, 128, 196), "sky_horizon": (196, 214, 226), "cloud_lit": (250, 246, 236),
    "cloud_shade": (150, 164, 196), "far_lit": (150, 166, 206), "far_dark": (70, 86, 138),
    "snow": (236, 240, 250), "far_haze": (170, 190, 220), "near_lit": (96, 128, 128),
    "near_dark": (46, 70, 84), "near_haze": (150, 180, 200), "ground_haze": (160, 186, 196),
    "back_pine": ((56, 88, 92), (92, 124, 124)), "front_pine": ((26, 58, 46), (66, 106, 74)),
}


def landscape(painting, rng, palette=DAY, horizon=545, road=True, cover=0.0):
    """Sky, mountains, forest, and meadow over the whole painting. Returns an RGB array."""
    p = palette
    shape = painting.shape[:2]
    size = (shape[1], shape[0])
    rock = detail_texture(painting, shape, (625, 210, 765, 400), 0.3)
    rgb = sky(shape, rng, p["sky_top"], p["sky_horizon"], horizon - 75, p["cloud_lit"], p["cloud_shade"], cover)
    rgb = mountains(rgb, rng, horizon - 25, 260, [(160, 260, 0.9), (420, 310, 1.1), (640, 210, 0.95), (820, 300, 1.0)],
                    p["far_lit"], p["far_dark"], snow=p["snow"], haze=p["far_haze"], haze_amt=0.2, texture=rock)
    rgb = mountains(rgb, rng, horizon + 55, 200, [(60, 430, 0.6), (300, 470, 0.45), (560, 440, 0.55), (760, 420, 0.5)],
                    p["near_lit"], p["near_dark"], haze=p["near_haze"], haze_amt=0.2, jag=0.6, texture=rock)
    rgb, _ = ground(rgb, horizon, p["ground_haze"], p.get("ground_tint", (1.0, 1.0, 1.0)), road=road)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")
    img.alpha_composite(forest(size, rng, horizon - 30, 70, (40, 800), 60, *p["back_pine"], blur=1.2))
    needles = detail_texture(painting, shape, (560, 540, 700, 700), 0.8)
    img.alpha_composite(forest(size, rng, horizon + 7, 40, (40, 800), 105, *p["front_pine"], texture=needles))
    return np.array(img.convert("RGB")).astype(np.float64)
