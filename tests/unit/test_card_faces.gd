extends GutTest
## Card faces print the cards' real numbers, filled in from the data rather than baked into art.

const ARCHER := preload("res://data/cards/archer_tower.tres")
const CANNON := preload("res://data/cards/cannon_tower.tres")
const FIREBALL := preload("res://data/cards/fireball.tres")
const UPGRADE := preload("res://data/cards/upgrade.tres")
const REPAIR := preload("res://data/cards/repair.tres")
const BARRICADE := preload("res://data/cards/barricade.tres")
const OIL := preload("res://data/cards/oil_slick.tres")
const CHILL := preload("res://data/cards/chill.tres")


func _face(card: CardData, context := {}) -> CardFace:
	return CardFace.new(card, load("res://ui/fonts/card_title.tres"), load("res://ui/fonts/card_body.tres"), context)


func _text(card: CardData, context := {}) -> String:
	return " ".join(_face(card, context).description_lines())


func test_tower_stats_match_their_tuning() -> void:
	assert_eq(_face(ARCHER).stat_texts(), PackedStringArray(["1.5 DAMAGE", "1.0 ATTACK SPEED", "5.0 RANGE"]))
	assert_eq(_face(CANNON).stat_texts(), PackedStringArray(["3.0 DAMAGE", "0.5 ATTACK SPEED", "5.0 RANGE"]))


func test_spell_text_matches_its_tuning() -> void:
	assert_eq(_text(FIREBALL), "Hits a small area, then leaves the ground burning for 10 seconds.")
	assert_eq(_face(FIREBALL).stat_texts(), PackedStringArray(["3.0 DAMAGE", "1.9 RADIUS", "10s BURN"]))
	assert_eq(_text(UPGRADE), "Upgrade a tower: +50% attack speed or +1 ammo.")
	assert_eq(_text(CHILL), "Slows enemies in an area. Chilled enemies take +50% cannon hits.")
	assert_eq(_face(CHILL).stat_texts(), PackedStringArray(["5s CHILL", "50% SLOW", "ANY TARGET"]))
	assert_eq(_face(OIL).stat_texts()[0], "40% SLOW")
	assert_eq(_face(BARRICADE).stat_texts()[0], "5 HEALTH")


func test_battle_values_fill_in_from_the_context() -> void:
	assert_eq(_text(REPAIR), "Repairs 5 health of your castle, up to its full health.")
	assert_eq(_face(REPAIR, {"castle_max": "20"}).stat_texts()[2], "20 MAX HEALTH")


func test_descriptions_fit_three_lines() -> void:
	for card in [ARCHER, CANNON, FIREBALL, UPGRADE, REPAIR, BARRICADE, OIL, CHILL]:
		assert_lte(_face(card).description_lines().size(), 3, card.title)


func test_every_card_has_its_art() -> void:
	for card in [ARCHER, CANNON, FIREBALL, UPGRADE, REPAIR, BARRICADE, OIL, CHILL]:
		assert_not_null(card.painting, card.title)
		assert_not_null(card.icon, card.title)
		assert_eq(card.stats.size(), 3, card.title)
