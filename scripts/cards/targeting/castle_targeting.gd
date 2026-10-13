class_name CastleTargeting
extends CardTargeting
## Aims at the castle. The castle glows while the card is held, and a drop or tap anywhere on the
## battlefield counts, since the raised card can cover the castle.


func begin(world: Battlefield, _card: CardData) -> void:
	world.castle.highlighted = true


func end(world: Battlefield) -> void:
	world.castle.highlighted = false


func resolve(world: Battlefield, _card: CardData, _global_pos: Vector2) -> CardTarget:
	return CardTarget.new(world.castle.to_global(world.castle.gate_center))


func has_any_target(world: Battlefield, card: CardData) -> bool:
	return card.can_play_on(world, resolve(world, card, Vector2.ZERO))
