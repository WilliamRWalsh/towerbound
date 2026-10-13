class_name EnemyRegistry
extends RefCounted
## The enemies in play on one battlefield, and the questions towers and spells ask about them.
## The battlefield adds each enemy as it spawns; it drops out of every query once it dies for good
## or the battle halts it, and leaves the registry when it leaves the tree. Positions and radii
## are in map pixels (battlefield-local coordinates).

var _field: Node2D
var _enemies: Array[Enemy] = []


func _init(field: Node2D) -> void:
	_field = field


func add(enemy: Enemy) -> void:
	_enemies.append(enemy)
	enemy.tree_exiting.connect(func() -> void: _enemies.erase(enemy), CONNECT_ONE_SHOT)


## Every enemy still in play: alive, or downed and about to get back up.
func in_play() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for enemy in _enemies:
		if enemy.in_play():
			list.append(enemy)
	return list


## Every enemy that can be targeted and hurt, in spawn order.
func living() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for enemy in _enemies:
		if enemy.is_alive():
			list.append(enemy)
	return list


## Living enemies standing within `radius` of `center`.
func in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for enemy in _enemies:
		if enemy.is_alive() and map_position(enemy).distance_to(center) <= radius:
			list.append(enemy)
	return list


## Living enemies between two distances along the road.
func on_road_between(start: float, end: float) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for enemy in _enemies:
		if enemy.is_alive() and enemy.progress >= start and enemy.progress <= end:
			list.append(enemy)
	return list


func map_position(enemy: Enemy) -> Vector2:
	return _field.to_local(enemy.global_position)


## Freezes every enemy in play, when the battle ends.
func halt_all() -> void:
	for enemy in in_play():
		enemy.halt()
