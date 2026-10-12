class_name SkeletonBody
extends EnemyBody
## Procedural skeleton art: bones, a glowing-eyed skull, and a rusty sword. Collapses into a
## bone pile when it dies.

const BONE := Color(0.93, 0.9, 0.8)
const OUTLINE := Color(0.17, 0.14, 0.12)
const SOCKET := Color(0.1, 0.07, 0.07)
const EYE_GLOW := Color(1.0, 0.4, 0.2)
const BLADE := Color(0.68, 0.69, 0.7)
const RUST := Color(0.55, 0.35, 0.22)
const HILT := Color(0.42, 0.26, 0.13)
const SHADOW := Color(0, 0, 0, 0.28)

const HIP_HEIGHT := 24.0
const LIMB := 12.0
const ARM := 10.5
const BLADE_LENGTH := 23.0
## Blade angle relative to the forearm: held level while walking, chopping in line with the arm
## at the end of a swing.
const GRIP_REST := -PI / 2 + 0.35
const GRIP_CHOP := -0.25

# Where each bone comes to rest when the skeleton collapses.
const PILE_LIMBS: Array[PackedVector2Array] = [
	[Vector2(-15, -3), Vector2(-4, -6)],
	[Vector2(-2, -2), Vector2(9, -4)],
	[Vector2(4, -7), Vector2(15, -3)],
	[Vector2(-12, -8), Vector2(-3, -1)],
	[Vector2(-8, -2), Vector2(1, -9)],
	[Vector2(6, -1), Vector2(14, -8)],
	[Vector2(-17, -7), Vector2(-9, -11)],
	[Vector2(2, -12), Vector2(10, -11)],
]
const PILE_RIBS := Vector2(-3, -8)
const PILE_SKULL := Vector2(13, -8)
const PILE_SWORD := [Vector2(-18, 1), Vector2(10, 3)]


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 13.0 - 2.0 * death, SHADOW)
	draw_set_transform(Vector2.ZERO)

	var bob := -absf(sin(walk_phase)) * 2.0 * (1.0 - death)
	var hip := Vector2(0, -HIP_HEIGHT + bob)
	var shoulder := hip + Vector2(1, -19)
	var swing := sin(walk_phase) * 0.45

	# Standing limbs: back leg, back arm, front leg, then the sword arm in front.
	var limbs: Array[PackedVector2Array] = []
	limbs.append_array(_leg(hip, -swing))
	limbs.append_array(_arm(shoulder, -swing * 0.9))
	limbs.append_array(_leg(hip, swing))
	var sword_arm := _arm(shoulder, weapon_angle)
	var t := _fall(death)
	for i in limbs.size():
		var pile := PILE_LIMBS[i]
		_bone(limbs[i][0].lerp(pile[0], t), limbs[i][1].lerp(pile[1], t), 3.6)

	_draw_pelvis(hip.lerp(Vector2(1, -4), t))
	_draw_ribs(hip.lerp(PILE_RIBS, t) + Vector2(1, -10) * (1.0 - t), t * 1.45)

	# The skull drops last and bounces once before rolling to rest.
	var skull_t := _bounce(clampf(death * 1.15 - 0.15, 0.0, 1.0))
	_draw_skull(shoulder.lerp(PILE_SKULL, skull_t) + Vector2(1, -9) * (1.0 - skull_t), skull_t * 1.9)

	var hand := sword_arm[1][1]
	var blade_dir := (hand - sword_arm[1][0]).normalized().rotated(lerpf(GRIP_REST, GRIP_CHOP, swoosh))
	draw_swoosh(shoulder, ARM * 2.0 + BLADE_LENGTH * 0.8)
	_draw_sword(hand.lerp(PILE_SWORD[0], t), (hand + blade_dir * BLADE_LENGTH).lerp(PILE_SWORD[1], t))
	for i in sword_arm.size():
		var pile := PILE_LIMBS[limbs.size() + i]
		_bone(sword_arm[i][0].lerp(pile[0], t), sword_arm[i][1].lerp(pile[1], t), 3.6)

	draw_health_bar(-72.0)


