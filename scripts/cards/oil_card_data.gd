class_name OilCardData
extends CardData
## Spills a slick of oil on the road that slows enemies wading through it. Fire touching the
## slick (Fireball, burning ground) ignites it into a long, hot blaze.

## How far from the road a drop still snaps onto it, in map pixels.
const SNAP_DISTANCE := 80.0
const OIL_COLOR := Color(0.62, 0.45, 0.9)

## Slick radius in world units at the 720 × 1280 reference resolution.
@export var radius := 55.0
## Speed multiplier for enemies in the slick.
@export var slow := 0.6
@export var duration := 25.0
## The blaze the slick becomes when ignited.
@export var burn_dps := 2.5
@export var burn_duration := 7.0


func begin_targeting(field: Battlefield) -> void:
	field.overlay.show_circle(radius * BuildGrid.MAP_PIXELS_PER_UNIT, OIL_COLOR)


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	var point := field.road_point(global_pos, SNAP_DISTANCE)
	var valid := point != Vector2.INF
	field.overlay.move_circle(point if valid else global_pos, over_field, valid)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	var point := field.road_point(global_pos, SNAP_DISTANCE)
	if point == Vector2.INF:
		return false
	OilSlick.spill(field.ground, point, radius * BuildGrid.MAP_PIXELS_PER_UNIT, slow, duration,
		burn_dps, burn_duration)
	return true
