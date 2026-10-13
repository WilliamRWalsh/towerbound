extends GutTest
## Playing cards from the hand: mana and cards are spent exactly once on a valid play, and
## nothing is spent on an invalid target, a cancel, or an unaffordable card.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func after_each() -> void:
	Engine.time_scale = 1.0


## A battle whose hand is exactly these four cards, held in preparation for a long time.
func _start(deck: Array) -> void:
	d = Driver.new(self, Driver.make_level(deck, 999.0))
	await d.advance(0.5)


func test_starting_state() -> void:
	d = Driver.new(self)
	await d.advance(0.2)
	assert_eq(d.castle().health, 20.0)
	assert_eq(d.mana(), 6.0)
	assert_eq(d.hand_cards().size(), 4)
	assert_eq(d.wave_number(), 1)
	assert_true(d.is_preparing())
	assert_almost_eq(d.prepare_time_left(), 6.8, 0.1)
	assert_eq(d.draw_pile_count(), 11)
	assert_eq(d.towers().size(), 0)


func test_tap_play_places_tower_and_spends_once() -> void:
	await _start([Driver.ARCHER, Driver.ARCHER, Driver.CHILL, Driver.OIL])
	var cell := d.buildable_cells()[0]
	await d.play_card("Archer Tower", d.cell_pos(cell))
	assert_eq(d.mana(), 4.0)
	assert_eq(d.hand_cards().size(), 3)
	assert_eq(d.discard_pile_count(), 1)
	assert_eq(d.towers().size(), 1)
	assert_not_null(d.tower_at(cell))
	assert_null(d.selected_card())


