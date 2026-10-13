class_name BurningGround
extends Node2D
## Scorched, burning ground a Fireball leaves behind. Every tick it burns each living enemy inside
## its radius, including ones that walk in later; kills pay out through the enemy's own `died`
## signal. Every tick it also ignites any Oil Slick it touches, so fire spreads along oil. Sits on
## the ground layer, under the enemies. Works in its parent's (map-pixel) coordinates.
## TargetPlanner reads its upcoming ticks to predict burn kills.

const GROUP := "burning_ground"
const TICK := 0.5
const FADE_TIME := 0.6
const FLAME := Color(1.0, 0.55, 0.12)
const EMBER := Color(0.85, 0.2, 0.05)
const CORE := Color(1.0, 0.9, 0.55)

var _radius := 90.0
var _damage_per_second := 1.0
var _duration := 4.0
var _age := 0.0
var _next_tick := TICK
## Each flame: [position in the unsquashed circle, phase offset, size].
var _flames: Array = []


## Lights a patch at a canvas position. `radius` is in map pixels.
static func ignite(layer: Node2D, target_global: Vector2, radius: float, damage_per_second: float, duration: float) -> BurningGround:
	var ground := BurningGround.new()
	ground._radius = radius
	ground._damage_per_second = damage_per_second
	ground._duration = duration
	for i in 14:
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius * 0.8
		ground._flames.append([spot, randf() * TAU, randf_range(0.7, 1.2)])
	ground.add_to_group(GROUP)
	layer.add_child(ground)
	ground.position = layer.to_local(target_global)
	return ground


func _process(delta: float) -> void:
	_age += delta
	while _age >= _next_tick and _next_tick <= _duration:
		_burn(_damage_per_second * TICK)
		_next_tick += TICK
	if _age >= _duration:
		queue_free()
	queue_redraw()


## Seconds from now of each burn tick still to come within `horizon`.
func upcoming_ticks(horizon: float) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var tick := _next_tick
	while tick <= _duration and tick - _age <= horizon:
		times.append(maxf(0.0, tick - _age))
		tick += TICK
	return times


## Damage one tick deals before resistances.
func tick_damage() -> float:
	return _damage_per_second * TICK


## Whether a canvas position is inside the patch, by the same test `_burn` uses.
func contains(point_global: Vector2) -> bool:
	var parent := get_parent() as Node2D
	return parent.to_local(point_global).distance_to(position) <= _radius


## Enemies leave the group when the battle ends, so a patch can't hurt anything after a result.
func _burn(amount: float) -> void:
	var hit: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if enemy.is_alive() and contains(enemy.global_position):
			hit.append(enemy)
	for enemy in hit:
		enemy.take_damage(amount, Damage.Type.FIRE)
	OilSlick.ignite_within(get_tree(), global_position, _radius * global_scale.x)


func _draw() -> void:
	var fade := clampf((_duration - _age) / FADE_TIME, 0.0, 1.0)
	var grow := clampf(_age / 0.15, 0.0, 1.0)
	# Same circle the Fireball's aiming preview showed, so what burns is what was aimed at.
	draw_circle(Vector2.ZERO, _radius * grow, Color(0.08, 0.04, 0.02, 0.45 * fade))
	draw_circle(Vector2.ZERO, _radius * 0.82 * grow, Color(EMBER, 0.28 * fade))
	draw_arc(Vector2.ZERO, _radius * grow, 0, TAU, 48, Color(FLAME, 0.55 * fade), 3.0)
	# Flickering flame tongues, each a teardrop that rises and shrinks on its own cycle.
	for flame in _flames:
		var base: Vector2 = flame[0]
		var cycle := fmod(_age * 1.6 + flame[1], 1.0)
		var size: float = flame[2] * (1.0 - cycle * 0.6) * fade * grow
		var lift := Vector2(sin(_age * 7.0 + flame[1]) * 2.0, -cycle * 24.0)
		draw_circle(base + lift, 16.0 * size, Color(EMBER, 0.55))
		draw_circle(base + lift + Vector2(0, -4), 11.0 * size, Color(FLAME, 0.85))
		draw_circle(base + lift + Vector2(0, -7), 5.0 * size, Color(CORE, 0.9))
