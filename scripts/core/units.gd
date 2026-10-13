class_name Units
extends RefCounted
## World units and map pixels. Distances and speeds are tuned in world units, where the 720-unit
## reference screen width spans the 941-pixel-wide woodland map. Nodes on the battlefield work in
## map pixels, and the battlefield scales them to the screen.

const PX_PER_UNIT := 941.0 / 720.0


## Map pixels for a distance (or a speed per second) in world units.
static func px(units: float) -> float:
	return units * PX_PER_UNIT
