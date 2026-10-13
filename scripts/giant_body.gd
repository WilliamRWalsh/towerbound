class_name GiantBody
extends EnemyBody
## Procedural giant art: a hulking, pot-bellied brute in a hide loincloth, with a small bald head,
## tusks, and a tree-trunk club. Lumbers slowly and topples face-first when it dies.

const SKIN := Color(0.78, 0.6, 0.44)
const SKIN_DARK := Color(0.58, 0.42, 0.3)
const OUTLINE := Color(0.15, 0.11, 0.08)
const HIDE := Color(0.45, 0.32, 0.19)
const HIDE_DARK := Color(0.31, 0.21, 0.12)
const STRAP := Color(0.25, 0.17, 0.1)
const TUSK := Color(0.95, 0.92, 0.82)
const EYE := Color(0.95, 0.85, 0.3)
const WOOD := Color(0.47, 0.32, 0.18)
const WOOD_DARK := Color(0.3, 0.2, 0.1)
const SHADOW := Color(0, 0, 0, 0.3)

const HIP_HEIGHT := 46.0
const LEG := 24.0
const ARM := 25.0
const CLUB_LENGTH := 50.0

## Whole-body transform while toppling; parts drawn in their own frame compose with it.
var _base := Transform2D.IDENTITY


func _init() -> void:
	chest_height = 82.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 32.0, SHADOW)
	# Falling forward onto its face: pivot at the toes, then lie flat.
	var fall := death * death
	_base = Transform2D(fall * 1.5, Vector2(8.0 * fall, 0))
	draw_set_transform_matrix(_base)

	var bob := -absf(sin(walk_phase)) * 3.0 * (1.0 - death)
	var sway := sin(walk_phase) * 0.05 * (1.0 - death)
	var hip := Vector2(0, -HIP_HEIGHT + bob)
	var swing := sin(walk_phase) * 0.4
	var shoulder := hip + Vector2(2, -52).rotated(sway)

	_draw_leg(hip + Vector2(-5, 0), -swing, SKIN_DARK)
	_draw_arm(shoulder + Vector2(-8, 2), -swing * 0.7, SKIN_DARK)
	_draw_leg(hip + Vector2(4, 0), swing, SKIN)

	# Pot belly and broad chest, then the hide loincloth and a shoulder strap.
	var belly := hip + Vector2(4, -22).rotated(sway)
	_outlined_ellipse(belly, Vector2(27, 30), lit(SKIN))
	_outlined_ellipse(shoulder + Vector2(-2, 10), Vector2(24, 16), lit(SKIN))
	draw_circle(belly + Vector2(8, -6), 9.0, lit(SKIN.lightened(0.12)))
	draw_line(belly + Vector2(8, 4), belly + Vector2(10, 8), lit(SKIN_DARK), 2.0)
	var cloth := PackedVector2Array([
		hip + Vector2(-24, -8), hip + Vector2(26, -8), hip + Vector2(24, 8), hip + Vector2(14, 18),
		hip + Vector2(6, 10), hip + Vector2(-4, 19), hip + Vector2(-14, 10), hip + Vector2(-25, 14),
	])
	_outlined_polygon(cloth, lit(HIDE))
	draw_line(hip + Vector2(-23, -6), hip + Vector2(25, -6), lit(HIDE_DARK), 3.0)
	draw_line(shoulder + Vector2(-16, 0), hip + Vector2(16, -10), STRAP, 5.0)

	_draw_head(shoulder + Vector2(9, -12).rotated(sway), sway)

	var club_arm := _arm_points(shoulder + Vector2(6, 2), weapon_angle)
	var hand := club_arm[2]
	var club_dir := (hand - club_arm[1]).normalized().rotated(lerpf(-PI / 2 + 0.4, -0.15, swoosh))
	draw_swoosh(shoulder, ARM * 2.0 + CLUB_LENGTH * 0.8)
	_draw_club(hand, hand + club_dir * CLUB_LENGTH)
	_limb(club_arm[0], club_arm[1], 11.0, SKIN)
	_limb(club_arm[1], club_arm[2], 10.0, SKIN)
	draw_circle(hand, 7.5, OUTLINE)
	draw_circle(hand, 6.3, lit(SKIN))

	draw_set_transform(Vector2.ZERO)
	draw_health_bar(-128.0, 44.0)


