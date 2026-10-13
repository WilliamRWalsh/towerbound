extends GutTest
## Enemies: damage types and multipliers, slows and chill, zombie revives, kill rewards, and
## striking the castle gate and barricades.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver
## Enemy instance id → times `died` fired.
var deaths := {}


func before_each() -> void:
	deaths.clear()
	d = Driver.new(self, Driver.make_level([], 999.0))
	await d.advance(0.2)
	d.silence_turrets()


func after_each() -> void:
	Engine.time_scale = 1.0


func _spawn(scene: PackedScene, progress := 400.0) -> Enemy:
	var enemy := d.spawn(scene, progress)
	enemy.died.connect(func(e: Enemy) -> void: deaths[e.get_instance_id()] = deaths.get(e.get_instance_id(), 0) + 1)
	return enemy


func _deaths(enemy: Enemy) -> int:
	return deaths.get(enemy.get_instance_id(), 0)


func test_one_arrow_kills_a_skeleton() -> void:
	var skeleton := _spawn(Driver.SKELETON)
	d.hit(skeleton, 1.5, Damage.Type.PIERCE)
	assert_false(skeleton.is_alive())
	assert_eq(_deaths(skeleton), 1)


func test_two_arrows_kill_a_goblin() -> void:
	var goblin := _spawn(Driver.GOBLIN)
	d.hit(goblin, 1.5, Damage.Type.PIERCE)
	assert_true(goblin.is_alive())
	d.hit(goblin, 1.5, Damage.Type.PIERCE)
	assert_false(goblin.is_alive())


func test_damage_multipliers() -> void:
	var big := _spawn(Driver.BIG_GOBLIN)
	d.hit(big, 1.0, Damage.Type.PIERCE)
	assert_almost_eq(big.health, 8.0 - 1.5, 0.001, "big goblin pierce x1.5")
	d.hit(big, 1.0, Damage.Type.CRUSH)
	assert_almost_eq(big.health, 6.5 - 0.5, 0.001, "big goblin crush x0.5")
	var giant := _spawn(Driver.GIANT)
	d.hit(giant, 2.0, Damage.Type.PIERCE)
	assert_almost_eq(giant.health, 25.0 - 1.0, 0.001, "giant pierce x0.5")
	d.hit(giant, 4.0, Damage.Type.CRUSH)
	assert_almost_eq(giant.health, 24.0 - 5.0, 0.001, "giant crush x1.25")
	var zombie := _spawn(Driver.ZOMBIE)
	d.hit(zombie, 1.0, Damage.Type.FIRE)
	assert_almost_eq(zombie.health, 3.0 - 2.0, 0.001, "zombie fire x2")
	var skeleton := _spawn(Driver.SKELETON)
	d.hit(skeleton, 1.0, Damage.Type.CRUSH)
	assert_almost_eq(skeleton.health, 0.5, 0.001, "skeleton neutral")


func test_damage_after_resistance_matches_damage_taken() -> void:
	var big := _spawn(Driver.BIG_GOBLIN)
	assert_almost_eq(big.damage_after_resistance(1.5, Damage.Type.PIERCE), 2.25, 0.001)
	assert_almost_eq(big.damage_after_resistance(3.0, Damage.Type.CRUSH), 1.5, 0.001)


func test_kill_pays_mana_once() -> void:
	var skeleton := _spawn(Driver.SKELETON)
	var big := _spawn(Driver.BIG_GOBLIN)
	d.hit(skeleton, 5.0, Damage.Type.PIERCE)
	d.hit(skeleton, 5.0, Damage.Type.PIERCE)
	assert_almost_eq(d.mana(), 6.3, 0.001)
	d.hit(big, 20.0, Damage.Type.PIERCE)
	assert_almost_eq(d.mana(), 7.2, 0.001)
	assert_eq(_deaths(skeleton), 1)


func test_mana_is_capped() -> void:
	d.set_mana(9.9)
	var giant := _spawn(Driver.GIANT)
	d.hit(giant, 100.0, Damage.Type.CRUSH)
	assert_eq(d.mana(), 10.0)


func test_chill_slows_and_makes_brittle() -> void:
	var goblin := _spawn(Driver.GOBLIN)
	d.chill(goblin, 5.0)
	assert_true(d.is_chilled(goblin))
	assert_almost_eq(d.speed_multiplier(goblin), 0.5, 0.001)
	assert_almost_eq(goblin.damage_after_resistance(3.0, Damage.Type.CRUSH), 4.5, 0.001)
	assert_almost_eq(goblin.damage_after_resistance(3.0, Damage.Type.PIERCE), 3.0, 0.001)
	await d.advance(4.8)
	assert_true(d.is_chilled(goblin))
	await d.advance(0.4)
	assert_false(d.is_chilled(goblin), "wears off after 5 s")
	assert_almost_eq(d.speed_multiplier(goblin), 1.0, 0.001)
	assert_almost_eq(goblin.damage_after_resistance(3.0, Damage.Type.CRUSH), 3.0, 0.001)


func test_giants_shake_off_chill_twice_as_fast() -> void:
	var giant := _spawn(Driver.GIANT)
	d.chill(giant, 5.0)
	await d.advance(2.3)
	assert_true(d.is_chilled(giant))
	await d.advance(0.4)
	assert_false(d.is_chilled(giant))


