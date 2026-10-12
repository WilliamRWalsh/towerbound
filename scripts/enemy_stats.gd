class_name EnemyStats
extends Resource
## Tuning for one enemy type. Speed is in world units per second at the 720 × 1280 reference
## resolution.

@export var max_health := 3
@export var speed := 85.0
## Castle health lost when this enemy reaches the castle.
@export var castle_damage := 1
## Mana granted once when this enemy is killed.
@export var mana_reward := 0.1
