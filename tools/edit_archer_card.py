"""One-off asset tool: builds assets/cards/archer_tower.png from sketches/archer.png.

Crops the card onto a transparent background, repaints the mana gem with a new cost,
and paints out the second archer and the background castle using Poisson (seamless) fills.
Also exports the empty gem and the numbers 0-10 in the same style for the mana bar.
Requires numpy, scipy, and Pillow: python tools/edit_archer_card.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage, sparse
from scipy.sparse.linalg import spsolve

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "sketches/archer.png"
OUTPUT = ROOT / "assets/cards/archer_tower.png"
UI_DIR = ROOT / "assets/ui"
GEM_RADIUS = 142  # outer radius of the gem's gold octagon, vertex pointing up
FONT = ("/System/Library/Fonts/Avenir Next.ttc", 150, 0)  # Avenir Next Bold
NUMBER_FILL = (240, 228, 205, 255)
NUMBER_STROKE = (18, 24, 48, 255)
COST = sys.argv[1] if len(sys.argv) > 1 else "2"
GEM_CENTER = (178, 170)


def poisson_fill(img, mask, guide=None):
    """Fills img where mask is True so it blends seamlessly with its surroundings.
    With a guide image, the fill copies the guide's texture (gradients); without, it's smooth."""
    h, w, _ = img.shape
    ys, xs = np.nonzero(mask)
    index = -np.ones((h, w), dtype=np.int64)
    index[ys, xs] = np.arange(len(ys))
    n = len(ys)
    rows, cols, vals = [], [], []
    b = np.zeros((n, 3))
    for k, (y, x) in enumerate(zip(ys, xs)):
        rows.append(k), cols.append(k), vals.append(4.0)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            qy, qx = y + dy, x + dx
            if guide is not None:
                b[k] += guide[y, x] - guide[qy, qx]
            if mask[qy, qx]:
                rows.append(k), cols.append(index[qy, qx]), vals.append(-1.0)
            else:
                b[k] += img[qy, qx]
    a = sparse.csr_matrix((vals, (rows, cols)), shape=(n, n))
    out = img.copy()
    for c in range(3):
        out[ys, xs, c] = spsolve(a, b[:, c])
    return np.clip(out, 0, 255)


def polygon_mask(shape, points, grow=0):
    m = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    mask = np.array(m) > 0
    return ndimage.binary_dilation(mask, iterations=grow) if grow else mask


def shifted(img, dx, dy):
    """Guide image where pixel (x, y) shows the source pixel at (x + dx, y + dy)."""
    return np.roll(img, shift=(-dy, -dx), axis=(0, 1))


def remove_second_archer(img):
    mask = polygon_mask(img.shape, [(207, 356), (224, 346), (268, 343), (287, 284), (301, 284),
                                    (338, 364), (336, 425), (285, 425), (285, 453), (223, 453),
                                    (194, 438), (191, 400)], grow=2)
    # Borrow the texture of the mountain range to the right of the tower.
    return poisson_fill(img, mask, shifted(img, 400, -60))


def remove_background_castle(img):
    mask = polygon_mask(img.shape, [(705, 405), (722, 398), (726, 438), (755, 432), (765, 390), (786, 390),
                                    (792, 436), (812, 450), (812, 690), (800, 700), (800, 760), (782, 820),
                                    (742, 820), (742, 745), (720, 700), (700, 660), (688, 610), (688, 470),
                                    (700, 455)], grow=2)
    # Mountains above the castle replace its upper half; the bridge, river, and pines to its
    # left continue across its lower half.
    rows = np.arange(img.shape[0])[:, None, None]
    guide = np.where(rows < 575, shifted(img, 0, -150), shifted(img, -130, 0))
    return poisson_fill(img, mask, guide)


def erase_cost(img):
    """Removes the old numeral (light fill plus dark outline) from the gem's table."""
    cx, cy = GEM_CENTER
    yy, xx = np.mgrid[: img.shape[0], : img.shape[1]]
    table = (np.abs(xx - cx) < 62) & (np.abs(yy - cy) < 72)
    r, bl = img[..., 0], img[..., 2]
    not_blue = (bl < r + 40) | (bl < 90)
    mask = ndimage.binary_dilation(table & not_blue, iterations=4) & table
    return poisson_fill(img, mask)


def number_layer(size, center, text):
    points = FONT[1] if len(text) == 1 else int(FONT[1] * 0.78)
    font = ImageFont.truetype(FONT[0], points, index=FONT[2])
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text(center, text, font=font, anchor="mm", fill=NUMBER_STROKE, stroke_width=7, stroke_fill=NUMBER_STROKE)
    draw.text(center, text, font=font, anchor="mm", fill=NUMBER_FILL)
    return layer


def draw_cost(img):
    card = Image.fromarray(img.astype(np.uint8)).convert("RGBA")
    card = Image.alpha_composite(card, number_layer(card.size, (GEM_CENTER[0], GEM_CENTER[1] + 2), COST))
    return np.array(card.convert("RGB")).astype(np.float64)


def export_mana_ui(img):
    """Saves the empty gem (cut out along its octagon) and the numbers 0-10 at the same scale."""
    UI_DIR.mkdir(parents=True, exist_ok=True)
    cx, cy = GEM_CENTER
    ss = 4
    mask = Image.new("L", (img.shape[1] * ss, img.shape[0] * ss), 0)
    angles = np.deg2rad(-90 + 45 * np.arange(8))
    pts = [((cx + GEM_RADIUS * np.cos(a)) * ss, (cy + GEM_RADIUS * np.sin(a)) * ss) for a in angles]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    mask = mask.resize((img.shape[1], img.shape[0]), Image.LANCZOS)
    gem = Image.fromarray(img.astype(np.uint8)).convert("RGBA")
    gem.putalpha(mask)
    box = (cx - GEM_RADIUS, cy - GEM_RADIUS, cx + GEM_RADIUS, cy + GEM_RADIUS)
    gem.crop(box).save(UI_DIR / "mana_gem.png")
    side = GEM_RADIUS * 2
    for n in range(11):
        number_layer((side, side), (side // 2, side // 2 + 2), str(n)).save(UI_DIR / f"mana_{n}.png")


def cut_out_card(rgb):
    """Makes the dark backdrop around the card transparent, with a softened edge."""
    backdrop = np.array([33, 34, 38], dtype=np.float64)
    near = np.linalg.norm(rgb - backdrop, axis=2) < 22
    near[:3], near[-3:], near[:, :3], near[:, -3:] = True, True, True, True
    labels, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    outside = np.isin(labels, list(border))
    alpha = Image.fromarray(((~outside) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    out.putalpha(alpha)
    return out.crop(out.getbbox())


def main():
    rgb = np.array(Image.open(SOURCE).convert("RGB")).astype(np.float64)
    rgb = erase_cost(rgb)
    export_mana_ui(rgb)
    rgb = draw_cost(rgb)
    rgb = remove_second_archer(rgb)
    rgb = remove_background_castle(rgb)
    card = cut_out_card(rgb)
    card.save(OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)} {card.size}")


if __name__ == "__main__":
    main()
