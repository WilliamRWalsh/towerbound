class_name Tower
extends Node2D
## Base for towers placed on the battlefield. Targets the in-range enemy furthest along the path
## and fires on a cooldown, using the stats of the card that placed it. Inactive (a placement
## preview) until `activate` is called. Subclasses decide what firing looks like.

var stats: TowerStats

var _projectiles: Node2D
var _cooldown := 0.0


func activate(tower_stats: TowerStats, projectile_layer: Node2D) -> void:
	stats = tower_stats
	_projectiles = projectile_layer


func _process(delta: float) -> void:
	if _projectiles == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	var target := find_target()
	if target:
		_cooldown = stats.fire_interval
		_fire(target)


## The living enemy in range that is furthest along the path, or null.
func find_target() -> Enemy:
	var reach := stats.attack_range * BuildGrid.MAP_PIXELS_PER_UNIT * global_scale.x
	var best: Enemy = null
	for enemy: Enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if not enemy.is_alive() or global_position.distance_to(enemy.global_position) > reach:
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _fire(_target: Enemy) -> void:
	pass


func _draw() -> void:
	# Soft contact shadow under the tower base; the sprite child draws on top.
	draw_set_transform(Vector2(0, 34), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 60.0, Color(0, 0, 0, 0.3))
