class_name CastleTurret
extends Tower
## An archer posted on one of the castle wall's painted turrets. Fires arrows like an Archer
## Tower, from the turret top, with its own (weaker) stats. Draws nothing: the map shows the turret.

@export var turret_stats: TowerStats
@export var projectile_layer: Node2D


func _ready() -> void:
	activate(turret_stats, projectile_layer)


func _fire(target: Enemy) -> void:
	Arrow.launch(_projectiles, global_position, target, stats.damage, stats.projectile_speed)


func _draw() -> void:
	pass
