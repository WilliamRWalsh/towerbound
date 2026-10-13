class_name BurningGround
extends AreaEffect
## Scorched, burning ground: what a Fireball leaves behind, and what an Oil Slick becomes when it
## catches. Every tick it burns each living enemy inside, including ones that walk in later; kills
## pay out through the enemy's own `died` signal. Every tick it also touches the ground with fire,
## so it ignites any oil it reaches and fire spreads along oil. TargetPlanner reads its upcoming
## ticks to predict burn kills.

const TICK := 0.5
const FADE_TIME := 0.6
const FLAME := Color(1.0, 0.55, 0.12)
const EMBER := Color(0.85, 0.2, 0.05)
const CORE := Color(1.0, 0.9, 0.55)

var _damage_per_second := 1.0
## Each flame: [position in the unsquashed circle, phase offset, size].
var _flames: Array = []


## Lights a patch at a canvas position. `burn_radius` is in map pixels.
static func ignite(battle_world: Battlefield, at_global: Vector2, burn_radius: float, burn: BurnSpec) -> BurningGround:
	var ground := BurningGround.new()
	ground.radius = burn_radius
	ground.duration = burn.duration
	ground.tick_interval = TICK
	ground.next_tick = TICK
	ground._damage_per_second = burn.damage_per_second
	for i in 14:
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * burn_radius * 0.8
		ground._flames.append([spot, randf() * TAU, randf_range(0.7, 1.2)])
	ground.place(battle_world, at_global)
	return ground


## Damage one tick deals before resistances.
func tick_damage() -> float:
	return _damage_per_second * TICK


## Seconds from now of each burn tick still to come within `horizon`.
func upcoming_ticks(horizon: float) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var tick := next_tick
	while tick <= duration and tick - age <= horizon:
		times.append(maxf(0.0, tick - age))
		tick += TICK
	return times


## Burn ticks still to come that will find `enemy` inside, assuming it keeps walking at its
## current speed (or stays put while striking).
func predicted_damage_to(enemy: Enemy, horizon: float) -> float:
	var total := 0.0
	var per_tick := enemy.damage_after_resistance(tick_damage(), Damage.Type.FIRE)
	for t in upcoming_ticks(horizon):
		if contains(TargetPlanner.future_position(enemy, t)):
			total += per_tick
	return total


## Enemies are halted when the battle ends, so a patch can't hurt anything after a result.
func _tick() -> void:
	var hit := Hit.new(tick_damage(), Damage.Type.FIRE)
	for enemy in enemies_inside():
		enemy.take_hit(hit)
	AreaEffect.touch_all(world, Damage.Type.FIRE, position, radius)


func _draw() -> void:
	var fade_out := fade(FADE_TIME)
	var grow := clampf(age / 0.15, 0.0, 1.0)
	# Same circle the Fireball's aiming preview showed, so what burns is what was aimed at.
	draw_circle(Vector2.ZERO, radius * grow, Color(0.08, 0.04, 0.02, 0.45 * fade_out))
	draw_circle(Vector2.ZERO, radius * 0.82 * grow, Color(EMBER, 0.28 * fade_out))
	draw_arc(Vector2.ZERO, radius * grow, 0, TAU, 48, Color(FLAME, 0.55 * fade_out), 3.0)
	# Flickering flame tongues, each a teardrop that rises and shrinks on its own cycle.
	for flame in _flames:
		var base: Vector2 = flame[0]
		var cycle := fmod(age * 1.6 + flame[1], 1.0)
		var size: float = flame[2] * (1.0 - cycle * 0.6) * fade_out * grow
		var lift := Vector2(sin(age * 7.0 + flame[1]) * 2.0, -cycle * 24.0)
		draw_circle(base + lift, 16.0 * size, Color(EMBER, 0.55))
		draw_circle(base + lift + Vector2(0, -4), 11.0 * size, Color(FLAME, 0.85))
		draw_circle(base + lift + Vector2(0, -7), 5.0 * size, Color(CORE, 0.9))
