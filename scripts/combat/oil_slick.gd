class_name OilSlick
extends Node2D
## A pool of lamp oil spilled on the road. Enemies wading through it are slowed. Any fire that
## touches it (a Fireball blast or burning ground) ignites it into a long, hot BurningGround patch
## and uses it up; that patch can ignite the next slick in turn. Dries up after `duration`. Sits on
## the ground layer, under the enemies. Works in its parent's (map-pixel) coordinates.

## How often enemies inside are slowed; each slow outlasts the tick so it never flickers off.
const TICK := 0.2
const FADE_TIME := 1.0
## Share of the slick's radius that has to overlap a fire to catch.
const CATCH_SHARE := 0.6

var _world: Battlefield
## True once it has ignited or dried up; it can't catch again.
var _spent := false
var _radius := 60.0
var _slow := 0.6
var _duration := 25.0
var _burn_dps := 2.5
var _burn_duration := 7.0
var _age := 0.0
var _next_tick := 0.0
## Blobs making up the puddle's outline: [offset, radius].
var _blobs: Array = []


## Spills a slick at a canvas position. `radius` is in map pixels; `slow` multiplies the speed of
## enemies inside.
static func spill(world: Battlefield, target_global: Vector2, radius: float, slow: float, duration: float,
		burn_dps: float, burn_duration: float) -> OilSlick:
	var slick := OilSlick.new()
	var layer := world.ground
	slick._world = world
	slick._radius = radius
	slick._slow = slow
	slick._duration = duration
	slick._burn_dps = burn_dps
	slick._burn_duration = burn_duration
	for i in 7:
		var spot := Vector2.from_angle(TAU * i / 7.0 + randf_range(-0.3, 0.3)) * radius * randf_range(0.3, 0.5)
		slick._blobs.append([spot, radius * randf_range(0.5, 0.62)])
	layer.add_child(slick)
	slick.position = layer.to_local(target_global)
	return slick


## Ignites every slick a fire of `radius` at `center` reaches (map pixels).
static func ignite_within(world: Battlefield, center: Vector2, radius: float) -> void:
	for slick in world.ground.get_children():
		if slick is OilSlick and not slick._spent:
			if slick.position.distance_to(center) <= radius + slick._radius * CATCH_SHARE:
				slick.ignite()


## Bursts into flame, leaving a burning patch the size of the slick. Only the first call counts.
func ignite() -> void:
	if _spent:
		return
	_spent = true
	BurningGround.ignite(_world, global_position, _radius, _burn_dps, _burn_duration)
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		_spent = true
		queue_free()
		return
	if _age >= _next_tick:
		_next_tick += TICK
		for enemy in _world.enemies.in_radius(position, _radius):
			enemy.apply_slow(_slow, TICK * 2.0)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((_duration - _age) / FADE_TIME, 0.0, 1.0)
	var grow := clampf(_age / 0.25, 0.0, 1.0)
	# A dark, glossy pool of overlapping blobs: see-through enough to show the road, with a pale
	# rim and swirls of rainbow sheen, filling the circle that was aimed.
	for blob in _blobs:
		draw_circle(blob[0] * grow, blob[1] * grow + 4.0, Color(0.85, 0.8, 0.95, 0.18 * fade))
	for blob in _blobs:
		draw_circle(blob[0] * grow, blob[1] * grow, Color(0.12, 0.08, 0.16, 0.68 * fade))
	var shimmer := 0.5 + 0.5 * sin(_age * 2.0)
	for i in _blobs.size():
		var blob: Array = _blobs[i]
		var c: Vector2 = blob[0] * grow * 0.7
		var r: float = blob[1] * grow
		var turn := _age * 0.3 + i
		draw_arc(c, r * 0.55, turn, turn + 1.4, 14, Color(0.6, 0.42, 0.9, (0.45 + 0.25 * shimmer) * fade), 4.0)
		draw_arc(c, r * 0.38, turn + 2.2, turn + 3.4, 12, Color(0.35, 0.8, 0.72, (0.4 + 0.25 * (1.0 - shimmer)) * fade), 3.0)
		draw_arc(c, r * 0.7, turn + 4.0, turn + 4.8, 10, Color(0.95, 0.78, 0.4, 0.3 * fade), 2.5)
	draw_circle(Vector2(-_radius * 0.25, -_radius * 0.2) * grow, 6.0 * grow, Color(1, 1, 1, 0.35 * fade))
