"""Writes the woodland level's wave resources (data/levels/woodland/wave_01-10.tres).

Each wave is a list of groups: (pause before the group, seconds between enemies, counts per
enemy type). Inside a group the types are interleaved evenly, so tougher enemies march inside
the crowd instead of all at the front or back. Edit WAVES and rerun: python tools/make_waves.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data/levels/woodland"

# Enemy key -> (scene, ext_resource id).
ENEMIES = {
    "S": ("res://scenes/skeleton.tscn", "3_skeleton"),
    "G": ("res://scenes/goblin.tscn", "4_goblin"),
    "B": ("res://scenes/big_goblin.tscn", "5_big_goblin"),
    "T": ("res://scenes/giant.tscn", "6_giant"),
    "Z": ("res://scenes/zombie.tscn", "7_zombie"),
}

# S skeleton, G goblin, B big goblin, T giant, Z zombie.
WAVES = [
    [(1.0, 0.45, "S2"), (2.5, 0.35, "S3G1"), (2.5, 0.3, "S3G2"), (3.0, 0.28, "S3G2")],
    [(1.0, 0.4, "S3G1"), (2.5, 0.3, "S4G2"), (2.5, 0.3, "S3G3"), (3.0, 0.25, "S4G2")],
    [(1.0, 0.35, "S3G2"), (2.5, 0.3, "S4G3"), (2.5, 0.28, "Z1S3G3"), (3.0, 0.25, "Z1S5G5")],
    [(1.0, 0.35, "S3G2"), (2.5, 0.3, "B1Z1S3G3"), (2.5, 0.28, "S4G4"), (3.0, 0.25, "B1Z1S6G7")],
    [(1.0, 0.3, "S4G2"), (2.5, 0.3, "B1Z1S3G4"), (2.5, 0.28, "B1Z1S4G4"), (3.0, 0.25, "B1Z1S8G8")],
    [(1.0, 0.3, "S4G3"), (2.5, 0.28, "B2Z1S3G4"), (2.5, 0.25, "B1Z1S5G5"), (3.0, 0.22, "B2Z2S9G9")],
    [(1.0, 0.3, "Z1S4G4"), (2.5, 0.28, "B2Z1S4G4"), (2.5, 0.25, "B2Z1S5G6"), (3.0, 0.22, "B2Z2S10G11")],
    [(1.0, 0.28, "Z1S5G4"), (2.5, 0.25, "B2Z1S5G5"), (2.5, 0.25, "B2Z1S6G6"), (2.5, 0.22, "B1Z1S4G4"),
     (3.0, 0.2, "B2Z2S8G8")],
    [(1.0, 0.28, "Z1S5G5"), (2.5, 0.25, "B2Z1S5G6"), (2.5, 0.25, "B2Z2S6G6"), (2.5, 0.22, "B2Z1S5G5"),
     (3.0, 0.2, "T1B2Z2S9G9")],
    [(1.0, 0.25, "Z1S6G6"), (2.5, 0.22, "B3Z2S5G6"), (2.5, 0.22, "B2Z2S6G7"), (2.5, 0.2, "T1B2Z2S6G6"),
     (3.0, 0.2, "T1B3Z3S9G10")],
]
ANNOUNCEMENTS = {10: "Final Wave"}


def parse_counts(spec):
    counts, i = {}, 0
    while i < len(spec):
        key, j = spec[i], i + 1
        while j < len(spec) and spec[j].isdigit():
            j += 1
        counts[key] = int(spec[i + 1:j])
        i = j
    return counts


def interleave(counts):
    """Spreads each type evenly through the group; rarer (tougher) types win ties."""
    total = sum(counts.values())
    slots = []
    for rank, (key, n) in enumerate(sorted(counts.items(), key=lambda kv: kv[1])):
        slots += [((i + 0.5) * total / n, rank, key) for i in range(n)]
    return [key for _, _, key in sorted(slots)]


def wave_text(number, groups):
    used = sorted({k for _, _, spec in groups for k in parse_counts(spec)}, key=list(ENEMIES).index)
    lines = [f'[gd_resource type="Resource" script_class="WaveConfig" load_steps={3 + len(used) + len(groups)} format=3]', "",
             '[ext_resource type="Script" path="res://scripts/wave_config.gd" id="1_wave"]',
             '[ext_resource type="Script" path="res://scripts/wave_group.gd" id="2_group"]']
    for key in used:
        path, rid = ENEMIES[key]
        lines.append(f'[ext_resource type="PackedScene" path="{path}" id="{rid}"]')
    for g, (pause, spacing, spec) in enumerate(groups, 1):
        order = ", ".join(f'ExtResource("{ENEMIES[k][1]}")' for k in interleave(parse_counts(spec)))
        lines += ["", f'[sub_resource type="Resource" id="Resource_group{g}"]', 'script = ExtResource("2_group")',
                  f"pause_before = {pause}", f"spacing = {spacing}",
                  f"enemies = Array[PackedScene]([{order}])"]
    refs = ", ".join(f'SubResource("Resource_group{g}")' for g in range(1, len(groups) + 1))
    lines += ["", "[resource]", 'script = ExtResource("1_wave")', f'groups = Array[ExtResource("2_group")]([{refs}])']
    if number in ANNOUNCEMENTS:
        lines.append(f'announcement = "{ANNOUNCEMENTS[number]}"')
    return "\n".join(lines) + "\n"


def main():
    for number, groups in enumerate(WAVES, 1):
        (OUT_DIR / f"wave_{number:02d}.tres").write_text(wave_text(number, groups))
        totals = {}
        for _, _, spec in groups:
            for k, n in parse_counts(spec).items():
                totals[k] = totals.get(k, 0) + n
        print(f"wave {number:2d}: {sum(totals.values()):3d} enemies {totals}")


if __name__ == "__main__":
    main()
