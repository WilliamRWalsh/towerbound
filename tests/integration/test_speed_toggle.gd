extends GutTest
## The x2 button: double speed only during combat, dropped when the castle is hurt or the wave ends.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func after_each() -> void:
	Engine.time_scale = 1.0


func _start_combat() -> void:
	d = Driver.new(self, Driver.make_level([], 0.5))
	await d.advance(0.1)
	d.silence_turrets()
	assert_true(await d.run_until(func() -> bool: return d.is_fighting(), 2.0))


func test_unavailable_during_preparation() -> void:
	d = Driver.new(self, Driver.make_level([], 30.0))
	await d.advance(0.1)
	assert_true(d.speed_toggle().disabled)
	await d.press_speed()
	assert_false(d.is_fast())
	assert_eq(Engine.time_scale, 1.0)


func test_doubles_speed_in_combat_and_toggles_off() -> void:
	await _start_combat()
	assert_false(d.speed_toggle().disabled)
	await d.press_speed()
	assert_true(d.is_fast())
	assert_eq(Engine.time_scale, 2.0)
	await d.press_speed()
	assert_false(d.is_fast())
	assert_eq(Engine.time_scale, 1.0)


func test_castle_damage_drops_back_to_normal_until_pressed_again() -> void:
	await _start_combat()
	await d.press_speed()
	d.castle().take_damage(0.85)
	assert_false(d.is_fast())
	assert_false(d.speed_toggle().button_pressed)
	assert_eq(Engine.time_scale, 1.0)
	await d.press_speed()
	assert_true(d.is_fast())
	assert_eq(Engine.time_scale, 2.0)


func test_repair_keeps_double_speed() -> void:
	await _start_combat()
	d.castle().take_damage(2.0)
	await d.press_speed()
	d.castle().heal(1)
	assert_true(d.is_fast())


func test_defeat_disables_it() -> void:
	await _start_combat()
	await d.press_speed()
	d.castle().take_damage(100.0)
	assert_eq(d.result(), "defeat")
	assert_false(d.is_fast())
	assert_true(d.speed_toggle().disabled)
	assert_eq(Engine.time_scale, 1.0)


func test_clearing_the_wave_returns_to_normal() -> void:
	await _start_combat()
	await d.press_speed()
	assert_true(await d.run_until(func() -> bool: return not d.spawns_pending(), 30.0))
	for enemy in d.living_enemies():
		d.hit(enemy, 100.0, Damage.Type.PIERCE)
	assert_true(await d.run_until(func() -> bool: return d.is_preparing(), 5.0))
	assert_true(d.castle().health > 19.9, "no castle damage, so only the wave end stopped it")
	assert_false(d.is_fast())
	assert_true(d.speed_toggle().disabled)
	assert_eq(Engine.time_scale, 1.0)


func test_restart_resets_speed() -> void:
	await _start_combat()
	await d.press_speed()
	await d.restart()
	assert_eq(Engine.time_scale, 1.0)
	assert_false(d.is_fast())
