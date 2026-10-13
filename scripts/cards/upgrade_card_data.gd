class_name UpgradeCardData
extends CardData
## Upgrades a placed tower with one of `upgrades`, each at most once per tower. When more than one
## still applies the player picks; when only one is left it applies directly.

## The upgrades on offer, in chooser order.
@export var upgrades: Array[TowerUpgrade] = []


func can_play(field: Battlefield) -> bool:
	return field.grid.towers().any(func(tower: Tower) -> bool: return not _options(tower).is_empty())


func begin_targeting(field: Battlefield) -> void:
	field.placement.show_tower_targets(func(tower: Tower) -> bool: return not _options(tower).is_empty())


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.placement.update_pointer(global_pos, over_field)


func choices_at(field: Battlefield, global_pos: Vector2) -> PackedStringArray:
	var tower := _tower_at(field, global_pos)
	var labels := PackedStringArray()
	if tower == null:
		return labels
	var options := _options(tower)
	if options.size() > 1:
		for option in options:
			labels.append(option.label())
	return labels


func play(field: Battlefield, global_pos: Vector2) -> bool:
	return play_choice(field, global_pos, 0)


func play_choice(field: Battlefield, global_pos: Vector2, choice: int) -> bool:
	var tower := _tower_at(field, global_pos)
	if tower == null:
		return false
	var options := _options(tower)
	if choice < 0 or choice >= options.size():
		return false
	return tower.upgrade(options[choice])


## The upgrades `tower` can still take, in chooser order.
func _options(tower: Tower) -> Array[TowerUpgrade]:
	var options: Array[TowerUpgrade] = []
	for option in upgrades:
		if tower.can_take(option):
			options.append(option)
	return options


func _tower_at(field: Battlefield, global_pos: Vector2) -> Tower:
	return field.grid.tower_at(field.grid.world_to_cell(global_pos))
