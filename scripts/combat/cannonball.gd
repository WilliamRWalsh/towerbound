class_name Cannonball
extends Projectile
## A cannonball lobbed at an enemy: follows its target, arcs high in between, and kicks up a puff
## of dust where it lands, whether or not its target is still there.

const RADIUS := 7.5
## Peak of the arc as a fraction of the flight distance, capped.
const ARC_SHARE := 0.4
const ARC_MAX := 90.0
const IMPACT_TIME := 0.3

## Fraction of the flight completed.
var _progress := 0.0
var _arc := 0.0
## Seconds since landing, or -1 in flight.
var _impact := -1.0


func _launched() -> void:
	_arc = minf(ARC_MAX, _from.distance_to(_aim) * ARC_SHARE)


func _process(delta: float) -> void:
	if _impact >= 0.0:
		_impact += delta
		if _impact >= IMPACT_TIME:
			queue_free()
		queue_redraw()
		return
	super(delta)


func _advance(delta: float) -> bool:
	var flight := maxf(1.0, _from.distance_to(_aim))
	_progress = minf(1.0, _progress + _speed * delta / flight)
	position = _from.lerp(_aim, _progress) + Vector2(0, -_arc * 4.0 * _progress * (1.0 - _progress))
	queue_redraw()
	return _progress >= 1.0


func _arrive(_struck: bool) -> void:
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
