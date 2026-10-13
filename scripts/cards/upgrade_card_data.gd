class_name UpgradeCardData
extends CardData
## Upgrades a placed tower: either its attack rate or its ammo capacity, each once per tower.
## When both are still open the player picks one; when only one is left it applies directly.

enum Choice { RATE, AMMO }

## 0.5 = 50% more shots per second.
@export var attack_rate_bonus := 0.5
## Charges added to the tower's capacity.
@export var extra_charges := 1


func can_play(field: Battlefield) -> bool:
	return field.grid.has_upgradeable_tower()


func begin_targeting(field: Battlefield) -> void:
	field.grid.begin_upgrade_targeting()


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.grid.update_pointer(global_pos, over_field)


func choices_at(field: Battlefield, global_pos: Vector2) -> PackedStringArray:
	var tower := _tower_at(field, global_pos)
	if tower == null or not (tower.can_upgrade_rate() and tower.can_upgrade_ammo()):
		return PackedStringArray()
	return PackedStringArray([
		"Rate of Fire\n+%d%% speed" % roundi(attack_rate_bonus * 100.0),
		"Ammo\n+%d charge%s" % [extra_charges, "" if extra_charges == 1 else "s"],
	])


func play(field: Battlefield, global_pos: Vector2) -> bool:
	var tower := _tower_at(field, global_pos)
	if tower == null:
		return false
	return tower.upgrade_rate(attack_rate_bonus) or tower.upgrade_ammo(extra_charges)


func play_choice(field: Battlefield, global_pos: Vector2, choice: int) -> bool:
	var tower := _tower_at(field, global_pos)
	if tower == null:
		return false
	if choice == Choice.AMMO:
		return tower.upgrade_ammo(extra_charges)
	return tower.upgrade_rate(attack_rate_bonus)


func _tower_at(field: Battlefield, global_pos: Vector2) -> Tower:
	return field.grid.tower_at(field.grid.world_to_cell(global_pos))
