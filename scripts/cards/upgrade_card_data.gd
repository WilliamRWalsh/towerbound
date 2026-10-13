class_name UpgradeCardData
extends CardData
## Upgrades a placed tower that hasn't been upgraded yet, raising its attack rate.

## 0.5 = 50% more shots per second.
@export var attack_rate_bonus := 0.5


func can_play(field: Battlefield) -> bool:
	return field.grid.has_upgradeable_tower()


func begin_targeting(field: Battlefield) -> void:
	field.grid.begin_upgrade_targeting()


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.grid.update_pointer(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	var tower := field.grid.tower_at(field.grid.world_to_cell(global_pos))
	return tower != null and tower.upgrade(attack_rate_bonus)
