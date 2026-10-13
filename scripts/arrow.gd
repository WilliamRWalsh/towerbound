class_name Arrow
extends Node2D
## An arrow flying from a tower to an enemy. Homes on the target's chest and deals damage once
## on contact. If the target dies or leaves play mid-flight, the arrow lands where it was aimed
## and fades out without effect. Works in its parent's (map-pixel) coordinates.

const LENGTH := 34.0
const TRAIL_LENGTH := 48.0
const HIT_RADIUS := 8.0
const FADE_TIME := 0.25

var _target: Enemy
var _damage := 1.0
var _damage_type := Damage.Type.PIERCE
var _speed := 0.0
## Damage reserved with TargetPlanner until this resolves; the enemy's instance id it is for.
var _committed := 0.0
var _committed_to := 0
var _aim := Vector2.ZERO
var _traveled := 0.0
var _done := false


## Fires an arrow from a canvas position. `speed` is in reference units per second.
static func launch(layer: Node2D, from_global: Vector2, target: Enemy, damage: float,
		damage_type: Damage.Type, speed: float) -> Arrow:
	var arrow := Arrow.new()
	arrow._target = target
	arrow._damage = damage
	arrow._damage_type = damage_type
	arrow._speed = speed * BuildGrid.MAP_PIXELS_PER_UNIT
	arrow._committed = TargetPlanner.commit(target, damage, damage_type)
	arrow._committed_to = target.get_instance_id()
	layer.add_child(arrow)
	arrow.position = layer.to_local(from_global)
	arrow._aim = layer.to_local(target.aim_point())
	arrow.rotation = (arrow._aim - arrow.position).angle()
	return arrow


func _process(delta: float) -> void:
	if _done:
		return
	var tracking := is_instance_valid(_target) and _target.is_alive()
	if tracking:
		_aim = get_parent().to_local(_target.aim_point())
	var to_aim := _aim - position
	var step := _speed * delta
	if to_aim.length() <= step + HIT_RADIUS:
		position = _aim
		_release()
		if tracking:
			_target.take_damage(_damage, _damage_type)
			queue_free()
		else:
			_land()
		return
	rotation = to_aim.angle()
	position += to_aim.normalized() * step
	_traveled += step
	queue_redraw()


## The target is gone: drop the arrow where it was headed and fade it out.
func _land() -> void:
	_done = true
	_traveled = 0.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Origin is the arrowhead tip; the shaft trails back along -x.
	var trail := minf(TRAIL_LENGTH, maxf(0.0, _traveled - LENGTH))
	if trail > 0.0:
		draw_polyline_colors(
			PackedVector2Array([Vector2(-LENGTH - trail, 0), Vector2(-LENGTH, 0)]),
			PackedColorArray([Color(1, 1, 0.9, 0.0), Color(1, 1, 0.9, 0.6)]), 3.0)
	var head := PackedVector2Array([Vector2(0, 0), Vector2(-11, -5.5), Vector2(-11, 5.5)])
	draw_line(Vector2(-LENGTH, 0), Vector2(-8, 0), Color(0.15, 0.1, 0.06), 5.0)
	draw_line(Vector2(-LENGTH, 0), Vector2(-8, 0), Color(0.66, 0.45, 0.24), 2.6)
	draw_colored_polygon(head, Color(0.15, 0.12, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-1.6, 0), Vector2(-10, -4.2), Vector2(-10, 4.2)]), Color(0.86, 0.88, 0.92))
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-LENGTH + 9, 0), Vector2(-LENGTH, 0), Vector2(-LENGTH - 4, 6.0 * side), Vector2(-LENGTH + 5, 6.0 * side),
		]), Color(0.9, 0.2, 0.15))


func _exit_tree() -> void:
	_release()


## Hands the reserved damage back to TargetPlanner, once.
func _release() -> void:
	if _committed_to != 0:
		TargetPlanner.release(_committed_to, _committed)
		_committed_to = 0
