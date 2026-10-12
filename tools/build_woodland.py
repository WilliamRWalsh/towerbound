"""Asset tool: builds the battlefield map from sketches/woodland.png.

Outputs:
  assets/maps/woodland.png         the map art
  assets/maps/woodland_blocked.png build mask (white = path, trees, or castle; not buildable)

Steps: paint out the baked-in mana bar and grid lines (the game draws its own grid), thin out
the flowers, push the path's left bend right to open up building room, and wither the land and
trees nearest the Badlands at the top. Finally, make the map phone-shaped (about 9:19.5): add a
strip of Badlands forest above the gate (it sits under the notch), stretch the courtyard below
the castle (it sits under the cards), and give the meadow the small remainder.
Requires numpy, scipy, and Pillow: python tools/build_woodland.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.stats import norm

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "sketches/woodland.png"
OUTPUT = ROOT / "assets/maps/woodland.png"
BLOCKED_OUTPUT = ROOT / "assets/maps/woodland_blocked.png"

MANA_BAR = (148, 1578, 808, 1640)  # left, top, right, bottom
MEADOW = (85, 190, 875, 1300)  # rough bounds of the open grass, for line and flower cleanup
FLOWERS_KEPT = 0.18
PATH_SHIFT = 95.0  # map pixels the left bend moves right
RIGHT_BEND_SHIFT = 55.0  # map pixels the upper-right bend moves left
GRASS_SAMPLE = (1020, 130)  # top-left of a plain 160 px patch of meadow used for regrown grass  # map pixels the left bend moves right (about one grid column)
SEED = 7
TARGET_ASPECT = 9 / 19.5  # width / height of modern iPhones
TOP_STRIP = 140  # rows of Badlands forest added above the gate
GATE = (355, 38, 560, 140)  # gate area removed from the added strip (left, top, right, bottom)
MEADOW_ROWS = (190, 1380)  # meadow and side forest
MEADOW_EXTRA = 72  # extra rows given to the meadow
COURTYARD_ROWS = (1550, 1672)  # stone courtyard below the castle gate, under the cards


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fill_from_neighbors(img, mask, sigma):
    """Replaces masked pixels with a blur of the unmasked pixels around them."""
    keep = (~mask).astype(np.float64)
    out = img.copy()
    weight = ndimage.gaussian_filter(keep, sigma)
    for c in range(3):
        blurred = ndimage.gaussian_filter(img[..., c] * keep, sigma)
        out[..., c] = np.where(mask, blurred / np.maximum(weight, 1e-6), img[..., c])
    return out


def remove_mana_bar(img):
    left, top, right, bottom = MANA_BAR
    mid, feather = (top + bottom) // 2, 6
    src = img.copy()
    for y in range(top, bottom):
        from_above = (top - 1) - (y - (top - 1))
        from_below = min(bottom + (bottom - y), img.shape[0] - 1)
        w = np.clip((y - (mid - feather)) / (feather * 2), 0, 1)
        img[y, left:right] = src[from_above, left:right] * (1 - w) + src[from_below, left:right] * w
    return img


def meadow_mask(shape):
    m = np.zeros(shape[:2], dtype=bool)
    left, top, right, bottom = MEADOW
    m[top:bottom, left:right] = True
    return m


def open_grass(img):
    """The open meadow itself (bright grass and what sits on it), excluding the tree lines."""
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    bright_grass = (g > r + 4) & (g > b + 25) & (img.mean(axis=2) > 95) & meadow_mask(img.shape)
    closed = ndimage.binary_closing(bright_grass, iterations=4)
    labels, count = ndimage.label(closed)
    sizes = ndimage.sum(closed, labels, range(1, count + 1))
    meadow = np.isin(labels, np.nonzero(sizes > 50000)[0] + 1)
    return ndimage.binary_erosion(ndimage.binary_fill_holes(meadow), iterations=2)


def remove_grid_lines(img):
    lum = img.mean(axis=2)
    vertical = (lum - ndimage.grey_opening(lum, size=(1, 9))) > 10
    horizontal = (lum - ndimage.grey_opening(lum, size=(9, 1))) > 10
    vertical = ndimage.binary_opening(vertical, structure=np.ones((20, 1)))
    horizontal = ndimage.binary_opening(horizontal, structure=np.ones((1, 20)))
    lines = ndimage.binary_dilation((vertical | horizontal) & meadow_mask(img.shape), iterations=1)
    return fill_from_neighbors(img, lines, 2.5)


def path_mask(img):
    """The dirt path: the large connected tan region."""
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    tan = (r > g) & (g > b) & (r - b > 55) & (r > 140)
    tan = ndimage.binary_closing(tan, iterations=2)
    labels, count = ndimage.label(tan)
    sizes = ndimage.sum(tan, labels, range(1, count + 1))
    return np.isin(labels, np.nonzero(sizes > 20000)[0] + 1)


def thin_flowers(img, path):
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    grass = (g > r + 4) & (g > b + 25)
    candidates = ~grass & ~ndimage.binary_dilation(path, iterations=3) & open_grass(img)
    clumps = ndimage.binary_dilation(candidates, iterations=3)
    labels, count = ndimage.label(clumps)
    sizes = ndimage.sum(clumps, labels, range(1, count + 1))
    rng = np.random.default_rng(SEED)
    removed = [i + 1 for i in range(count) if sizes[i] < 2500 and rng.random() > FLOWERS_KEPT]
    mask = np.isin(labels, removed)
    return fill_from_neighbors(img, mask, 5.0)


def path_shift_field(shape):
    """Horizontal displacement that moves the path's left bend right and its upper-right bend
    left, opening building room beside both. Each shift fades out smoothly."""
    ys, xs = np.mgrid[0:shape[0], 0:shape[1]].astype(np.float64)
    left_bend = smoothstep(420, 610, ys) * (1 - smoothstep(880, 1040, ys)) * (1 - smoothstep(400, 640, xs))
    right_bend = smoothstep(250, 380, ys) * (1 - smoothstep(540, 640, ys)) * smoothstep(420, 600, xs)
    return PATH_SHIFT * left_bend - RIGHT_BEND_SHIFT * right_bend


def warp(channels, dx, order=1):
    ys, xs = np.mgrid[0:dx.shape[0], 0:dx.shape[1]].astype(np.float64)
    # Inverse map: each output pixel samples the source pixel it was pushed from.
    return [ndimage.map_coordinates(c, [ys, xs - dx], order=order, mode="nearest") for c in channels]


def poisson_fill(img, mask, guide):
    """Seamlessly fills masked pixels, copying the texture (gradients) of the guide image."""
    from scipy import sparse
    from scipy.sparse.linalg import spsolve
    h, w, _ = img.shape
    ys, xs = np.nonzero(mask)
    index = -np.ones((h, w), dtype=np.int64)
    index[ys, xs] = np.arange(len(ys))
    rows, cols, vals = [], [], []
    b = np.zeros((len(ys), 3))
    for k, (y, x) in enumerate(zip(ys, xs)):
        rows.append(k), cols.append(k), vals.append(4.0)
        for qy, qx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            b[k] += guide[y, x] - guide[qy, qx]
            if mask[qy, qx]:
                rows.append(k), cols.append(index[qy, qx]), vals.append(-1.0)
            else:
                b[k] += img[qy, qx]
    a = sparse.csr_matrix((vals, (rows, cols)), shape=(len(ys), len(ys)))
    out = img.copy()
    for c in range(3):
        out[ys, xs, c] = spsolve(a, b[:, c])
    return np.clip(out, 0, 255)


def move_path(img, path):
    """Lifts the path (with its grassy fringe) off the map, grows meadow where it was, and lays it
    back down shifted. Only the path moves, so trees and bushes keep their shape."""
    dx = path_shift_field(img.shape)
    layer = ndimage.binary_dilation(path, iterations=5)
    moving = layer & (np.abs(dx) > 0.5)
    # Grow grass under the old bend (including its dark edge): a smooth blend of the surrounding
    # meadow plus fine texture from a plain stretch of grass.
    hole = ndimage.binary_dilation(moving, iterations=12) & ~ndimage.binary_dilation(path & (np.abs(dx) <= 0.5), iterations=3)
    top, left = GRASS_SAMPLE
    sample = img[top:top + 160, left:left + 160]
    texture = sample - ndimage.gaussian_filter(sample, (4, 4, 0))
    reps = (img.shape[0] // 160 + 1, img.shape[1] // 160 + 1, 1)
    base = poisson_fill(img, hole, np.tile(texture, reps)[:img.shape[0], :img.shape[1]])
    # Shift the path layer and composite it with a soft edge.
    moved = np.stack(warp([img[..., c] for c in range(3)], dx), axis=-1)
    alpha = warp([ndimage.gaussian_filter(layer.astype(np.float64), 1.0)], dx)[0][..., None]
    out = base * (1 - alpha) + moved * alpha
    new_path = warp([path.astype(np.float64)], dx)[0] > 0.5
    return out, new_path, dx


def rgb_to_hsv(img):
    return np.array(Image.fromarray(img.astype(np.uint8)).convert("HSV")).astype(np.float64)


def hsv_to_rgb(hsv):
    return np.array(Image.fromarray(np.clip(hsv, 0, 255).astype(np.uint8), "HSV").convert("RGB")).astype(np.float64)


def blob_noise(shape, sigma, rng):
    n = ndimage.gaussian_filter(rng.standard_normal(shape[:2]), sigma)
    return (n - n.mean()) / n.std()


def wither_near_badlands(img, path, meadow):
    """Grass and trees fade from dead at the Badlands edge to fresh a quarter of the way down."""
    rng = np.random.default_rng(SEED)
    ys = np.mgrid[0:img.shape[0], 0:img.shape[1]][0].astype(np.float64)
    hsv = rgb_to_hsv(img)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    green = (h > 40) & (h < 120) & (s > 50)  # PIL hue is 0-255
    near_meadow = ndimage.binary_dilation(meadow, iterations=12) & ~path

    # Grass: a patchy gradient from straw at the Badlands edge to green about a quarter down.
    zone = 1 - smoothstep(380, 600, ys)
    patch = blob_noise(img.shape, 16, rng) * 0.3 * zone
    grass_death = np.clip(1.15 - smoothstep(190, 540, ys) * 1.15 + patch, 0, 1) * (green & near_meadow)
    grass_death = ndimage.gaussian_filter(grass_death, 1.5)

    # Trees: whole clumps die. Nearly all are dead at the top, a few remain dead further down.
    clump = blob_noise(img.shape, 22, rng)
    dead_share = 1 - smoothstep(170, 760, ys) * 0.92
    threshold = ndimage.gaussian_filter(dead_share, 1)  # fraction of clumps that are dead
    tree_death = (clump < norm.ppf(np.clip(threshold, 1e-3, 1 - 1e-3))) & green & ~near_meadow

    straw = np.stack([h + (27 - h) * 0.9, s * 0.58, np.minimum(v * 1.0, 235)], axis=-1)
    dead_wood = np.stack([h + (22 - h) * 0.9, s * 0.32, v * 0.7], axis=-1)
    out = hsv.copy()
    out = out * (1 - grass_death[..., None]) + straw * grass_death[..., None]
    soft_tree = ndimage.gaussian_filter(tree_death.astype(np.float64), 1.2)[..., None]
    out = out * (1 - soft_tree) + dead_wood * soft_tree
    return hsv_to_rgb(out)


def row_source_map(height, new_height):
    """For each output row of the phone-shaped map, the source row it samples (top strip excluded)."""
    m_top, m_bottom = MEADOW_ROWS
    c_top, c_bottom = COURTYARD_ROWS
    body = new_height - TOP_STRIP
    out_pts = [0, m_top, m_bottom + MEADOW_EXTRA, c_top + MEADOW_EXTRA, body - 1]
    src_pts = [0, m_top, m_bottom, c_top, height - 1]
    return np.interp(np.arange(body, dtype=np.float64), out_pts, src_pts)


def resample_rows(channel, src_rows, order=1):
    ys, xs = np.meshgrid(src_rows, np.arange(channel.shape[1], dtype=np.float64), indexing="ij")
    return ndimage.map_coordinates(channel, [ys, xs], order=order, mode="nearest")


def badlands_strip(img):
    """The forest above the gate with the gate painted out, flipped to continue seamlessly upward."""
    strip = img[:TOP_STRIP + 2].copy()
    left, top, right, bottom = GATE
    mask = np.zeros(strip.shape[:2], dtype=bool)
    mask[top:bottom, left:right] = True
    strip = poisson_fill(np.pad(strip, ((0, 2), (0, 0), (0, 0)), mode="edge"), np.pad(mask, ((0, 2), (0, 0))),
                         np.pad(np.roll(strip, 230, axis=1), ((0, 2), (0, 0), (0, 0)), mode="edge"))[:TOP_STRIP]
    return strip[::-1]


def make_phone_shaped(img, blocked):
    height, width = blocked.shape
    new_height = round(width / TARGET_ASPECT)
    src_rows = row_source_map(height, new_height)
    body = np.stack([resample_rows(img[..., c], src_rows) for c in range(3)], axis=-1)
    img = np.concatenate([badlands_strip(img), body])
    body_blocked = resample_rows(blocked.astype(np.float64), src_rows) > 0.5
    blocked = np.concatenate([np.ones((TOP_STRIP, width), dtype=bool), body_blocked])
    scale = (MEADOW_ROWS[1] - MEADOW_ROWS[0] + MEADOW_EXTRA) / (MEADOW_ROWS[1] - MEADOW_ROWS[0])
    to_output = lambda y: TOP_STRIP + MEADOW_ROWS[0] + (y - MEADOW_ROWS[0]) * scale
    print(f"Map {width}x{new_height}; source rows 229 and 1228 land at {to_output(229):.0f} and {to_output(1228):.0f}")
    return img, blocked


def main():
    img = np.array(Image.open(SOURCE).convert("RGB")).astype(np.float64)
    img = remove_mana_bar(img)
    img = remove_grid_lines(img)
    path = path_mask(img)
    open_grass_before = open_grass(img)
    path_mask_before = path
    img = thin_flowers(img, path)

    img, path, dx = move_path(img, path)
    meadow = open_grass_before | (ndimage.binary_dilation(path_mask_before, iterations=6) & ~path)
    dark = img.max(axis=2) < 102  # tree canopies, the Badlands, and shadowed scenery
    blocked = path | ndimage.binary_opening(dark, iterations=2) | ~meadow_mask(img.shape)
    img = wither_near_badlands(img, path, meadow)

    img, blocked = make_phone_shaped(img, blocked)

    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(OUTPUT)
    Image.fromarray((blocked * 255).astype(np.uint8)).save(BLOCKED_OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)} and {BLOCKED_OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
