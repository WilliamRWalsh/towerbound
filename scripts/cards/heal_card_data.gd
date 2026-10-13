class_name HealCardData
extends CardData
## Restores castle health, up to its maximum. The castle glows while the card is aimed; dropping
## or tapping anywhere on the battlefield casts it, since the raised card can cover the castle.

@export var amount := 5


func can_play(field: Battlefield) -> bool:
	return not field.castle.is_full() and not field.castle.is_destroyed()


func begin_targeting(field: Battlefield) -> void:
	field.castle.highlighted = true


func play(field: Battlefield, _global_pos: Vector2) -> bool:
	return field.castle.heal(amount)