## Thigh and shin of a leg swinging `angle` radians from vertical.
func _leg(hip: Vector2, angle: float) -> Array[PackedVector2Array]:
	var knee := hip + Vector2(sin(angle), cos(angle)) * LIMB
	var foot := knee + Vector2(sin(angle * 0.4), cos(angle * 0.4)) * LIMB
	return [PackedVector2Array([hip, knee]), PackedVector2Array([knee, foot])]


## Upper arm and forearm; `angle` is measured from straight down toward the front.
func _arm(shoulder: Vector2, angle: float) -> Array[PackedVector2Array]:
	var elbow := shoulder + Vector2(sin(angle), cos(angle)) * ARM
	var bend := angle + 0.35
	var hand := elbow + Vector2(sin(bend), cos(bend)) * ARM
	return [PackedVector2Array([shoulder, elbow]), PackedVector2Array([elbow, hand])]


func _bone(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, OUTLINE, width + 2.4)
	draw_circle(a, width * 0.5 + 1.2, OUTLINE)
	draw_circle(b, width * 0.5 + 1.2, OUTLINE)
	draw_line(a, b, lit(BONE), width)
	draw_circle(a, width * 0.62, lit(BONE))
	draw_circle(b, width * 0.62, lit(BONE))


func _draw_pelvis(center: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 6.2, OUTLINE)
	draw_circle(Vector2.ZERO, 5.0, lit(BONE))
	draw_set_transform(Vector2.ZERO)


func _draw_ribs(center: Vector2, angle: float) -> void:
	draw_set_transform(center, angle)
	_bone(Vector2(-1, 10), Vector2(-1, -10), 3.0)
	for i in 3:
		var y := -6.0 + i * 5.0
		var radius := 7.5 - i * 0.8
		draw_arc(Vector2(-1, y), radius, -1.5, 1.5, 10, OUTLINE, 4.6)
		draw_arc(Vector2(-1, y), radius, -1.5, 1.5, 10, lit(BONE), 2.4)
	draw_set_transform(Vector2.ZERO)


func _draw_skull(center: Vector2, angle: float) -> void:
	draw_set_transform(center, angle)
	draw_rect(Rect2(-1.5, 4.0, 9.0, 5.0), OUTLINE)
	draw_rect(Rect2(-0.5, 5.0, 7.0, 3.0), lit(BONE))
	draw_circle(Vector2.ZERO, 9.4, OUTLINE)
	draw_circle(Vector2.ZERO, 8.2, lit(BONE))
	draw_circle(Vector2(4.0, -0.5), 2.7, SOCKET)
	draw_circle(Vector2(-1.2, -0.5), 2.1, SOCKET)
	draw_colored_polygon(PackedVector2Array([Vector2(6.6, 2.0), Vector2(5.2, 4.2), Vector2(7.6, 4.0)]), SOCKET)
	if death < 0.5:
		draw_circle(Vector2(4.3, -0.4), 1.0, EYE_GLOW)
		draw_circle(Vector2(-1.0, -0.4), 0.8, EYE_GLOW)
	for x in [1.0, 3.0, 5.0]:
		draw_line(Vector2(x, 5.2), Vector2(x, 7.8), OUTLINE, 0.8)
	draw_set_transform(Vector2.ZERO)


func _draw_sword(hilt: Vector2, tip: Vector2) -> void:
	var dir := (tip - hilt).normalized()
	var guard := dir.orthogonal() * 5.0
	var blade_start := hilt + dir * 2.0
	draw_line(hilt - dir * 5.0, blade_start, OUTLINE, 4.5)
	draw_line(hilt - dir * 4.0, blade_start, HILT, 2.5)
	draw_line(blade_start, tip, OUTLINE, 5.4)
	draw_line(blade_start, tip, lit(BLADE), 3.4)
	draw_line(blade_start + dir * 6.0, blade_start + dir * 10.0, RUST, 3.0)
	draw_line(blade_start - guard, blade_start + guard, OUTLINE, 4.0)
	draw_line(blade_start - guard * 0.8, blade_start + guard * 0.8, HILT, 2.2)


## Falling: slow start, fast finish.
static func _fall(t: float) -> float:
	return t * t


static func _bounce(t: float) -> float:
	if t < 0.7:
		var f := t / 0.7
		return f * f
	var b := (t - 0.7) / 0.3
	return 1.0 - 0.12 * sin(b * PI)
