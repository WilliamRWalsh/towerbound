class_name ArcherTower
extends Tower
## Wooden Archer Tower: looses a quick arrow at its target.

## Where arrows leave the turret, relative to the tower's cell center.
const MUZZLE := Vector2(0, -125)

@onready var _sprite: Sprite2D = $Sprite


func _fire(target: Enemy) -> void:
	Arrow.launch(_projectiles, to_global(MUZZLE), target, stats.damage, stats.damage_type, stats.projectile_speed)
	# A quick squash sells the shot without delaying it.
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.98, 0.9), 0.05)
	tween.tween_property(_sprite, "scale", Vector2(0.94, 0.94), 0.12)
