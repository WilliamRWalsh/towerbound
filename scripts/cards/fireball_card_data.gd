class_name FireballCardData
extends CardData
## Hurls a fireball at any point on the battlefield, damaging every enemy within its radius, then
## leaves the ground there burning for a while.

@export var damage := 3.0
## Blast radius in world units at the 720 × 1280 reference resolution.
@export var radius := 70.0
## How the patch it leaves behind burns.
@export var burn: BurnSpec


func damage_type() -> int:
	return Damage.Type.FIRE


func begin_targeting(field: Battlefield) -> void:
	field.overlay.show_circle(Units.px(radius))


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.overlay.move_circle(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	Fireball.cast(field, global_pos, damage, Units.px(radius), burn)
	return true
