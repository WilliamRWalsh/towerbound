class_name Castle
extends Node2D
## The defended castle: owns its health, which is authoritative for the battle. Enemies at the gate
## call `take_damage`; the Repair card calls `heal`. Also draws feedback over the painted gate in
## map pixels: a red flash when struck, a green glow while a heal is being aimed, and rising
## sparkles when healed.

signal health_changed(health: float, max_health: int)
signal destroyed

## Area over the painted castle walls and gate, in map pixels; glows while a heal is aimed.
@export var wall_rect := Rect2(130, 1530, 680, 240)
## The gate the enemies strike, in map pixels.
@export var gate_center := Vector2(471, 1690)

const SPARKLE_TIME := 1.1

var max_health := 20
## Fractional, since enemy strikes deal fractions of a point.
var health := 20.0

## True while a Repair card is selected, so the castle glows as a target.
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

var _hit_flash := 0.0
## Each sparkle: [start position, age, drift].
var _sparkles: Array = []
var _glow_time := 0.0


func reset(starting_health: int) -> void:
	max_health = starting_health
	health = float(starting_health)
	_sparkles.clear()
	highlighted = false
	health_changed.emit(health, max_health)


func is_destroyed() -> bool:
	return health <= 0.001


## Still standing, so enemies at the gate keep striking it (barricades answer the same question).
func is_standing() -> bool:
	return not is_destroyed()


func is_full() -> bool:
	return health >= max_health


func take_damage(amount: float) -> void:
	if is_destroyed() or amount <= 0.0:
		return
	health = snappedf(maxf(0.0, health - amount), 0.01)
	_hit_flash = 1.0
	health_changed.emit(health, max_health)
	if is_destroyed():
		destroyed.emit()


## Restores health up to the maximum. Returns false (changing nothing) when full or fallen.
func heal(amount: int) -> bool:
	if is_destroyed() or is_full() or amount <= 0:
		return false
	health = minf(max_health, health + amount)
	for i in 26:
		var start := Vector2(randf_range(wall_rect.position.x + 80, wall_rect.end.x - 80),
				randf_range(wall_rect.position.y + 60, wall_rect.end.y - 40))
		_sparkles.append([start, randf_range(-0.35, 0.0), Vector2(randf_range(-12, 12), randf_range(-110, -70))])
	health_changed.emit(health, max_health)
	return true



func _process(delta: float) -> void:
	_glow_time += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	for sparkle in _sparkles:
		sparkle[1] += delta
	_sparkles = _sparkles.filter(func(sparkle: Array) -> bool: return sparkle[1] < SPARKLE_TIME)
	if highlighted or _hit_flash > 0.0 or not _sparkles.is_empty():
		queue_redraw()


func _draw() -> void:
	if _hit_flash > 0.0:
		draw_set_transform(gate_center, 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 110.0, Color(1.0, 0.2, 0.1, 0.28 * _hit_flash))
		draw_set_transform(Vector2.ZERO)
	if highlighted:
		var pulse := 0.75 + 0.25 * sin(_glow_time * 5.0)
		draw_rect(wall_rect, Color(0.45, 1.0, 0.5, 0.3 * pulse))
		draw_rect(wall_rect.grow(4), Color(0.3, 0.9, 0.35, 0.5 * pulse), false, 12.0)
		draw_rect(wall_rect, Color(0.75, 1.0, 0.7, pulse), false, 5.0)
	for sparkle in _sparkles:
		var age: float = sparkle[1]
		if age < 0.0:
			continue
		var t := age / SPARKLE_TIME
		var pos: Vector2 = sparkle[0] + sparkle[2] * age
		var alpha := sin(t * PI)
		draw_circle(pos, 9.0 * (1.0 - t * 0.4), Color(0.4, 1.0, 0.45, 0.35 * alpha))
		_draw_cross(pos, 7.0 * (1.0 - t * 0.3), Color(0.85, 1.0, 0.75, alpha))


## A little four-point twinkle.
func _draw_cross(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), color, 2.5)
	draw_line(center - Vector2(0, arm), center + Vector2(0, arm), color, 2.5)
