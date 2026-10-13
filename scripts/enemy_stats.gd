class_name EnemyStats
extends Resource
## Tuning for one enemy type. Speed is in world units per second at the 720 × 1280 reference
## resolution.

@export var max_health := 3
@export var speed := 85.0
## Castle (or barricade) health lost each time this enemy strikes it.
@export var castle_damage := 1.0
## Seconds between strikes while it stands at the gate.
@export var attack_interval := 1.5
## Mana granted once when this enemy is killed.
@export var mana_reward := 0.1
## Times it gets back up after being killed; `died` and the mana reward come only from the last death.
@export var revives := 0
## Seconds from falling to standing again.
@export var revive_delay := 2.0
