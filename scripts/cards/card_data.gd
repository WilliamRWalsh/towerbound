class_name CardData
extends Resource
## What a card is and does. Subclasses decide how the card aims (`begin_targeting`,
## `update_targeting`) and what playing it changes (`play`). main.gd owns the rules around them:
## it checks mana before a card is selected or played, and only on a successful `play` does it
## remove the card from the hand, discard it, and spend its cost.

@export var title := ""
@export var art: Texture2D
@export var cost := 2


## False when the card has no possible target right now (e.g. Heal at full health); the card
## is then rejected when selected, without spending anything.
func can_play(_field: Battlefield) -> bool:
	return true


## Turns on this card's targeting preview.
func begin_targeting(_field: Battlefield) -> void:
	pass


## Moves the preview. `over_field` is false while the pointer is over the hand.
func update_targeting(_field: Battlefield, _global_pos: Vector2, _over_field: bool) -> void:
	pass


## Applies the card at a canvas position. Returns false, changing nothing, on an invalid target.
func play(_field: Battlefield, _global_pos: Vector2) -> bool:
	return false


## The Damage.Type this card deals, for the badge on the card, or Damage.NONE.
func damage_type() -> int:
	return Damage.NONE


## Called once when the card is thrown away with Discard (not when played).
func on_discard(_field: Battlefield) -> void:
	pass


## Options the player must pick between before this card is played at a canvas position (e.g.
## which upgrade a tower gets). Empty means `play` applies it directly.
func choices_at(_field: Battlefield, _global_pos: Vector2) -> PackedStringArray:
	return PackedStringArray()


## Applies the card with the option picked from `choices_at`. Returns false, changing nothing, on
## an invalid target.
func play_choice(field: Battlefield, global_pos: Vector2, _choice: int) -> bool:
	return play(field, global_pos)
