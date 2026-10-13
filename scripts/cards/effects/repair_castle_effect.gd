class_name RepairCastleEffect
extends CardEffect
## Restores castle health, up to its maximum.

@export var amount := 5


func can_apply(world: Battlefield, _target: CardTarget) -> bool:
	return not world.castle.is_full() and not world.castle.is_destroyed()


func apply(world: Battlefield, _target: CardTarget, _choice: int) -> void:
	world.castle.heal(amount)
