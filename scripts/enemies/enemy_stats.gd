class_name EnemyStats
extends Resource
## Tuning for one enemy type. Speed is in world units per second at the 720 × 1280 reference
## resolution.

## Shown in the wave preview.
@export var display_name := ""
@export var max_health := 3.0
@export var speed := 85.0
## Castle (or barricade) health lost each time this enemy strikes it.
@export var strike_damage := 1.0
## Seconds between strikes while it stands at the gate.
@export var attack_interval := 1.5
## This enemy's share of its wave's mana (`WaveConfig.mana_reward`), relative to the others in
## the wave. Paid once, when it is killed.
@export var reward_weight := 1.0
## Times it gets back up after being killed; `died` and the mana reward come only from the last death.
@export var revives := 0
## Seconds from falling to standing again.
@export var revive_delay := 2.0
## Damage types whose killing hit keeps it down for good, with no revive (fire burns a zombie).
@export var final_death_types: Array[Damage.Type] = []
## Multiplier on damage of each Damage.Type: below 1 resists, above 1 is a weakness; types not
## listed take 1. A resistible status effect's duration scales the same way (frost and Chill).
@export var damage_taken: Dictionary[Damage.Type, float] = {}


func multiplier(type: int) -> float:
	return damage_taken.get(type, 1.0)
