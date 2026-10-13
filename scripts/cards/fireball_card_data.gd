class_name FireballCardData
extends CardData
## Hurls a fireball at any point on the battlefield, damaging every enemy within its radius, then
## leaves the ground there burning for a while.

@export var damage := 3.0
## Blast radius in world units at the 720 × 1280 reference resolution.
@export var radius := 70.0
## Damage per second to each enemy standing in the burning patch, and how long it burns.
@export var burn_dps := 1.0
@export var burn_duration := 4.0


func damage_type() -> int:
	return Damage.Type.FIRE


func begin_targeting(field: Battlefield) -> void:
	field.overlay.show_circle(Units.px(radius))


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.overlay.move_circle(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	Fireball.cast(field.effects, global_pos, damage, Units.px(radius),
		field.ground, burn_dps, burn_duration)
	return true
