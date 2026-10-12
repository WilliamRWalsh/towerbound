class_name ManaWisp
extends Node2D
## A blue wisp that drifts up out of a fallen enemy, then arcs into the mana bar. Display only:
## the mana is already granted; `arrived` tells the bar when to show it.

signal arrived

const RISE_TIME := 0.3
const RISE_HEIGHT := 46.0
const FLIGHT_TIME := 0.85
## How far the flight bows upward, in canvas units.
const ARC_HEIGHT := 150.0
const TRAIL_POINTS := 12

const GLOW := Color(0.35, 0.7, 1.0)
const CORE := Color(0.88, 0.97, 1.0)

var _start := Vector2.ZERO
var _target: Callable
var _age := 0.0
var _trail: Array[Vector2] = []


## `target` returns the canvas position to fly to; it's re-read every frame because the bar's
## surface moves as other wisps land.
static func launch(layer: Node, from: Vector2, target: Callable) -> ManaWisp:
	var wisp := ManaWisp.new()
	wisp._start = from
	wisp._target = target
	wisp.position = from
	layer.add_child(wisp)
	return wisp


func _process(delta: float) -> void:
	_age += delta
	var lifted := _start + Vector2(0, -RISE_HEIGHT)
	if _age < RISE_TIME:
		var t := _age / RISE_TIME
		var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
		position = _start.lerp(lifted, ease_out) + Vector2(sin(_age * 22.0) * 4.0 * (1.0 - t), 0)
	else:
		var t := minf((_age - RISE_TIME) / FLIGHT_TIME, 1.0)
		var eased := t * t * (3.0 - 2.0 * t) * 0.4 + t * t * 0.6  # gentle start, quick finish
		var end: Vector2 = _target.call()
		var control := lifted.lerp(end, 0.35) + Vector2(0, -ARC_HEIGHT)
		position = lifted.lerp(control, eased).lerp(control.lerp(end, eased), eased)
		if t >= 1.0:
			arrived.emit()
			queue_free()
			return
	_trail.push_front(position)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	# Trail of fading motes behind the wisp, drawn in local space.
	for i in range(_trail.size() - 1, 0, -1):
		var fade := 1.0 - float(i) / TRAIL_POINTS
		draw_circle(_trail[i] - position, 9.0 * fade, Color(GLOW, 0.4 * fade))
	var flicker := 1.0 + sin(_age * 31.0) * 0.12
	draw_circle(Vector2.ZERO, 24.0 * flicker, Color(GLOW, 0.14))
	draw_circle(Vector2.ZERO, 14.0 * flicker, Color(GLOW, 0.38))
	draw_circle(Vector2.ZERO, 8.0, Color(GLOW.lightened(0.3), 0.9))
	draw_circle(Vector2.ZERO, 4.5, CORE)