func test_strongest_slow_wins() -> void:
	var goblin := _spawn(Driver.GOBLIN)
	d.slow(goblin, 0.6, 10.0)
	assert_almost_eq(d.speed_multiplier(goblin), 0.6, 0.001)
	d.chill(goblin, 2.0)
	assert_almost_eq(d.speed_multiplier(goblin), 0.5, 0.001)
	d.slow(goblin, 0.8, 10.0)
	assert_almost_eq(d.speed_multiplier(goblin), 0.5, 0.001)


func test_slow_moves_the_enemy_slower() -> void:
	var fast := _spawn(Driver.GOBLIN, 300.0)
	var slowed := _spawn(Driver.GOBLIN, 300.0)
	d.slow(slowed, 0.6, 10.0)
	await d.advance(1.0)
	var fast_moved := fast.progress - 300.0
	var slow_moved := slowed.progress - 300.0
	assert_almost_eq(slow_moved / fast_moved, 0.6, 0.03)


func test_zombie_gets_back_up_once() -> void:
	var zombie := _spawn(Driver.ZOMBIE)
	d.hit(zombie, 3.0, Damage.Type.PIERCE)
	assert_false(zombie.is_alive())
	assert_true(d.is_downed(zombie))
	assert_eq(_deaths(zombie), 0)
	assert_eq(d.mana(), 6.0, "no reward for the first fall")
	d.hit(zombie, 3.0, Damage.Type.PIERCE)
	assert_true(d.is_downed(zombie), "can't be hurt while down")
	await d.advance(1.9)
	assert_true(d.is_downed(zombie))
	await d.advance(0.3)
	assert_true(zombie.is_alive(), "stands up about 2 s after falling")
	assert_eq(zombie.health, 3.0)
	var at := zombie.progress
	await d.advance(0.5)
	assert_gt(zombie.progress, at, "walks on")
	d.hit(zombie, 3.0, Damage.Type.PIERCE)
	assert_false(zombie.is_alive())
	assert_false(d.is_downed(zombie))
	assert_eq(_deaths(zombie), 1)
	assert_almost_eq(d.mana(), 6.5, 0.001)


func test_fire_keeps_a_zombie_down() -> void:
	var zombie := _spawn(Driver.ZOMBIE)
	var id := zombie.get_instance_id()
	d.hit(zombie, 2.0, Damage.Type.FIRE)
	assert_false(d.is_downed(zombie))
	assert_eq(deaths.get(id, 0), 1)
	await d.advance(3.0)
	assert_true(not is_instance_valid(zombie) or not zombie.is_alive(), "stays dead")
	assert_eq(deaths.get(id, 0), 1)


func test_strikes_the_gate_on_its_interval() -> void:
	var skeleton := _spawn(Driver.SKELETON, d.road_length() - 90.0)
	var hits: Array[float] = []
	d.castle().health_changed.connect(func(_h: float, _m: int) -> void: hits.append(d.sim_time))
	assert_true(await d.run_until(func() -> bool: return hits.size() >= 4, 15.0))
	assert_true(d.is_at_gate(skeleton))
	assert_almost_eq(d.castle().health, 20.0 - 4 * 0.85, 0.001)
	assert_almost_eq(hits[2] - hits[1], 1.8, 0.05)
	assert_almost_eq(hits[3] - hits[2], 1.8, 0.05)


func test_chill_slows_gate_strikes_from_the_next_swing() -> void:
	_spawn(Driver.SKELETON, d.road_length() - 90.0)
	var hits: Array[float] = []
	d.castle().health_changed.connect(func(_h: float, _m: int) -> void: hits.append(d.sim_time))
	assert_true(await d.run_until(func() -> bool: return hits.size() >= 1, 15.0))
	for enemy in d.living_enemies():
		d.chill(enemy, 60.0)
	assert_true(await d.run_until(func() -> bool: return hits.size() >= 4, 20.0))
	assert_almost_eq(hits[3] - hits[2], 2.7, 0.05)


func test_barricade_stops_enemies_until_broken() -> void:
	var barricade := d.place_barricade(800.0)
	var skeleton := _spawn(Driver.SKELETON, 650.0)
	assert_true(await d.run_until(func() -> bool: return barricade.health < 5.0, 10.0))
	assert_true(d.is_blocked(skeleton))
	assert_almost_eq(barricade.health, 4.15, 0.001)
	assert_lt(skeleton.progress, 800.0)
	assert_true(await d.run_until(func() -> bool: return not barricade.is_standing(), 20.0))
	await d.advance(1.0)
	assert_false(d.is_blocked(skeleton))
	assert_gt(skeleton.progress, 800.0, "walks on past the broken barricade")
	assert_eq(d.castle().health, 20.0)


func test_barricade_does_not_stop_enemies_already_past() -> void:
	var skeleton := _spawn(Driver.SKELETON, 850.0)
	d.place_barricade(800.0)
	await d.advance(1.0)
	assert_false(d.is_blocked(skeleton))
	assert_gt(skeleton.progress, 900.0)
