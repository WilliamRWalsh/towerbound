class_name TowerCardData
extends CardData
## Places a tower on an open build cell.

@export var tower_scene: PackedScene
## Combat stats the placed tower uses.
@export var tower_stats: TowerStats


func damage_type() -> int:
	return tower_stats.damage_type


func begin_targeting(field: Battlefield) -> void:
	field.placement.show_placement(tower_scene, tower_stats)


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.placement.update_pointer(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	return field.grid.place_tower(field.grid.world_to_cell(global_pos), tower_scene, tower_stats)