func test_drag_play_places_tower() -> void:
	await _start([Driver.ARCHER, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.drag_card("Archer Tower", d.cell_pos(d.buildable_cells()[3]))
	assert_eq(d.towers().size(), 1)
	assert_eq(d.mana(), 4.0)
	assert_eq(d.hand_cards().size(), 3)


func test_invalid_drops_spend_nothing() -> void:
	await _start([Driver.ARCHER, Driver.ARCHER, Driver.CHILL, Driver.OIL])
	var road_cell := d.blocked_cells()[0]
	await d.drag_card("Archer Tower", d.cell_pos(road_cell))
	assert_eq(d.towers().size(), 0, "blocked cell")
	await d.drag_card("Archer Tower", d.castle().to_global(d.castle().gate_center))
	assert_eq(d.towers().size(), 0, "castle gate")
	await d.drag_card("Archer Tower", Vector2(360, 1250))
	assert_eq(d.towers().size(), 0, "back over the hand")
	assert_eq(d.mana(), 6.0)
	assert_eq(d.hand_cards().size(), 4)
	assert_eq(d.discard_pile_count(), 0)


func test_invalid_tap_keeps_the_card_selected() -> void:
	await _start([Driver.ARCHER, Driver.ARCHER, Driver.CHILL, Driver.OIL])
	var cell := d.buildable_cells()[0]
	await d.play_card("Archer Tower", d.cell_pos(cell))
	await d.tap_card("Archer Tower")
	var selected := d.selected_card()
	assert_not_null(selected)
	await d.tap(d.cell_pos(cell))
	await d.advance(0.2)
	assert_eq(d.selected_card(), selected, "occupied cell keeps it selected")
	await d.tap(d.cell_pos(d.blocked_cells()[0]))
	await d.advance(0.2)
	assert_eq(d.selected_card(), selected, "blocked cell keeps it selected")
	assert_eq(d.mana(), 4.0)
	assert_eq(d.towers().size(), 1)
	# A valid cell then plays it.
	await d.tap(d.cell_pos(d.buildable_cells()[5]))
	await d.advance(0.2)
	assert_eq(d.towers().size(), 2)
	assert_eq(d.mana(), 2.0)


func test_cancel_spends_nothing() -> void:
	await _start([Driver.ARCHER, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.tap_card("Archer Tower")
	assert_not_null(d.selected_card())
	await d.press_cancel()
	assert_null(d.selected_card())
	await d.tap_card("Archer Tower")
	await d.tap_card("Archer Tower")
	assert_null(d.selected_card(), "tapping the selected card again cancels")
	assert_eq(d.mana(), 6.0)
	assert_eq(d.hand_cards().size(), 4)


func test_unaffordable_card_is_not_selected() -> void:
	await _start([Driver.ARCHER, Driver.CANNON, Driver.CHILL, Driver.OIL])
	d.set_mana(1.0)
	await d.tap_card("Cannon Tower")
	assert_null(d.selected_card())
	await d.drag_card("Archer Tower", d.cell_pos(d.buildable_cells()[0]))
	assert_eq(d.towers().size(), 0)
	assert_eq(d.mana(), 1.0)
	assert_eq(d.hand_cards().size(), 4)


func test_cannon_costs_three() -> void:
	await _start([Driver.CANNON, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.play_card("Cannon Tower", d.cell_pos(d.buildable_cells()[0]))
	assert_eq(d.mana(), 3.0)
	assert_true(d.towers()[0] is CannonTower)


func test_repair_restores_health_up_to_full() -> void:
	await _start([Driver.REPAIR, Driver.REPAIR, Driver.CHILL, Driver.OIL])
	await d.tap_card("Repair")
	assert_null(d.selected_card(), "refused at full health")
	d.castle().take_damage(7.0)
	await d.play_card("Repair", Vector2(360, 600))
	assert_eq(d.castle().health, 18.0)
	assert_eq(d.mana(), 4.0)
	await d.play_card("Repair", Vector2(360, 600))
	assert_eq(d.castle().health, 20.0)
	assert_eq(d.mana(), 2.0)


func test_repair_dropped_on_the_hand_spends_nothing() -> void:
	await _start([Driver.REPAIR, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	d.castle().take_damage(5.0)
	await d.drag_card("Repair", Vector2(360, 1250))
	assert_eq(d.castle().health, 15.0)
	assert_eq(d.mana(), 6.0)


func test_upgrade_chooser_spends_only_on_a_pick() -> void:
	await _start([Driver.ARCHER, Driver.UPGRADE, Driver.UPGRADE, Driver.UPGRADE])
	var cell := d.buildable_cells()[10]
	await d.play_card("Archer Tower", d.cell_pos(cell))
	d.set_mana(10.0)
	var tower := d.tower_at(cell)
	# Opening the chooser and backing out spends nothing.
	await d.play_card("Upgrade", d.cell_pos(cell))
	assert_true(d.chooser_open())
	assert_eq(d.mana(), 10.0)
	await d.press_cancel()
	assert_false(d.chooser_open())
	assert_eq(d.hand_cards().size(), 3)
	assert_eq(d.mana(), 10.0)
	# Picking Rate of Fire spends the card and 3 mana once.
	await d.play_card("Upgrade", d.cell_pos(cell))
	await d.choose("Rate")
	assert_almost_eq(d.fire_interval(tower), 0.667, 0.001)
	assert_eq(d.mana(), 7.0)
	assert_eq(d.hand_cards().size(), 2)
	# With only Ammo left, the next Upgrade applies straight away.
	await d.play_card("Upgrade", d.cell_pos(cell))
	assert_false(d.chooser_open())
	assert_eq(d.max_charges(tower), 3)
	assert_eq(d.charges_left(tower), 3)
	assert_eq(d.mana(), 4.0)
	# Nothing left to upgrade: the last card is refused.
	await d.tap_card("Upgrade")
	assert_null(d.selected_card())
	assert_eq(d.mana(), 4.0)
	assert_eq(d.hand_cards().size(), 1)


func test_upgrade_on_an_empty_cell_spends_nothing() -> void:
	await _start([Driver.ARCHER, Driver.UPGRADE, Driver.CHILL, Driver.OIL])
	await d.play_card("Archer Tower", d.cell_pos(d.buildable_cells()[0]))
	await d.play_card("Upgrade", d.cell_pos(d.buildable_cells()[4]))
	assert_false(d.chooser_open())
	assert_eq(d.mana(), 4.0)
	assert_eq(d.hand_cards().size(), 3)


func test_discard_once_per_wave() -> void:
	await _start([Driver.ARCHER, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.press_discard()
	assert_true(d.is_discarding())
	await d.tap_card("Chill")
	assert_false(d.is_discarding())
	assert_eq(d.hand_cards().size(), 3)
	assert_eq(d.discard_pile_count(), 1)
	assert_eq(d.mana(), 6.0)
	assert_true(d.discard_button().disabled)
	await d.press_discard()
	assert_false(d.is_discarding(), "a second discard this wave is refused")


func test_discard_mode_backs_out() -> void:
	await _start([Driver.ARCHER, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.press_discard()
	await d.press_cancel()
	assert_false(d.is_discarding())
	await d.press_discard()
	await d.tap(d.cell_pos(d.buildable_cells()[0]))
	assert_false(d.is_discarding(), "a tap on the battlefield backs out")
	assert_eq(d.hand_cards().size(), 4)
	assert_false(d.discard_button().disabled)


func test_discarding_a_barricade_scatters_caltrops() -> void:
	await _start([Driver.BARRICADE, Driver.CHILL, Driver.OIL, Driver.FIREBALL])
	await d.press_discard()
	await d.tap_card("Barricade")
	assert_eq(d.count_in(d.ground_layer(), Caltrops), 1)
	assert_eq(d.mana(), 6.0)


func test_barricade_snaps_to_the_road() -> void:
	await _start([Driver.BARRICADE, Driver.BARRICADE, Driver.CHILL, Driver.OIL])
	await d.play_card("Barricade", d.cell_pos(d.cell_far_from_road(150.0)))
	assert_eq(d.mana(), 6.0, "off the road")
	await d.press_cancel()
	await d.play_card("Barricade", d.road_pos(700.0))
	assert_eq(d.mana(), 4.0)
	await d.play_card("Barricade", d.road_pos(750.0))
	assert_eq(d.mana(), 4.0, "too close to another barricade")
	await d.press_cancel()
	await d.play_card("Barricade", d.road_pos(60.0))
	assert_eq(d.mana(), 4.0, "too close to the Badlands gate")


func test_cards_refill_to_four_and_keep_unplayed() -> void:
	d = Driver.new(self, Driver.make_level([], 1.0))
	await d.advance(0.3)
	d.place_tower(d.cell_near_road(), Driver.CANNON)
	for cell in d.buildable_cells().slice(0, 12):
		if d.tower_at(cell) == null:
			d.place_tower(cell, Driver.CANNON)
	await d.press_discard()
	await d.tap(d.card_point(d.hand_cards()[0]))
	await d.advance(0.3)
	var after_discard := d.hand_titles()
	Engine.time_scale = 4.0
	assert_true(await d.run_until(func() -> bool: return d.wave_number() == 2, 120.0), "wave 1 cleared")
	Engine.time_scale = 1.0
	await d.advance(0.5)
	assert_eq(d.hand_cards().size(), 4)
	for title in after_discard:
		assert_has(d.hand_titles(), title, "unplayed card stays in hand")
	assert_false(d.discard_button().disabled, "discard comes back next wave")
