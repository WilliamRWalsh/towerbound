class_name GoblinBody
extends EnemyBody
## Procedural goblin art: a small green goblin with a big head, long ears, a ragged tunic, and a
## knobbly club. Waddles as it walks and topples over backward when it dies. Its colors are
## exported so the big goblin can reuse it.

const OUTLINE := Color(0.13, 0.12, 0.08)
const BELT := Color(0.22, 0.15, 0.09)
const BOOT := Color(0.24, 0.17, 0.1)
const EYE := Color(1.0, 0.86, 0.2)
const CLUB := Color(0.55, 0.37, 0.2)
const CLUB_DARK := Color(0.36, 0.23, 0.12)
const SHADOW := Color(0, 0, 0, 0.28)

## Colors, so bigger goblin kinds can share this art.
@export var skin := Color(0.45, 0.66, 0.24)
@export var skin_dark := Color(0.3, 0.47, 0.15)
@export var tunic := Color(0.5, 0.33, 0.18)
@export var tunic_dark := Color(0.36, 0.22, 0.11)

const HIP_HEIGHT := 12.0
const LEG := 6.5
const ARM := 7.0
const CLUB_LENGTH := 15.0

## Whole-body transform while toppling over; parts drawn in their own frame compose with it.
var _base := Transform2D.IDENTITY


func _init() -> void:
	chest_height = 22.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 10.0, SHADOW)
	# Falling over backward: pivot at the heels, then lie flat.
	var fall := death * death
	_base = Transform2D(-fall * 1.45, Vector2(-3.0 * fall, 0))
	draw_set_transform_matrix(_base)

	var bob := -absf(sin(walk_phase)) * 1.6 * (1.0 - death)
	var waddle := sin(walk_phase) * 0.08 * (1.0 - death)
	var hip := Vector2(0, -HIP_HEIGHT + bob)
	var swing := sin(walk_phase) * 0.6
	var shoulder := hip + Vector2(1, -10).rotated(waddle)

	_draw_leg(hip, -swing, skin_dark)
	_draw_arm(shoulder, -swing * 0.8)
	_draw_leg(hip, swing, skin)

	# Ragged tunic over a round belly, with a rope belt.
	var top := hip + Vector2(1, -12).rotated(waddle)
	var tunic_shape := PackedVector2Array([
		top + Vector2(-6, 0), top + Vector2(6, 0), hip + Vector2(8, 3), hip + Vector2(5, 1),
		hip + Vector2(2, 4), hip + Vector2(-2, 1), hip + Vector2(-5, 4), hip + Vector2(-8, 2),
	])
	_outlined_polygon(tunic_shape, lit(tunic))
	draw_line(top + Vector2(-5, 1), hip + Vector2(-7, 1), lit(tunic_dark), 2.0)
	draw_line(hip + Vector2(-7, -3), hip + Vector2(8, -3), BELT, 2.4)

	_draw_head(shoulder + Vector2(2, -9).rotated(waddle), waddle)

	var club_arm := _arm_points(shoulder, weapon_angle)
	var hand := club_arm[2]
	var club_dir := (hand - club_arm[1]).normalized().rotated(lerpf(-PI / 2 + 0.5, -0.2, swoosh))
	draw_swoosh(shoulder, ARM * 2.0 + CLUB_LENGTH * 0.8)
	_draw_club(hand, hand + club_dir * CLUB_LENGTH)
	_limb(club_arm[0], club_arm[1], 3.0, skin)
	_limb(club_arm[1], club_arm[2], 3.0, skin)
	draw_circle(hand, 2.6, lit(skin))

	draw_set_transform(Vector2.ZERO)
	draw_health_bar(-50.0)


