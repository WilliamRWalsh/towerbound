"""Asset tool: draws the castle health bar's heart as a faceted ruby in a bevelled gold rim, in the
style of the mana gem (assets/ui/mana_gem.png). Writes assets/ui/heart_gem.png at the gem's size.
Requires numpy, scipy, and Pillow: python tools/draw_heart_gem.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets/ui/heart_gem.png"

SS = 3  # supersampling factor
SIZE = 284  # matches mana_gem.png
RIM = 24  # gold rim width
FACETS = 16  # crown facets between the rim and the table
TABLE_SCALE = 0.5  # the flat table is the heart shrunk by this much
LIGHT = np.array([-0.55, -0.83])  # from the top left, like the mana gem

GOLD = np.array([[92, 56, 18], [170, 112, 40], [222, 168, 78], [255, 232, 160]], float)
RUBY = np.array([[64, 4, 14], [140, 10, 28], [206, 30, 50], [255, 112, 120]], float)
EDGE = (255, 165, 170)


def ramp(palette, t):
    """Maps 0-1 values onto a palette of evenly spaced color stops."""
    t = np.clip(t, 0.0, 1.0) * (len(palette) - 1)
    i = np.minimum(np.asarray(t).astype(int), len(palette) - 2)
    f = np.asarray(t - i)[..., None]
    return palette[i] * (1 - f) + palette[i + 1] * f


def heart_outline(n, count):
    """`count` points spaced evenly along a point-down heart filling most of an n x n square."""
    t = np.linspace(0, 2 * np.pi, 2000, endpoint=False)
    x = 16 * np.sin(t) ** 3
    y = -(13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t)) - 2.5
    pts = np.stack([x, y], 1) * (n * 0.47 / 16) + n / 2
    seg = np.linalg.norm(np.diff(pts, axis=0, append=pts[:1]), axis=1)
    along = np.concatenate([[0], np.cumsum(seg)[:-1]])
    # Start at the top cleft so the facets sit symmetrically.
    targets = np.arange(count) / count * along[-1] + seg.sum() * 0.0
    idx = np.searchsorted(along, targets)
    return pts[np.clip(idx, 0, len(pts) - 1)]


def main():
    n = SIZE * SS
    outline = heart_outline(n, 600)
    mask_img = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask_img).polygon([tuple(p) for p in outline], fill=255)
    inside = np.array(mask_img) > 127
    center = np.array([n / 2, n / 2 - n * 0.03])

    # Ruby: crown facets from the girdle (just inside the rim) in to the table.
    girdle = center + (heart_outline(n, FACETS * 2) - center) * 0.86
    girdle = girdle[::2]
    table = center + (girdle - center) * TABLE_SCALE
    ruby = Image.new("RGB", (n, n))
    draw = ImageDraw.Draw(ruby)
    draw.polygon([tuple(p) for p in outline], fill=tuple(int(c) for c in RUBY[1]))
    for i in range(FACETS):
        a, b = girdle[i], girdle[(i + 1) % FACETS]
        edge = b - a
        normal = np.array([edge[1], -edge[0]]) / (np.linalg.norm(edge) + 1e-6)
        if np.dot(normal, (a + b) / 2 - center) < 0:
            normal = -normal
        lit = np.dot(normal, LIGHT)  # facets tilting toward the top left catch the light
        color = ramp(RUBY, 0.45 + 0.4 * lit)
        quad = [tuple(a), tuple(b), tuple(table[(i + 1) % FACETS]), tuple(table[i])]
        draw.polygon(quad, fill=tuple(int(c) for c in color))
    # Outer ring between girdle and rim, split along the same spokes.
    for i in range(FACETS):
        a, b = girdle[i], girdle[(i + 1) % FACETS]
        oa, ob = center + (a - center) * 1.3, center + (b - center) * 1.3
        mid = (a + b) / 2 - center
        lit = np.dot(mid / np.linalg.norm(mid), LIGHT)
        color = ramp(RUBY, 0.3 + 0.3 * lit)
        draw.polygon([tuple(oa), tuple(ob), tuple(b), tuple(a)], fill=tuple(int(c) for c in color))
    rgb = np.array(ruby, float)

    # Table: lighter toward the top left, deep toward the point.
    table_img = Image.new("L", (n, n), 0)
    ImageDraw.Draw(table_img).polygon([tuple(p) for p in table], fill=255)
    on_table = np.array(table_img) > 127
    yy, xx = np.mgrid[0:n, 0:n]
    tone = 0.62 - 0.5 * ((xx - center[0]) * 0.4 + (yy - center[1])) / (n * 0.25)
    rgb[on_table] = ramp(RUBY, tone)[on_table]

    # Pale cut lines along the facet edges.
    lines = Image.new("L", (n, n), 0)
    ld = ImageDraw.Draw(lines)
    width = int(1.3 * SS)
    ld.line([tuple(p) for p in np.vstack([table, table[:1]])], fill=255, width=width, joint="curve")
    ld.line([tuple(p) for p in np.vstack([girdle, girdle[:1]])], fill=150, width=width, joint="curve")
    for i in range(FACETS):
        ld.line([tuple(table[i]), tuple(girdle[i]), tuple(center + (girdle[i] - center) * 1.3)], fill=190, width=width)
    alpha = np.array(lines.filter(ImageFilter.GaussianBlur(0.6 * SS)), float)[..., None] / 255 * 0.6
    rgb = rgb * (1 - alpha) + np.array(EDGE) * alpha

    # Gold rim: outer bevel rises inward, inner bevel falls toward the ruby.
    dist = distance_transform_edt(inside) / SS
    gy, gx = np.gradient(gaussian_filter(dist, 2 * SS))
    norm = np.hypot(gx, gy) + 1e-6
    facing = -(gx / norm * LIGHT[0] + gy / norm * LIGHT[1])
    rim = inside & (dist < RIM)
    shade = np.where(dist < RIM * 0.55, 0.55 + 0.42 * facing, 0.5 - 0.35 * facing)
    rgb[rim] = ramp(GOLD, shade)[rim]
    seam = inside & ((np.abs(dist - RIM) < 1.0) | (dist < 1.4) | (np.abs(dist - RIM * 0.55) < 0.5))
    rgb[seam] *= np.where(np.abs(dist - RIM * 0.55) < 0.5, 0.8, 0.35)[seam][:, None]

    # Soft glint on the upper left lobe.
    glint = Image.new("L", (n, n), 0)
    gx0, gy0 = n * 0.31, n * 0.3
    ImageDraw.Draw(glint).ellipse([gx0 - n * 0.075, gy0 - n * 0.035, gx0 + n * 0.075, gy0 + n * 0.035], fill=170)
    glint = glint.rotate(40, center=(gx0, gy0)).filter(ImageFilter.GaussianBlur(3 * SS))
    g = np.array(glint, float)[..., None] / 255 * (inside & ~rim)[..., None]
    rgb = rgb * (1 - g) + 255 * g

    img = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).convert("RGBA")
    img.putalpha(Image.fromarray((inside * 255).astype(np.uint8)))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(OUTPUT)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
