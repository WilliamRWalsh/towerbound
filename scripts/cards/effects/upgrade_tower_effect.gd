class_name UpgradeTowerEffect
extends CardEffect
## Upgrades the targeted tower with one of `upgrades`, each at most once per tower. When more than
## one still applies the player picks; when only one is left it applies directly.

## The upgrades on offer, in chooser order.
@export var upgrades: Array[TowerUpgrade] = []


func can_apply(_world: Battlefield, target: CardTarget) -> bool:
	return target.tower != null and not _options(target.tower).is_empty()


func choices(_world: Battlefield, target: CardTarget) -> PackedStringArray:
	var labels := PackedStringArray()
	var options := _options(target.tower)
	if options.size() > 1:
		for option in options:
			labels.append(option.label())
	return labels


func apply(_world: Battlefield, target: CardTarget, choice: int) -> void:
	var options := _options(target.tower)
	target.tower.upgrade(options[clampi(choice, 0, options.size() - 1)])


## Each upgrade's amount under its id: {rate} → "+50%", {ammo} → "+1".
func describe(values: Dictionary) -> void:
	for option in upgrades:
		values[String(option.id)] = option.amount_text()


## The upgrades `tower` can still take, in chooser order.
func _options(tower: Tower) -> Array[TowerUpgrade]:
	var options: Array[TowerUpgrade] = []
	if tower == null:
		return options
	for option in upgrades:
		if tower.can_take(option):
			options.append(option)
	return options
