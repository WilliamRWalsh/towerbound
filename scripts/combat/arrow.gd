class_name Arrow
extends Projectile
## An arrow flying straight at an enemy's chest. If the target is gone by the time it gets there,
## it drops where it was aimed and fades out.

const LENGTH := 34.0
const TRAIL_LENGTH := 48.0
const HIT_RADIUS := 8.0
const FADE_TIME := 0.25

var _traveled := 0.0


func _launched() -> void:
	rotation = (_aim - position).angle()


func _advance(delta: float) -> bool:
	var to_aim := _aim - position
	var step := _speed * delta
	if to_aim.length() <= step + HIT_RADIUS:
		position = _aim
		return true
	rotation = to_aim.angle()
	position += to_aim.normalized() * step
	_traveled += step
	queue_redraw()
	return false


func _arrive(struck: bool) -> void:
	if struck:
		queue_free()
		return
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
