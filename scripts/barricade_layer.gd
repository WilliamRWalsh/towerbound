class_name BarricadeLayer
extends Node2D
## Holds the barricades placed on the enemy path, in map pixels, and previews placement while a
## Barricade card is aimed. A barricade snaps to the nearest point on the road; it is invalid
## too far from the road, near either end of it, or too close to another barricade.

## Furthest a drop can be from the road and still snap to it, in map pixels.
const SNAP_DISTANCE := 80.0
## Keep clear of the Badlands gate (under the notch) and the crowd at the castle gate.
const MIN_PROGRESS := 160.0
const END_CLEARANCE := 200.0
## Closest two standing barricades may be along the road.
const MIN_GAP := 110.0
const INVALID := -1.0

@export var path: Path2D

var _ghost: Barricade = null


## Where a canvas position snaps to along the road, or INVALID.
func snap(global_pos: Vector2) -> float:
	var curve := path.curve
	var local := path.to_local(global_pos)
	var offset := curve.get_closest_offset(local)
	if local.distance_to(curve.sample_baked(offset)) > SNAP_DISTANCE:
		return INVALID
	if offset < MIN_PROGRESS or offset > curve.get_baked_length() - END_CLEARANCE:
		return INVALID
	for barricade: Barricade in get_tree().get_nodes_in_group(Barricade.GROUP):
		if absf(barricade.progress - offset) < MIN_GAP:
			return INVALID
	return offset


## Places a barricade at the snapped point. Returns false, changing nothing, if invalid.
func place(global_pos: Vector2, health: float) -> bool:
	var offset := snap(global_pos)
	if offset == INVALID:
		return false
	var barricade := Barricade.new()
	add_child(barricade)
	barricade.place_on(path.curve, offset)
	barricade.activate(health)
	return true


func begin_preview() -> void:
	end_preview()
	_ghost = Barricade.new()
	_ghost.preview = true
	_ghost.visible = false
	add_child(_ghost)


func update_preview(global_pos: Vector2, over_field: bool) -> void:
	if _ghost == null:
		return
	_ghost.visible = over_field
	var offset := snap(global_pos)
	if offset != INVALID:
		_ghost.place_on(path.curve, offset)
	else:
		_ghost.position = to_local(global_pos)
	_ghost.preview_valid = offset != INVALID


func end_preview() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
