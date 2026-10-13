extends GutTest
## Cards are put together from a targeting and effects. These check the parts work together,
## including on a card that exists only in this test.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func test_damage_badges_come_from_the_played_effects() -> void:
	assert_eq(Driver.ARCHER.damage_type(), Damage.Type.PIERCE)
	assert_eq(Driver.CANNON.damage_type(), Damage.Type.CRUSH)
	assert_eq(Driver.FIREBALL.damage_type(), Damage.Type.FIRE)
	assert_eq(Driver.CHILL.damage_type(), Damage.Type.FROST)
	assert_eq(Driver.BARRICADE.damage_type(), Damage.NONE, "its caltrops only come on discard")
	assert_eq(Driver.REPAIR.damage_type(), Damage.NONE)


## A card no one has made yet: a frozen oil slick laid on the road, built only from existing parts.
func _frost_trap() -> CardData:
	var area := AreaTargeting.new()
	area.radius = 55.0
	area.on_road = true
	var oil: SpillOilEffect = (Driver.OIL.find_effect(SpillOilEffect) as SpillOilEffect).duplicate()
	var frost: FrostBurstEffect = (Driver.CHILL.find_effect(FrostBurstEffect) as FrostBurstEffect).duplicate()
	var card := CardData.new()
	card.id = &"frost_trap"
	card.title = "Frost Trap"
	card.art = Driver.CHILL.art
	card.cost = 2
	card.targeting = area
	var effects: Array[CardEffect] = [oil, frost]
	card.effects = effects
	return card


func test_a_new_card_from_existing_parts() -> void:
	var trap := _frost_trap()
	d = Driver.new(self, Driver.make_level([trap, Driver.ARCHER, Driver.ARCHER, Driver.ARCHER], 999.0))
	await d.advance(0.3)
	d.silence_turrets()
	var goblin := d.spawn(Driver.GOBLIN, 800.0)
	goblin.process_mode = Node.PROCESS_MODE_DISABLED
	await d.play_card("Frost Trap", d.cell_pos(d.cell_far_from_road(150.0)))
	assert_eq(d.mana(), 6.0, "off the road")
	await d.press_cancel()
	await d.play_card("Frost Trap", goblin.global_position)
	assert_eq(d.mana(), 4.0)
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 1)
	assert_true(d.is_chilled(goblin))
	assert_almost_eq(goblin.health, 2.5, 0.001)
	assert_eq(trap.damage_type(), Damage.Type.FROST)
