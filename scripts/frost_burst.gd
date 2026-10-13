class_name FrostBurst
extends Node2D
## A Chill spell: a ring of frost bursts out from the target point. At once it deals frost damage
## to every living enemy within the radius and chills them; kills pay out through the enemy's own
## `died` signal. Then icy shards fly out and fade. Works in its parent's (map-pixel) coordinates.

const BURST_TIME := 0.6
const ICE := Color(0.78, 0.93, 1.0)
const DEEP := Color(0.35, 0.65, 0.95)

var _radius := 90.0
var _age := 0.0
## Each shard: [direction, length, speed share].
var _shards: Array = []


## Casts a frost burst at a canvas position. `radius` is in map pixels.
static func cast(layer: Node2D, target_global: Vector2, damage: float, radius: float, chill_duration: float) -> FrostBurst:
	var burst := FrostBurst.new()
	burst._radius = radius
	for i in 14:
		burst._shards.append([Vector2.from_angle(TAU * i / 14.0 + randf_range(-0.15, 0.15)),
			randf_range(10, 20), randf_range(0.7, 1.0)])
	layer.add_child(burst)
	burst.position = layer.to_local(target_global)
	var hit: Array[Enemy] = []
	for enemy: Enemy in layer.get_tree().get_nodes_in_group(Enemy.GROUP):
		if enemy.is_alive() and layer.to_local(enemy.global_position).distance_to(burst.position) <= radius:
			hit.append(enemy)
	for enemy in hit:
		# Chill first so the hit flash shows the enemy already frosted.
		enemy.apply_chill(chill_duration)
		enemy.take_damage(damage, Damage.Type.FROST)
	return burst


func _process(delta: float) -> void:
	_age += delta
	if _age >= BURST_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / BURST_TIME, 0.0, 1.0)
	var fade := 1.0 - t
	var spread := 1.0 - pow(1.0 - t, 3.0)
	draw_circle(Vector2.ZERO, _radius * spread, Color(DEEP, 0.18 * fade))
	draw_arc(Vector2.ZERO, _radius * spread, 0, TAU, 64, Color(ICE, 0.95 * fade), 8.0 * fade + 1.0)
	draw_arc(Vector2.ZERO, _radius * spread * 0.7, 0, TAU, 48, Color(ICE, 0.4 * fade), 3.0)
	for shard in _shards:
		var dir: Vector2 = shard[0]
		var tip: Vector2 = dir * _radius * spread * shard[2]
		var side := dir.orthogonal() * 4.0
		draw_colored_polygon(PackedVector2Array([tip + dir * shard[1], tip + side, tip - dir * 6.0, tip - side]),
				Color(ICE, 0.9 * fade))
	draw_circle(Vector2.ZERO, 26.0 * (1.0 - t), Color(1, 1, 1, 0.8 * fade))
