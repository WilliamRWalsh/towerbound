class_name EnemyStats
extends Resource
## Tuning for one enemy type. Speed is in world units per second at the 720 × 1280 reference
## resolution.

## Shown in the wave preview.
@export var display_name := ""
@export var max_health := 3.0
@export var speed := 85.0
## Castle (or barricade) health lost each time this enemy strikes it.
@export var castle_damage := 1.0
## Seconds between strikes while it stands at the gate.
@export var attack_interval := 1.5
## Mana granted once when this enemy is killed.
@export var mana_reward := 0.1
## Times it gets back up after being killed; `died` and the mana reward come only from the last death.
## A killing fire hit keeps it down for good.
@export var revives := 0
## Seconds from falling to standing again.
@export var revive_delay := 2.0

@export_group("Damage taken")
## Multipliers on damage of each type: below 1 resists, above 1 is a weakness. Frost also
## scales how long chill lasts.
@export var pierce := 1.0
@export var crush := 1.0
@export var fire := 1.0
@export var frost := 1.0


func multiplier(type: int) -> float:
	match type:
		Damage.Type.PIERCE:
			return pierce
		Damage.Type.CRUSH:
			return crush
		Damage.Type.FIRE:
			return fire
		Damage.Type.FROST:
			return frost
	return 1.0
