class_name Units
extends RefCounted
## World units and map pixels. Distances and speeds are tuned in world units, where the 720-unit
## reference screen width spans the 941-pixel-wide woodland map. Nodes on the battlefield work in
## map pixels, and the battlefield scales them to the screen.

const PX_PER_UNIT := 941.0 / 720.0
## World units in one "pace", the distance cards print: the Archer Tower's 180 range reads 5.0.
const UNITS_PER_PACE := 36.0


## Map pixels for a distance (or a speed per second) in world units.
static func px(units: float) -> float:
	return units * PX_PER_UNIT


## Paces for a distance in world units, as printed on cards.
static func paces(units: float) -> float:
	return units / UNITS_PER_PACE
