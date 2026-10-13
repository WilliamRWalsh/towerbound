class_name Damage
extends RefCounted
## Damage types. Each enemy takes more or less of each type (`EnemyStats.multiplier`). Also draws
## the small icon for each type, shared by the wave preview and the card badges.

enum Type { PIERCE, CRUSH, FIRE, FROST }

const NONE := -1
const NAMES := ["Pierce", "Crush", "Fire", "Frost"]


## Draws the type's icon centered at `center`, about `size` across.
static func draw_icon(canvas: CanvasItem, center: Vector2, size: float, type: int) -> void:
	var s := size / 24.0
	match type:
		Type.PIERCE:
			# An arrow pointing up and to the right.
			var dir := Vector2(1, -1).normalized()
			var tip := center + dir * 10.0 * s
			var tail := center - dir * 10.0 * s
			canvas.draw_line(tail, tip - dir * 4.0 * s, Color(0.15, 0.1, 0.06), 4.0 * s)
			canvas.draw_line(tail, tip - dir * 4.0 * s, Color(0.85, 0.65, 0.4), 2.2 * s)
			var side := dir.orthogonal()
			canvas.draw_colored_polygon(PackedVector2Array([
				tip, tip - dir * 7.0 * s + side * 4.0 * s, tip - dir * 7.0 * s - side * 4.0 * s,
			]), Color(0.88, 0.9, 0.95))
			for k in [-1.0, 1.0]:
				canvas.draw_line(tail + dir * 3.0 * s, tail + side * 4.0 * k * s, Color(0.9, 0.25, 0.18), 2.0 * s)
		Type.CRUSH:
			# A cannonball with a highlight.
			canvas.draw_circle(center, 9.0 * s, Color(0.06, 0.06, 0.07))
			canvas.draw_circle(center, 7.5 * s, Color(0.36, 0.37, 0.42))
			canvas.draw_circle(center + Vector2(-2.5, -2.5) * s, 2.6 * s, Color(0.75, 0.77, 0.82))
		Type.FIRE:
			# A flame: a teardrop of ember, flame, and core.
			_flame(canvas, center + Vector2(0, 2) * s, 10.0 * s, Color(0.85, 0.2, 0.05))
			_flame(canvas, center + Vector2(0, 4) * s, 7.0 * s, Color(1.0, 0.55, 0.12))
			_flame(canvas, center + Vector2(0, 6) * s, 3.8 * s, Color(1.0, 0.92, 0.6))
		Type.FROST:
			# A six-armed snowflake.
			for i in 3:
				var arm := Vector2.from_angle(PI * i / 3.0 + PI / 2.0) * 10.0 * s
				canvas.draw_line(center - arm, center + arm, Color(0.12, 0.2, 0.32), 4.0 * s)
			for i in 3:
				var arm := Vector2.from_angle(PI * i / 3.0 + PI / 2.0) * 10.0 * s
				canvas.draw_line(center - arm, center + arm, Color(0.78, 0.92, 1.0), 2.2 * s)
				for end in [arm, -arm]:
					var base: Vector2 = center + end * 0.6
					var d: Vector2 = end.normalized()
					canvas.draw_line(base, base + d.rotated(0.8) * 3.5 * s, Color(0.78, 0.92, 1.0), 1.6 * s)
					canvas.draw_line(base, base + d.rotated(-0.8) * 3.5 * s, Color(0.78, 0.92, 1.0), 1.6 * s)


## A teardrop flame: round at the bottom, pointed at the top. `base` is the round part's center.
static func _flame(canvas: CanvasItem, base: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := lerpf(-0.15 * PI, 1.15 * PI, i / 12.0)
		points.append(base + Vector2(cos(a), sin(a)) * radius)
	points.append(base + Vector2(0, -radius * 2.1))
	canvas.draw_colored_polygon(points, color)
