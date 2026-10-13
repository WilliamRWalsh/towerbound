class_name CardTargeting
extends Resource
## How a card is aimed: the preview it shows on the battlefield while held, and what a drop or tap
## at a position picks out (a CardTarget), or null if nothing valid is there. The card's effects
## then decide whether they can act on that target. Subclasses: CellTargeting, TowerTargeting,
## AreaTargeting, RoadTargeting, CastleTargeting.


## Turns on the preview.
func begin(_world: Battlefield, _card: CardData) -> void:
	pass


## Moves the preview. `over_field` is false while the pointer is over the hand.
func update(_world: Battlefield, _card: CardData, _global_pos: Vector2, _over_field: bool) -> void:
	pass


## Turns off the preview.
func end(_world: Battlefield) -> void:
	pass


## What a drop at `global_pos` would target, or null.
func resolve(_world: Battlefield, _card: CardData, _global_pos: Vector2) -> CardTarget:
	return null


## False when nothing on the battlefield could be targeted right now (Repair at full health), so
## the card is refused when picked up.
func has_any_target(_world: Battlefield, _card: CardData) -> bool:
	return true


## Adds the targeting's numbers to the card's text values (see CardEffect.describe).
func describe(_values: Dictionary) -> void:
	pass
