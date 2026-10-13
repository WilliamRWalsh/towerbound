class_name Cannonball
extends Node2D
## A cannonball lobbed from a tower at an enemy. Follows the target and arcs high in between,
## deals damage once on landing, and kicks up a puff of dust. If the target dies or leaves play
## mid-flight, the ball lands where it was aimed and does nothing. Works in its parent's
## (map-pixel) coordinates.

const RADIUS := 7.5
## Peak of the arc as a fraction of the flight distance, capped.
const ARC_SHARE := 0.4
const ARC_MAX := 90.0
const IMPACT_TIME := 0.3

var _target: Enemy
var _damage := 1.0
var _speed := 0.0
var _from := Vector2.ZERO
var _aim := Vector2.ZERO
## Fraction of the flight completed.
var _progress := 0.0
var _arc := 0.0
var _impact := -1.0


## Fires a cannonball from a canvas position. `speed` is in reference units per second.
static func launch(layer: Node2D, from_global: Vector2, target: Enemy, damage: float, speed: float) -> Cannonball:
	var ball := Cannonball.new()
	ball._target = target
	ball._damage = damage
	ball._speed = speed * BuildGrid.MAP_PIXELS_PER_UNIT
	layer.add_child(ball)
	ball._from = layer.to_local(from_global)
	ball._aim = layer.to_local(target.aim_point())
	ball._arc = minf(ARC_MAX, ball._from.distance_to(ball._aim) * ARC_SHARE)
	ball.position = ball._from
	return ball


func _process(delta: float) -> void:
	if _impact >= 0.0:
		_impact += delta
		if _impact >= IMPACT_TIME:
			queue_free()
		queue_redraw()
		return
	var tracking := is_instance_valid(_target) and _target.is_alive()
	if tracking:
		_aim = get_parent().to_local(_target.aim_point())
	var flight := maxf(1.0, _from.distance_to(_aim))
	_progress = minf(1.0, _progress + _speed * delta / flight)
	position = _from.lerp(_aim, _progress) + Vector2(0, -_arc * 4.0 * _progress * (1.0 - _progress))
	if _progress >= 1.0:
		if tracking:
			_target.take_damage(_damage)
		_impact = 0.0
	queue_redraw()


func _draw() -> void:
	if _impact >= 0.0:
		# Dust burst: a ring of puffs spreading and fading.
		var t := _impact / IMPACT_TIME
		for i in 7:
			var dir := Vector2.from_angle(TAU * i / 7.0 + 0.4)
			draw_circle(dir * (6.0 + 22.0 * t) * Vector2(1.0, 0.6), 7.0 * (1.0 - t * 0.5),
					Color(0.72, 0.62, 0.48, 0.7 * (1.0 - t)))
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - t), Color(1.0, 0.8, 0.45, 0.6 * (1.0 - t)))
		return
	draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(0.06, 0.06, 0.07))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.24, 0.25, 0.28))
	draw_circle(Vector2(-2.5, -2.5), 2.6, Color(0.62, 0.64, 0.7))
