class_name ZombieBody
extends EnemyBody
## Procedural zombie art: a hunched, grey-green corpse in a torn shirt, arms reaching forward,
## dragging its back leg. Swipes at the gate with its claws, pitches forward onto its face when
## it falls, and lets its back arm hang limp once it has risen again.

const SKIN := Color(0.56, 0.66, 0.5)
const SKIN_DARK := Color(0.4, 0.5, 0.36)
const SHIRT := Color(0.45, 0.47, 0.58)
const SHIRT_DARK := Color(0.32, 0.33, 0.43)
const TROUSERS := Color(0.33, 0.25, 0.19)
const OUTLINE := Color(0.12, 0.13, 0.1)
const EYE := Color(0.88, 1.0, 0.45)
const MOUTH := Color(0.25, 0.08, 0.08)
const WOUND := Color(0.5, 0.14, 0.12)
const SHADOW := Color(0, 0, 0, 0.28)

const HIP_HEIGHT := 21.0
const LEG := 10.5
const ARM := 10.0
## Arms reach straight ahead while walking; the swing raises the front arm overhead.
const REACH := 1.5
## Forward hunch of the torso, in radians.
const HUNCH := 0.22

## Whole-body transform while falling; parts drawn in their own frame compose with it.
var _base := Transform2D.IDENTITY


func _init() -> void:
	chest_height = 32.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 12.0, SHADOW)
	# Pitching forward onto its face: pivot at the toes, then lie flat.
	var fall := death * death
	_base = Transform2D(fall * 1.5, Vector2(4.0, -7.0) * fall)
	draw_set_transform_matrix(_base)

	var stagger := 1.0 - death
	var bob := -absf(sin(walk_phase)) * 2.4 * stagger
	var lurch := sin(walk_phase) * 0.1 * stagger
	var hip := Vector2(0, -HIP_HEIGHT + bob)
	var swing := sin(walk_phase) * 0.45
	var lean := HUNCH + lurch
	var shoulder := hip + Vector2(0, -17).rotated(lean)

	# Back arm (limp after rising), dragging back leg, then the front leg.
	var back_arm := 0.25 + swing * 0.3 if risen else REACH - 0.15 + sin(walk_phase * 0.5) * 0.12
	_draw_arm(shoulder + Vector2(-1, 0), back_arm, SKIN_DARK, SHIRT_DARK)
	_draw_leg(hip, -0.15 - swing * 0.35, SKIN_DARK)
	_draw_leg(hip, swing, SKIN)

	# Torn shirt over a hunched torso, with a wound showing through.
	var up := Vector2(0, -1).rotated(lean)
	var side := up.orthogonal()
	var neck := hip + up * 18.0
	var torso := PackedVector2Array([
		neck - side * 6.0, neck + side * 6.5, hip + side * 7.5 + Vector2(0, 2),
		hip + side * 4.0 + Vector2(0, 5), hip + side * 1.0 + Vector2(0, 2),
		hip - side * 2.5 + Vector2(0, 5), hip - side * 7.0 + Vector2(0, 2),
	])
	_outlined_polygon(torso, lit(SHIRT))
	draw_line(neck - side * 4.5, hip - side * 5.5, lit(SHIRT_DARK), 2.0)
	draw_circle(hip + up * 9.0 + side * 2.0, 2.4, lit(SKIN_DARK))
	draw_circle(hip + up * 9.0 + side * 2.4, 1.2, WOUND)
	draw_line(hip - side * 7.0 + Vector2(0, -1), hip + side * 7.5 + Vector2(0, -1), lit(TROUSERS), 3.0)

	_draw_head(neck + up * 8.0 + side * 2.5, lean * 0.6)

	# Reaching front arm: the swing lifts it overhead and rakes down.
	var arm := REACH + (weapon_angle - WEAPON_REST) * 0.5 + sin(walk_phase * 0.5 + 1.0) * 0.1 * stagger
	var hand := _draw_arm(shoulder, arm, SKIN, SHIRT)
	if swoosh > 0.0:
		var claw := Color(1, 1, 1, 0.6 * swoosh)
		for i in 3:
			var offset := Vector2(5.0 + i * 3.0, -6.0 + i * 3.0)
			draw_line(hand + offset, hand + offset + Vector2(-5, 10), claw, 2.0)

	draw_set_transform(Vector2.ZERO)
	draw_health_bar(-64.0)


func _draw_head(center: Vector2, tilt: float) -> void:
	draw_set_transform_matrix(_base * Transform2D(tilt, center))
	draw_circle(Vector2.ZERO, 8.6, OUTLINE)
	draw_circle(Vector2.ZERO, 7.5, lit(SKIN))
	draw_circle(Vector2(-2.5, 2.5), 3.0, lit(SKIN_DARK))
	# Patchy hair, a sunken glowing eye, and a slack open jaw.
	for x in [-6.0, -3.5, -1.0]:
		draw_line(Vector2(x, -6.5), Vector2(x - 2.5, -10.0), OUTLINE, 1.6)
	draw_circle(Vector2(3.8, -1.5), 2.6, OUTLINE)
	if death < 0.4:
		draw_circle(Vector2(3.8, -1.5), 1.5, EYE)
	draw_colored_polygon(PackedVector2Array([Vector2(2.5, 3.5), Vector2(7.6, 3.0), Vector2(6.5, 7.5), Vector2(3.0, 6.5)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(3.2, 4.2), Vector2(6.8, 3.8), Vector2(6.0, 6.6), Vector2(3.6, 5.9)]), MOUTH)
	draw_rect(Rect2(4.6, 3.8, 1.4, 1.4), Color(0.9, 0.87, 0.7))
	draw_set_transform_matrix(_base)


## Thigh in torn trousers and a bare shin.
func _draw_leg(hip: Vector2, angle: float, skin: Color) -> void:
	var knee := hip + Vector2(sin(angle), cos(angle)) * LEG
	var foot := knee + Vector2(sin(angle * 0.4), cos(angle * 0.4)) * LEG
	_limb(knee, foot, 3.2, skin)
	_limb(hip, knee, 4.6, TROUSERS)
	draw_circle(foot + Vector2(2.0, -0.5), 3.2, OUTLINE)
	draw_circle(foot + Vector2(2.0, -0.5), 2.3, lit(skin))


## Sleeve and bare forearm; `angle` is measured from straight down toward the front. Returns
## the hand position.
func _draw_arm(shoulder: Vector2, angle: float, skin: Color, sleeve: Color) -> Vector2:
	var elbow := shoulder + Vector2(sin(angle), cos(angle)) * ARM
	var bend := angle + 0.15
	var hand := elbow + Vector2(sin(bend), cos(bend)) * ARM
	_limb(elbow, hand, 3.0, skin)
	_limb(shoulder, elbow, 4.2, sleeve)
	draw_circle(hand, 3.0, OUTLINE)
	draw_circle(hand, 2.2, lit(skin))
	return hand


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
