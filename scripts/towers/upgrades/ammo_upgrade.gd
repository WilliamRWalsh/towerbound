class_name AmmoUpgrade
extends TowerUpgrade
## Gives a tower more charges before it has to reload. Towers with unlimited ammo (castle turrets)
## have nothing to gain.

@export var extra_charges := 1


func can_apply(tower: Tower) -> bool:
	return super(tower) and not tower.ammo.is_unlimited()


func apply(tower: Tower) -> void:
	tower.ammo.add_capacity(extra_charges)


func label() -> String:
	return "Ammo\n+%d charge%s" % [extra_charges, "" if extra_charges == 1 else "s"]
