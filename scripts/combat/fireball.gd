class_name Fireball
extends Node2D
## A Fireball spell: a flaming meteor falls onto the target point, then bursts. On impact it
## damages every living enemy within the radius exactly once; enemies that die from it pay out
## through their own `died` signal. It then leaves a BurningGround patch on the ground layer that
## keeps burning enemies who stand in or walk through it. Any Oil Slick the blast touches
## ignites. Works in its parent's (map-pixel) coordinates.

const FALL_TIME := 0.42
const BURST_TIME := 0.7
## Where the meteor starts, relative to the target, in map pixels.
const FALL_FROM := Vector2(-160, -520)
const CORE := Color(1.0, 0.95, 0.7)
const FLAME := Color(1.0, 0.55, 0.12)
const EMBER := Color(0.85, 0.2, 0.05)

var _damage := 3.0
var _radius := 90.0
var _ground: Node2D
var _burn_dps := 1.0
var _burn_duration := 4.0
var _age := 0.0
var _landed := false
## Each spark: [position, velocity] relative to the impact point.
var _sparks: Array = []


## Casts a fireball at a canvas position. `radius` is in map pixels. The burning patch goes on
## `ground_layer`, under the enemies.
static func cast(layer: Node2D, target_global: Vector2, damage: float, radius: float,
		ground_layer: Node2D, burn_dps: float, burn_duration: float) -> Fireball:
	var fireball := Fireball.new()
	fireball._damage = damage
	fireball._radius = radius
	fireball._ground = ground_layer
	fireball._burn_dps = burn_dps
	fireball._burn_duration = burn_duration
	layer.add_child(fireball)
	fireball.position = layer.to_local(target_global)
	return fireball


func _process(delta: float) -> void:
	_age += delta
	if not _landed and _age >= FALL_TIME:
		_explode()
	for spark in _sparks:
		spark[0] += spark[1] * delta
		spark[1] *= 0.9
	if _age >= FALL_TIME + BURST_TIME:
		queue_free()
	queue_redraw()


func _explode() -> void:
	_landed = true
	var parent := get_parent() as Node2D
	var hit: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if enemy.is_alive() and parent.to_local(enemy.global_position).distance_to(position) <= _radius:
			hit.append(enemy)
	for enemy in hit:
		enemy.take_damage(_damage, Damage.Type.FIRE)
	OilSlick.ignite_within(get_tree(), global_position, _radius * global_scale.x)
	if _burn_duration > 0.0:
		BurningGround.ignite(_ground, global_position, _radius, _burn_dps, _burn_duration)
	for i in 18:
		var dir := Vector2.from_angle(randf() * TAU)
		_sparks.append([dir * randf_range(4, 20), dir * randf_range(220, 520) * Vector2(1.0, 0.65)])


func _draw() -> void:
	if not _landed:
		var t := _age / FALL_TIME
		var head := FALL_FROM * (1.0 - t * t)
		var back := FALL_FROM.normalized()
		# Trail of shrinking flame blobs behind the meteor.
		for i in 8:
			var k := float(i) / 8.0
			var pos := head + back * (14.0 + 22.0 * i)
			draw_circle(pos, 22.0 * (1.0 - k), Color(FLAME, 0.55 * (1.0 - k)))
		draw_circle(head, 28.0, Color(EMBER, 0.6))
		draw_circle(head, 21.0, FLAME)
		draw_circle(head - back * 4.0, 12.0, CORE)
		# Shadow of the landing spot growing as it nears.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, _radius * 0.5 * t, Color(0, 0, 0, 0.25 * t))
		draw_set_transform(Vector2.ZERO)
		return
	var b := clampf((_age - FALL_TIME) / BURST_TIME, 0.0, 1.0)
	var fade := 1.0 - b
	# Blast ring, fireball core, then sparks; the burning patch below supplies the scorch.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, _radius * (0.4 + 0.7 * b), Color(EMBER, 0.45 * fade))
	draw_arc(Vector2.ZERO, _radius * (0.5 + 0.6 * b), 0, TAU, 64, Color(FLAME, fade), 10.0 * fade + 1.0)
	draw_set_transform(Vector2.ZERO)
	var bloom := 1.0 - pow(b, 0.6)
	draw_circle(Vector2(0, -10), _radius * 0.65 * bloom, Color(FLAME, 0.8 * bloom))
	draw_circle(Vector2(0, -14), _radius * 0.38 * bloom, Color(CORE, bloom))
	for spark in _sparks:
		draw_circle(spark[0], 4.5 * fade + 0.5, Color(1.0, 0.75, 0.3, fade))
