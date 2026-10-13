class_name Deck
extends RefCounted
## The cards of one battle that aren't in the hand: a shuffled draw pile and a discard pile.
## Drawing from an empty draw pile shuffles the discards back in first. Pure rules, no display.

var _draw_pile: Array[CardData] = []
var _discard_pile: Array[CardData] = []


func _init(cards: Array[CardData]) -> void:
	_draw_pile = cards.duplicate()
	_draw_pile.shuffle()


## The next card, or null when both piles are empty (every card is in the hand).
func draw() -> CardData:
	if _draw_pile.is_empty():
		_draw_pile = _discard_pile
		_discard_pile = []
		_draw_pile.shuffle()
	return _draw_pile.pop_back()


func discard(card: CardData) -> void:
	_discard_pile.append(card)


func draw_count() -> int:
	return _draw_pile.size()


func discard_count() -> int:
	return _discard_pile.size()