func _draw_head(center: Vector2, tilt: float) -> void:
	draw_set_transform_matrix(_base * Transform2D(tilt, center))
	# Small bald head under a heavy brow, with a jutting jaw and tusks.
	draw_circle(Vector2(1, 2), 14.5, OUTLINE)
	draw_circle(Vector2(1, 2), 13.2, lit(SKIN))
	draw_circle(Vector2(-3, -4), 5.0, lit(SKIN.lightened(0.15)))
	_outlined_polygon(PackedVector2Array([Vector2(-2, 6), Vector2(15, 5), Vector2(14, 14), Vector2(0, 15)]), lit(SKIN_DARK))
	_outlined_polygon(PackedVector2Array([Vector2(8, 7), Vector2(10, -1), Vector2(12, 7)]), TUSK)
	_outlined_polygon(PackedVector2Array([Vector2(2, 7), Vector2(4, 0), Vector2(6, 7)]), TUSK)
	draw_line(Vector2(2, -6), Vector2(15, -4), OUTLINE, 3.0)
	if death < 0.4:
		draw_circle(Vector2(10, -2), 2.0, EYE)
		draw_circle(Vector2(10.5, -2), 0.9, OUTLINE)
	else:
		draw_line(Vector2(8, -3), Vector2(12, -1), OUTLINE, 1.5)
	_outlined_ellipse(Vector2(-11, 1), Vector2(3.5, 5.0), lit(SKIN_DARK))
	draw_set_transform_matrix(_base)


func _draw_leg(hip: Vector2, angle: float, color: Color) -> void:
	var knee := hip + Vector2(sin(angle), cos(angle)) * LEG
	var foot := knee + Vector2(sin(angle * 0.4), cos(angle * 0.4)) * LEG
	_limb(hip, knee, 14.0, color)
	_limb(knee, foot, 12.0, color)
	_outlined_ellipse(foot + Vector2(4, -2), Vector2(10, 5.5), lit(color.darkened(0.1)))


func _draw_arm(shoulder: Vector2, angle: float, color: Color) -> void:
	var points := _arm_points(shoulder, angle)
	_limb(points[0], points[1], 10.0, color)
	_limb(points[1], points[2], 9.0, color)
	draw_circle(points[2], 6.0, OUTLINE)
	draw_circle(points[2], 4.8, lit(color))


func _arm_points(shoulder: Vector2, angle: float) -> PackedVector2Array:
	var elbow := shoulder + Vector2(sin(angle), cos(angle)) * ARM
	var bend := angle + 0.35
	return PackedVector2Array([shoulder, elbow, elbow + Vector2(sin(bend), cos(bend)) * ARM])


## A rough tree-trunk club, thickening toward the tip, with a broken-off branch.
func _draw_club(grip: Vector2, tip: Vector2) -> void:
	var dir := (tip - grip).normalized()
	var side := dir.orthogonal()
	var start := grip - dir * 8.0
	var outline := PackedVector2Array([start + side * 5.5, tip + side * 10.5, tip + dir * 4.0, tip - side * 10.5, start - side * 5.5])
	var body := PackedVector2Array([start + side * 4.0, tip + side * 9.0, tip + dir * 2.5, tip - side * 9.0, start - side * 4.0])
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(body, lit(WOOD))
	var knot := grip + dir * CLUB_LENGTH * 0.6
	draw_line(knot + side * 6.0, knot + side * 14.0 + dir * 6.0, OUTLINE, 5.0)
	draw_line(knot + side * 6.0, knot + side * 13.0 + dir * 5.5, lit(WOOD), 3.0)
	draw_line(grip + dir * 14.0 - side * 2.0, tip - dir * 6.0 - side * 4.0, lit(WOOD_DARK), 2.0)
	draw_circle(tip - dir * 10.0 + side * 3.0, 2.0, WOOD_DARK)


func _limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, OUTLINE, width + 2.6)
	draw_circle(a, width * 0.5 + 1.3, OUTLINE)
	draw_circle(b, width * 0.5 + 1.3, OUTLINE)
	draw_line(a, b, lit(color), width)
	draw_circle(a, width * 0.5, lit(color))
	draw_circle(b, width * 0.5, lit(color))


func _outlined_polygon(points: PackedVector2Array, color: Color) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, color)
	draw_polyline(closed, OUTLINE, 1.8)


func _outlined_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		points.append(center + Vector2.from_angle(TAU * i / 24.0) * radii)
	_outlined_polygon(points, color)
