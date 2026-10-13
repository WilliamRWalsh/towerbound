class_name ChargePips
extends Node2D
## A tower's ammo display: a row of pips under its base, amber gems for charges left and dark
## sockets for spent ones, with the charge spent this wave popping as it empties. While the tower
## sits out a wave reloading, a turning ring with an arrowhead sits over it. Display only; it
## reads the tower's TowerAmmo.

## Where the pips sit, relative to the cell center, and the gap between them.
const PIPS_POS := Vector2(0, 50)
const PIP_SPACING := 32.0
const POP_TIME := 0.35
const AMMO := Color(1.0, 0.72, 0.25)
const AMMO_DARK := Color(0.14, 0.1, 0.07)
const GOLD_DARK := Color(0.5, 0.33, 0.08)

var _ammo: TowerAmmo
## Seconds since a charge was spent, or -1.
var _pop := -1.0
var _spin := 0.0


func _init(ammo: TowerAmmo) -> void:
	_ammo = ammo
	z_index = 1
	# Animate before the tower fires each frame, as when the tower drew its own pips.
	process_priority = -1
	ammo.spent.connect(func() -> void:
		_pop = 0.0
		queue_redraw())
	ammo.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if not (_ammo.reloading or _pop >= 0.0):
		return
	_spin += delta
	if _pop >= 0.0:
		_pop += delta
		if _pop >= POP_TIME:
			_pop = -1.0
	queue_redraw()


func _draw() -> void:
	var n := _ammo.capacity
	var start := PIPS_POS - Vector2(PIP_SPACING * (n - 1) * 0.5, 0)
	var back := Rect2(start - Vector2(22, 15), Vector2(PIP_SPACING * (n - 1) + 44, 30))
	draw_style_box(_pip_backing(), back)
	for i in n:
		var c := start + Vector2(PIP_SPACING * i, 0)
		var full := not _ammo.reloading and i < _ammo.left
		if full:
			_draw_gem(c, 11.0, AMMO)
		else:
			draw_circle(c, 9.0, AMMO_DARK)
			draw_arc(c, 9.0, 0, TAU, 20, Color(AMMO, 0.4), 2.0)
		if _pop >= 0.0 and i == _ammo.left:
			var t := _pop / POP_TIME
			draw_circle(c, 11.0 * (1.0 - t) + 2.0, Color(1.0, 0.95, 0.7, 1.0 - t))
			draw_arc(c, 12.0 + 16.0 * t, 0, TAU, 20, Color(AMMO, 1.0 - t), 3.0)
	if _ammo.reloading:
		# A turning reload ring with an arrowhead, centered on the tower body.
		var center := Vector2(0, -50)
		var radius := 34.0
		var a := _spin * 3.0
		draw_circle(center, radius + 8.0, Color(0.05, 0.04, 0.03, 0.55))
		draw_arc(center, radius, a, a + PI * 1.5, 32, AMMO, 6.0)
		var tip := center + Vector2.from_angle(a + PI * 1.5) * radius
		var fwd := Vector2.from_angle(a + PI * 2.0)
		var side := Vector2.from_angle(a + PI * 1.5)
		draw_colored_polygon(PackedVector2Array([tip + fwd * 12.0, tip + side * 10.0 - fwd * 2.0, tip - side * 10.0 - fwd * 2.0]), AMMO)


func _draw_gem(c: Vector2, r: float, color: Color) -> void:
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	var rim := PackedVector2Array([c + Vector2(0, -r - 2.5), c + Vector2(r + 2.5, 0), c + Vector2(0, r + 2.5), c + Vector2(-r - 2.5, 0)])
	draw_colored_polygon(rim, GOLD_DARK)
	draw_colored_polygon(diamond, color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.5), c, c + Vector2(-r * 0.5, -r * 0.5)]), Color(1.0, 0.95, 0.75))


static var _backing: StyleBoxFlat


static func _pip_backing() -> StyleBoxFlat:
	if _backing == null:
		_backing = StyleBoxFlat.new()
		_backing.bg_color = Color(0.05, 0.04, 0.03, 0.7)
		_backing.border_color = Color(GOLD_DARK, 0.9)
		_backing.set_border_width_all(2)
		_backing.set_corner_radius_all(11)
	return _backing
