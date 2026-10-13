extends GutTest
## The draw and discard piles: shuffling, recycling discards, and running dry.

const ARCHER := preload("res://data/cards/archer_tower.tres")
const FIREBALL := preload("res://data/cards/fireball.tres")
const CHILL := preload("res://data/cards/chill.tres")


func _cards(n: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	var kinds := [ARCHER, FIREBALL, CHILL]
	for i in n:
		cards.append(kinds[i % kinds.size()])
	return cards


func test_draws_every_card_once() -> void:
	var cards := _cards(12)
	var deck := Deck.new(cards)
	var drawn: Array[CardData] = []
	for i in 12:
		drawn.append(deck.draw())
	assert_eq(deck.draw_count(), 0)
	assert_eq(drawn.count(ARCHER), 4)
	assert_eq(drawn.count(FIREBALL), 4)
	assert_eq(drawn.count(CHILL), 4)


func test_does_not_change_the_source_list() -> void:
	var cards := _cards(6)
	var before := cards.duplicate()
	var deck := Deck.new(cards)
	deck.draw()
	assert_eq(cards, before)


func test_reshuffles_discards_when_draw_pile_is_empty() -> void:
	var deck := Deck.new(_cards(4))
	var hand: Array[CardData] = []
	for i in 4:
		hand.append(deck.draw())
	deck.discard(hand.pop_back())
	deck.discard(hand.pop_back())
	assert_eq(deck.discard_count(), 2)
	var next := deck.draw()
	assert_not_null(next)
	assert_eq(deck.discard_count(), 0)
	assert_eq(deck.draw_count(), 1)


func test_no_loss_or_duplication_across_many_cycles() -> void:
	var cards := _cards(15)
	var deck := Deck.new(cards)
	var hand: Array[CardData] = []
	for round in 50:
		while hand.size() < 4:
			var card := deck.draw()
			if card == null:
				break
			hand.append(card)
		# Play or discard one or two cards each round.
		for k in 1 + round % 2:
			deck.discard(hand.pop_front())
		assert_eq(hand.size() + deck.draw_count() + deck.discard_count(), 15)
	var all: Array[CardData] = hand.duplicate()
	while deck.draw_count() + deck.discard_count() > 0:
		all.append(deck.draw())
	assert_eq(all.count(ARCHER), cards.count(ARCHER))
	assert_eq(all.count(FIREBALL), cards.count(FIREBALL))
	assert_eq(all.count(CHILL), cards.count(CHILL))


func test_draw_returns_null_when_both_piles_are_empty() -> void:
	var deck := Deck.new(_cards(2))
	deck.draw()
	deck.draw()
	assert_null(deck.draw())
	assert_null(deck.draw())
