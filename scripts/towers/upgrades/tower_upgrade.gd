class_name TowerUpgrade
extends Resource
## One improvement an Upgrade card can make to a placed tower, at most once per tower. Subclasses
## say what it changes and how it reads on the upgrade chooser.

## Names the upgrade; a tower records the ids it has taken.
@export var id: StringName
## Marks the tower with the gold chevron badge once taken.
@export var shows_badge := false


func can_apply(tower: Tower) -> bool:
	return not tower.has_upgrade(id)


func apply(_tower: Tower) -> void:
	pass


## Button text on the upgrade chooser, built from the upgrade's numbers so it can't go stale.
func label() -> String:
	return String(id).capitalize()


## How much it adds, for card text: "+50%", "+1".
func amount_text() -> String:
	return ""
