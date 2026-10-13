class_name TargetOverlay
extends Node2D
## Area-of-effect preview for spells: a pulsing circle that follows the pointer. Works in map
## pixels as a child of the battlefield. Display only.

var _radius := 0.0
var _showing := false
var _time := 0.0


func show_circle(radius: float) -> void:
	_radius = radius
	_showing = true
	visible = false


func move_circle(global_pos: Vector2, over_field: bool) -> void:
	if not _showing:
		return
	position = get_parent().to_local(global_pos)
	visible = over_field
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
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.45, 0.15, 0.2 * pulse))
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 72, Color(1.0, 0.6, 0.25, 0.9 * pulse), 4.0)
	draw_arc(Vector2.ZERO, _radius * 0.55, 0, TAU, 48, Color(1.0, 0.75, 0.4, 0.35 * pulse), 2.0)
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.8, 0.45, 0.9))
