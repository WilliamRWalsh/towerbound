class_name TargetOverlay
extends Node2D
## Area-of-effect preview for spells: a pulsing circle that follows the pointer. Works in map
## pixels as a child of the battlefield. Display only. Fire-colored by default; other spells pass
## their own color. Turns red over a spot the spell can't be cast on.

const FIRE := Color(1.0, 0.55, 0.2)
const INVALID := Color(0.95, 0.2, 0.15)

var _radius := 0.0
var _color := FIRE
var _valid := true
var _showing := false
var _time := 0.0


func show_circle(radius: float, color := FIRE) -> void:
	_radius = radius
	_color = color
	_showing = true
	visible = false


func move_circle(global_pos: Vector2, over_field: bool, valid := true) -> void:
	if not _showing:
		return
	position = get_parent().to_local(global_pos)
	visible = over_field
	_valid = valid
	queue_redraw()


func hide_circle() -> void:
	_showing = false
	visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(_time * 6.0)
	var color := _color if _valid else INVALID
	var light := color.lightened(0.3)
	draw_circle(Vector2.ZERO, _radius, Color(color.darkened(0.1), 0.2 * pulse))
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 72, Color(color, 0.9 * pulse), 4.0)
	draw_arc(Vector2.ZERO, _radius * 0.55, 0, TAU, 48, Color(light, 0.35 * pulse), 2.0)
	draw_circle(Vector2.ZERO, 6.0, Color(light, 0.9))
