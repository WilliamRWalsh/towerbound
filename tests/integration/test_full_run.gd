extends GutTest
## Whole runs: a meadow full of upgraded towers wins all ten waves, an undefended castle falls,
## result states stop the battle, and retry starts clean.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver
var spawned := 0
## Enemy instance id → times `died` fired.
var deaths := {}
var bad_wave_ends: Array[int] = []


func before_each() -> void:
	spawned = 0
	deaths.clear()
	bad_wave_ends.clear()


func after_each() -> void:
	Engine.time_scale = 1.0


func _track() -> void:
	d.on_enemy_spawned(func(enemy: Enemy) -> void:
		spawned += 1
		enemy.died.connect(func(e: Enemy) -> void:
			deaths[e.get_instance_id()] = deaths.get(e.get_instance_id(), 0) + 1))
	d.on_wave_cleared(func(number: int) -> void:
		if d.spawns_pending() or not d.living_enemies().is_empty():
			bad_wave_ends.append(number))


func _assert_fresh_run() -> void:
	assert_eq(d.castle().health, 20.0)
	assert_eq(d.mana(), 6.0)
	assert_eq(d.hand_cards().size(), 4)
	assert_eq(d.wave_number(), 1)
	assert_true(d.is_preparing())
	assert_eq(d.result(), "none")
	assert_eq(d.towers().size(), 0)
	assert_eq(d.enemies().size(), 0)
	assert_eq(d.count_in(d.projectile_layer(), Node), 0)
	assert_eq(d.count_in(d.ground_layer(), Node), 0)
	assert_true(d.ledger_is_empty())


func test_win_all_ten_waves_then_retry() -> void:
	d = Driver.new(self)
	await d.advance(0.2)
	_track()
	var i := 0
	for cell in d.buildable_cells():
		var tower := d.place_tower(cell, Driver.ARCHER if i % 2 == 0 else Driver.CANNON)
		d.upgrade_rate(tower)
		d.upgrade_ammo(tower)
		i += 1
	Engine.time_scale = 8.0
	assert_true(await d.run_until(func() -> bool: return d.result() != "none", 1200.0), "run finished")
	Engine.time_scale = 1.0
	assert_eq(d.result(), "victory")
	assert_gt(d.castle().health, 0.0)
	assert_eq(d.wave_number(), 10)
	assert_eq(spawned, 491)
	assert_eq(deaths.size(), 491, "every enemy died")
	assert_true(deaths.values().all(func(n: int) -> bool: return n == 1), "each died exactly once")
	assert_eq(bad_wave_ends, [] as Array[int], "no wave ended with enemies pending or alive")
	# Nothing moves on after the result.
	await d.advance(10.0)
	assert_eq(d.result(), "victory")
	assert_eq(spawned, 491)
	assert_eq(d.wave_number(), 10)
	await d.restart()
	_assert_fresh_run()


func test_undefended_castle_falls_and_everything_stops_then_retry() -> void:
	d = Driver.new(self)
	await d.advance(0.2)
	_track()
	Engine.time_scale = 8.0
	assert_true(await d.run_until(func() -> bool: return d.result() != "none", 900.0), "run finished")
	Engine.time_scale = 1.0
	assert_eq(d.result(), "defeat")
	assert_eq(d.castle().health, 0.0)
	assert_true(d.living_enemies().is_empty(), "enemies halted")
	var wave := d.wave_number()
	var count := spawned
	var mana := d.mana()
	var hand := d.hand_cards().size()
	await d.advance(20.0)
	assert_eq(spawned, count, "no more spawns")
	assert_eq(d.wave_number(), wave, "no phase progression")
	assert_false(d.is_preparing())
	assert_false(d.is_fighting())
	assert_eq(d.castle().health, 0.0)
	# Card play is blocked.
	await d.tap(d.card_point(d.hand_cards()[0]))
	await d.advance(0.3)
	assert_null(d.selected_card())
	await d.press_discard()
	assert_false(d.is_discarding())
	assert_eq(d.mana(), mana)
	assert_eq(d.hand_cards().size(), hand)
	await d.restart()
	_assert_fresh_run()
