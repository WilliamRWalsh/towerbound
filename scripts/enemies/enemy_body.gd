class_name EnemyBody
extends Node2D
## Base for an enemy's procedural art, drawn facing right with the origin between the feet (the
## Enemy flips `scale.x` to face left). Display only: the Enemy node drives these values.

## Weapon-arm angles, measured from straight down toward the front.
const WEAPON_REST := 0.5
const SWING_RAISED := 3.44
const SWING_STRUCK := 0.5
## Pale blue a chilled enemy's colors shift toward.
const FROST_TINT := Color(0.62, 0.85, 1.0)

## Height above the feet that arrows aim for.
@export var chest_height := 36.0

## Walk cycle phase in radians.
var walk_phase := 0.0:
	set(value):
		walk_phase = value
		queue_redraw()
var weapon_angle := WEAPON_REST:
	set(value):
		weapon_angle = value
		queue_redraw()
## 0–1 strength of the swing trail.
var swoosh := 0.0:
	set(value):
		swoosh = value
		queue_redraw()
## 0 standing, 1 fully fallen.
var death := 0.0:
	set(value):
		death = value
		queue_redraw()
## 0–1 hit flash, toward `flash_color`.
var flash := 0.0:
	set(value):
		flash = value
		queue_redraw()
## Color the hit flash fades from: white normally, gold on a weakness, grey on a resistance.
var flash_color := Color.WHITE
## 0–1 icy blue tint while chilled.
var frost := 0.0:
	set(value):
		frost = value
		queue_redraw()
## True once the enemy has got back up after being killed (zombies only).
var risen := false:
	set(value):
		risen = value
		queue_redraw()
## Fraction of health left; the bar shows only once the enemy has been hit.
var health_ratio := 1.0:
	set(value):
		health_ratio = value
		queue_redraw()


## Thin health bar centered above the head, at `top` (negative, above the feet).
func draw_health_bar(top: float, width := 24.0) -> void:
	if health_ratio >= 1.0 or death > 0.0:
		return
	var bar := Rect2(-width * 0.5, top, width, 4)
	draw_rect(bar.grow(1.5), Color(0.08, 0.05, 0.05, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * health_ratio, bar.size.y)), Color(0.9, 0.22, 0.16))


## Arc trailing a weapon swing around `pivot`.
func draw_swoosh(pivot: Vector2, reach: float) -> void:
	if swoosh <= 0.0:
		return
	var start := Vector2(sin(SWING_RAISED), cos(SWING_RAISED)).angle()
	var end := Vector2(sin(weapon_angle), cos(weapon_angle)).angle()
	draw_arc(pivot, reach, start, end, 16, Color(1, 1, 1, 0.55 * swoosh), 5.0)
	draw_arc(pivot, reach - 6.0, start, end, 16, Color(1, 1, 1, 0.25 * swoosh), 3.0)


func lit(color: Color) -> Color:
	if frost > 0.0:
		# Keep light and dark parts apart: shift toward the tint at the color's own brightness.
		color = color.lerp(Color(FROST_TINT * (0.4 + color.get_luminance()), color.a), 0.6 * frost)
	return color.lerp(Color(flash_color, color.a), flash)
