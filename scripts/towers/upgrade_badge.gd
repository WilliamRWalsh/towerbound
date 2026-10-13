class_name UpgradeBadge
extends Node2D
## A ring of light that bursts from a tower each time it is upgraded, and once it has an upgrade
## that shows a badge (Rate of Fire), a gold shield with two chevrons on its side. Display only.

## Where the shield sits, relative to the cell center.
const BADGE_POS := Vector2(40, 8)
const BURST_TIME := 0.6
const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_DARK := Color(0.5, 0.33, 0.08)

## Shows the chevron shield.
var shown := false:
	set(value):
		shown = value
		queue_redraw()
## Seconds since the last upgrade, or -1.
var _burst := -1.0


func _init() -> void:
	z_index = 1
	process_priority = -1


func burst() -> void:
	_burst = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _burst < 0.0:
		return
	_burst += delta
	if _burst >= BURST_TIME:
		_burst = -1.0
	queue_redraw()


func _draw() -> void:
	if _burst >= 0.0:
		var t := _burst / BURST_TIME
		draw_arc(Vector2(0, -50), 40.0 + 70.0 * t, 0, TAU, 48, Color(GOLD, 1.0 - t), 6.0 * (1.0 - t) + 1.0)
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0)
			draw_circle(Vector2(0, -50) + dir * (30.0 + 90.0 * t), 5.0 * (1.0 - t), Color(1.0, 0.95, 0.6, 1.0 - t))
	if not shown:
		return
	var c := BADGE_POS
	var shield := PackedVector2Array([c + Vector2(-14, -16), c + Vector2(14, -16), c + Vector2(14, 2), c + Vector2(0, 16), c + Vector2(-14, 2)])
	var rim := PackedVector2Array([c + Vector2(-17, -19), c + Vector2(17, -19), c + Vector2(17, 3), c + Vector2(0, 20), c + Vector2(-17, 3)])
	draw_colored_polygon(rim, GOLD_DARK)
	draw_colored_polygon(shield, GOLD)
	for dy in [-4.0, 5.0]:
		draw_polyline(PackedVector2Array([c + Vector2(-8, dy + 4), c + Vector2(0, dy - 3), c + Vector2(8, dy + 4)]), GOLD_DARK, 3.5)