func _draw_head(center: Vector2, tilt: float) -> void:
	draw_set_transform_matrix(_base * Transform2D(tilt, center))
	# Long ears sweeping back, then the big round head.
	_outlined_polygon(PackedVector2Array([Vector2(-5, -3), Vector2(-17, -9), Vector2(-14, -5), Vector2(-4, 2)]), lit(skin_dark))
	_outlined_polygon(PackedVector2Array([Vector2(3, -6), Vector2(9, -16), Vector2(8, -9), Vector2(6, -3)]), lit(skin_dark))
	draw_circle(Vector2.ZERO, 9.2, OUTLINE)
	draw_circle(Vector2.ZERO, 8.0, lit(skin))
	draw_circle(Vector2(-2.5, -3.0), 3.5, lit(skin.lightened(0.15)))
	# Hooked nose, wide grin with a tooth, and a yellow eye (crossed out once it falls).
	_outlined_polygon(PackedVector2Array([Vector2(6, -2), Vector2(13, 2), Vector2(6, 3)]), lit(skin))
	draw_line(Vector2(1, 5), Vector2(7, 4.5), OUTLINE, 1.4)
	draw_rect(Rect2(4.5, 4.5, 1.8, 2.0), Color(0.95, 0.93, 0.85))
	if death < 0.4:
		draw_circle(Vector2(4.0, -2.0), 2.6, OUTLINE)
		draw_circle(Vector2(4.0, -2.0), 2.0, EYE)
		draw_circle(Vector2(4.6, -2.0), 0.9, OUTLINE)
		draw_line(Vector2(1.0, -5.0), Vector2(6.5, -4.0), OUTLINE, 1.5)
	else:
		draw_line(Vector2(2.5, -3.5), Vector2(5.5, -0.5), OUTLINE, 1.3)
		draw_line(Vector2(5.5, -3.5), Vector2(2.5, -0.5), OUTLINE, 1.3)
	draw_set_transform_matrix(_base)


func _draw_leg(hip: Vector2, angle: float, color: Color) -> void:
	var knee := hip + Vector2(sin(angle), cos(angle)) * LEG
	var foot := knee + Vector2(sin(angle * 0.4), cos(angle * 0.4)) * LEG
	_limb(hip, knee, 3.2, color)
	_limb(knee, foot, 3.2, color)
	draw_circle(foot + Vector2(1.5, -0.5), 3.4, OUTLINE)
	draw_circle(foot + Vector2(1.5, -0.5), 2.5, lit(BOOT))


func _draw_arm(shoulder: Vector2, angle: float) -> void:
	var points := _arm_points(shoulder, angle)
	_limb(points[0], points[1], 2.8, skin_dark)
	_limb(points[1], points[2], 2.8, skin_dark)


func _arm_points(shoulder: Vector2, angle: float) -> PackedVector2Array:
	var elbow := shoulder + Vector2(sin(angle), cos(angle)) * ARM
	var bend := angle + 0.4
	return PackedVector2Array([shoulder, elbow, elbow + Vector2(sin(bend), cos(bend)) * ARM])


func _draw_club(grip: Vector2, tip: Vector2) -> void:
	var dir := (tip - grip).normalized()
	draw_line(grip - dir * 3.0, tip, OUTLINE, 5.0)
	draw_line(grip - dir * 2.0, tip, lit(CLUB), 3.0)
	draw_circle(tip, 5.2, OUTLINE)
	draw_circle(tip, 4.2, lit(CLUB))
	draw_circle(tip + dir.orthogonal() * 2.0 - dir, 1.2, CLUB_DARK)
	draw_circle(tip - dir.orthogonal() * 2.5 + dir, 1.0, CLUB_DARK)


func _limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, OUTLINE, width + 2.0)
	draw_circle(a, width * 0.5 + 1.0, OUTLINE)
	draw_circle(b, width * 0.5 + 1.0, OUTLINE)
	draw_line(a, b, lit(color), width)
	draw_circle(a, width * 0.5, lit(color))
	draw_circle(b, width * 0.5, lit(color))


func _outlined_polygon(points: PackedVector2Array, color: Color) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, color)
	draw_polyline(closed, OUTLINE, 1.4)
