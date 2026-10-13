class_name StatusEffect
extends Resource
## A timed condition on an enemy, such as Chill or an oil slick's slow. While it lasts it can slow
## the enemy's walk, slow its strikes, change the damage it takes, and tint it. Applying an effect
## the enemy already has keeps the longer of the two durations. Several effects at once combine:
## the strongest slow and the slowest strikes win, and damage multipliers stack.

## Names the effect, e.g. for `Enemy.has_status`.
@export var id: StringName
## Walking speed multiplier while it lasts (0.5 = half speed).
@export_range(0.0, 1.0) var speed_multiplier := 1.0
## Multiplier on the time between gate and barricade strikes, read as each swing starts.
@export var strike_interval_multiplier := 1.0
## Extra multipliers on damage taken while it lasts, by Damage.Type (e.g. brittle against crush).
@export var damage_taken: Dictionary[Damage.Type, float] = {}
## The effect's element. When `resistible`, an enemy's multiplier for this damage type also
## scales how long the effect lasts on it (a giant shrugs off frost twice as fast).
@export var element: Damage.Type = Damage.Type.PIERCE
@export var resistible := false
## Color the enemy's art shifts toward while it lasts; transparent for none.
@export var tint := Color(0, 0, 0, 0)
## Seconds over which the tint fades out as the effect runs out.
@export var tint_fade := 0.4
