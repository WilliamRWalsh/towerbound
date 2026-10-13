class_name CardEffect
extends Resource
## One thing a card does to its target when played (or when thrown away, for a discard effect).
## A card checks `can_apply` on every effect before applying any, so a card is played whole or
## not at all.


## False when this target is no good for this effect (a full castle, a tower with nothing left
## to upgrade); the play is refused and nothing is spent.
func can_apply(_world: Battlefield, _target: CardTarget) -> bool:
	return true


## Labels the player must pick between before the effect applies here (which upgrade), or empty.
func choices(_world: Battlefield, _target: CardTarget) -> PackedStringArray:
	return PackedStringArray()


## Does the effect. `choice` indexes `choices` when there were any.
func apply(_world: Battlefield, _target: CardTarget, _choice: int) -> void:
	pass


## The Damage.Type it deals, for the badge on the card, or Damage.NONE.
func damage_type() -> int:
	return Damage.NONE
