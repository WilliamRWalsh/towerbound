class_name PlaceTowerEffect
extends CardEffect
## Builds a tower on the targeted cell, with these stats.

@export var tower_scene: PackedScene
@export var tower_stats: TowerStats


func can_apply(world: Battlefield, target: CardTarget) -> bool:
	return world.grid.can_build(target.cell)


func apply(world: Battlefield, target: CardTarget, _choice: int) -> void:
	world.grid.place_tower(target.cell, tower_scene, tower_stats)


func damage_type() -> int:
	return tower_stats.damage_type


func describe(values: Dictionary) -> void:
	values["damage"] = decimal(tower_stats.damage)
	values["attack_speed"] = decimal(1.0 / tower_stats.fire_interval)
	values["range"] = decimal(Units.paces(tower_stats.attack_range))
	values["charges"] = str(tower_stats.charges)
