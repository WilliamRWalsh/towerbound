"""Splits the card art into the pieces the game composes card faces from, so the cost, title,
description, and stats are drawn from the card data instead of being baked into each image:

- assets/cards/frame.png: the shared card frame (from sketches/archer.png) with the cost numeral,
  title, description, icon, and stat values cleared, and the painting window cut out.
- assets/cards/paintings/<card>.png: each card's painting, cropped to the window.
- assets/cards/icons/<card>.png: each card's description icon on its dark disc.
- assets/cards/stat_icons/<stat>.png: the tower cards' stat icons (damage, attack speed, range),
  lifted off their dark stat boxes.

Paintings and icons are cut from the finished cards in art/cards/<card>.png (made by
edit_archer_card.py, edit_cannon_card.py, and make_spell_cards.py; art/ is source art Godot
ignores), so rerun this after any of those. Prints the rectangles scripts/ui/card_face.gd uses.
Requires numpy, scipy, and Pillow: python tools/export_card_faces.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import edit_archer_card as archer
import make_spell_cards as spells

ROOT = Path(__file__).resolve().parent.parent
CARDS = ["archer_tower", "cannon_tower", "fireball", "upgrade", "repair", "barricade", "oil_slick", "chill"]
# The finished cards are cut out of the sketch at this offset (the sketch's margin).
OX, OY = spells.OFFSET
ICON_CENTER = (162, 1107)
ICON_RADIUS = 62
ICON_HALF = 64
# Tower stat icons on the archer card: name -> x range inside its stat box (card coordinates).
STAT_ICONS = {"damage": (94, 151), "attack_speed": (330, 382), "range": (578, 650)}
STAT_ICON_ROWS = (1244, 1318)


def blank_frame(base):
    """The sketch's frame with every piece of card-specific text and art cleared."""
    rgb = spells.fill(base, [(196, 894), (642, 894), (642, 954), (196, 954)], grow=0)
    for top in (1046, 1096, 1146):
        rgb = spells.fill(rgb, [(266, top), (744, top), (744, top + 46), (266, top + 46)], grow=0)
    for x0, x1 in spells.STAT_BOXES:
        rgb = spells.clear_stat_box(rgb, x0, x1)
    img = spells.to_image(rgb)
    icx, icy = ICON_CENTER[0] + OX, ICON_CENTER[1] + OY
    disc = tuple(int(v) for v in rgb[icy + 52, icx])
    ImageDraw.Draw(img).ellipse([icx - ICON_RADIUS, icy - ICON_RADIUS, icx + ICON_RADIUS, icy + ICON_RADIUS], fill=disc)
    return spells.to_array(img)


def stat_icon(card, x0, x1):
    """Crops a gold stat icon and un-blends it from the dark box behind it, returning the RGBA
    icon and its rectangle in card coordinates."""
    y0, y1 = STAT_ICON_ROWS
    box = (x0 - 6, y0, x1 + 7, y1)
    rgb = np.array(card.crop(box).convert("RGB")).astype(np.float64)
    lum = rgb.mean(-1)
    bg = np.median(rgb[lum < np.percentile(lum, 30)], axis=0)
    fg_lum = np.percentile(lum, 99)
    alpha = np.clip((lum - bg.mean()) / max(1.0, fg_lum - bg.mean()), 0, 1)
    color = (rgb - bg * (1 - alpha[..., None])) / np.maximum(alpha[..., None], 1e-3)
    out = np.dstack([np.clip(color, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), box


def main():
    base = np.array(Image.open(archer.SOURCE).convert("RGB")).astype(np.float64)
    base = archer.erase_cost(base)
    base = archer.remove_second_archer(base)
    base = archer.remove_background_castle(base)
    window = spells.frame_window(base)[..., 0]

    frame = archer.cut_out_card(blank_frame(base))
    width, height = frame.size
    window = window[OY:OY + height, OX:OX + width]
    alpha = np.array(frame.getchannel("A")).astype(np.float64) * (1.0 - window)
    frame.putalpha(Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8)))
    frame.save(ROOT / "assets/cards/frame.png")
    print(f"Saved assets/cards/frame.png {frame.size}")

    ys, xs = np.nonzero(window > 0.002)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    disc = Image.new("L", (ICON_HALF * 8, ICON_HALF * 8), 0)
    ImageDraw.Draw(disc).ellipse([16, 16, ICON_HALF * 8 - 16, ICON_HALF * 8 - 16], fill=255)
    disc = disc.resize((ICON_HALF * 2, ICON_HALF * 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    (ROOT / "assets/cards/paintings").mkdir(exist_ok=True)
    (ROOT / "assets/cards/icons").mkdir(exist_ok=True)
    for name in CARDS:
        card = Image.open(ROOT / f"art/cards/{name}.png").convert("RGBA")
        assert card.size == frame.size, f"{name} is {card.size}, frame is {frame.size}"
        card.crop(box).convert("RGB").save(ROOT / f"assets/cards/paintings/{name}.png")
        cx, cy = ICON_CENTER
        icon = card.crop((cx - ICON_HALF, cy - ICON_HALF, cx + ICON_HALF, cy + ICON_HALF))
        icon.putalpha(disc)
        icon.save(ROOT / f"assets/cards/icons/{name}.png")
        print(f"Saved painting and icon for {name}")
    (ROOT / "assets/cards/stat_icons").mkdir(exist_ok=True)
    archer_card = Image.open(ROOT / "art/cards/archer_tower.png").convert("RGBA")
    for name, (x0, x1) in STAT_ICONS.items():
        icon, rect = stat_icon(archer_card, x0, x1)
        icon.save(ROOT / f"assets/cards/stat_icons/{name}.png")
        print(f"Stat icon {name}: Rect2({rect[0]}, {rect[1]}, {rect[2] - rect[0]}, {rect[3] - rect[1]})")
    print(f"Painting rect: Rect2({box[0]}, {box[1]}, {box[2] - box[0]}, {box[3] - box[1]})")
    print(f"Icon rect: Rect2({ICON_CENTER[0] - ICON_HALF}, {ICON_CENTER[1] - ICON_HALF}, {ICON_HALF * 2}, {ICON_HALF * 2})")
    gx, gy = archer.GEM_CENTER
    r = archer.GEM_RADIUS
    print(f"Cost gem rect: Rect2({gx - r - OX}, {gy - r - OY}, {2 * r}, {2 * r})")


if __name__ == "__main__":
    main()
