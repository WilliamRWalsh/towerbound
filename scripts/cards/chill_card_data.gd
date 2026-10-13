class_name ChillCardData
extends CardData
## A burst of frost anywhere on the battlefield: light frost damage and a chill on every enemy
## inside. Chilled enemies walk and strike slower and are brittle against crush damage.

const FROST_COLOR := Color(0.55, 0.85, 1.0)

@export var damage := 0.5
## Burst radius in world units at the 720 × 1280 reference resolution.
@export var radius := 70.0
## The status it puts on enemies, and for how long before each enemy's frost multiplier.
@export var chill: StatusEffect
@export var chill_duration := 5.0


func damage_type() -> int:
	return Damage.Type.FROST


func begin_targeting(field: Battlefield) -> void:
	field.overlay.show_circle(Units.px(radius), FROST_COLOR)


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.overlay.move_circle(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	FrostBurst.cast(field, global_pos, damage, Units.px(radius), chill, chill_duration)
	return true
