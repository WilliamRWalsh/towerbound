extends GutTest
## Towers: ammo charges and reloading across waves, upgrades, and shared targeting that doesn't
## overkill (TargetPlanner).

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver
var arrows := 0


func before_each() -> void:
	arrows = 0
	d = Driver.new(self, Driver.make_level([], 999.0))
	await d.advance(0.2)
	d.silence_turrets()
	d.on_projectile_launched(func(_p: Node) -> void: arrows += 1)


func after_each() -> void:
	Engine.time_scale = 1.0


## Spawns an enemy on the road just short of the point nearest `cell`, so it walks into range.
func _spawn_near(cell: Vector2i, scene: PackedScene = Driver.SKELETON) -> Enemy:
	return d.spawn(scene, maxf(0.0, d.progress_near(d.cell_pos(cell)) - 60.0))


func _until_dead(enemy: Enemy, max_seconds := 6.0) -> bool:
	return await d.run_until(func() -> bool: return not is_instance_valid(enemy) or not enemy.is_alive(), max_seconds)


func test_fire_fire_reload() -> void:
	var near := d.cell_near_road(100.0)
	var far := d.cell_far_from_road(240.0)
	assert_ne(far, Vector2i(-1, -1))
	var tower := d.place_tower(near)
	var idle := d.place_tower(far)
	assert_eq(d.charges_left(tower), 2)
	# Wave 1: fires, spends one charge.
	d.begin_wave()
	assert_true(await _until_dead(_spawn_near(near, Driver.GOBLIN)))
	assert_eq(d.charges_left(tower), 1)
	d.end_wave()
	assert_false(d.is_reloading(tower))
	# Wave 2: spends its last charge, but keeps firing until the wave ends.
	d.begin_wave()
	assert_true(await _until_dead(_spawn_near(near)))
	assert_eq(d.charges_left(tower), 0)
	var before := arrows
	assert_true(await _until_dead(_spawn_near(near)))
	assert_gt(arrows, before, "still firing on its last charge")
	d.end_wave()
	assert_true(d.is_reloading(tower))
	# Wave 3: sits out reloading.
	d.begin_wave()
	before = arrows
	_spawn_near(near)
	await d.advance(3.0)
	assert_eq(arrows, before, "no shots while reloading")
	d.end_wave()
	assert_false(d.is_reloading(tower))
	assert_eq(d.charges_left(tower), 2)
	# The tower out of reach never fired and kept its charges.
	assert_eq(d.charges_left(idle), 2)
	assert_false(d.is_reloading(idle))


func test_tower_placed_mid_wave_spends_a_charge_on_its_first_shot() -> void:
	d.begin_wave()
	var near := d.cell_near_road(100.0)
	var tower := d.place_tower(near)
	assert_true(await _until_dead(_spawn_near(near)))
	assert_eq(d.charges_left(tower), 1)


func test_rate_upgrade() -> void:
	var tower := d.place_tower(d.cell_near_road(100.0))
	assert_eq(d.fire_interval(tower), 1.0)
	assert_true(d.upgrade_rate(tower))
	assert_almost_eq(d.fire_interval(tower), 0.667, 0.001)
	assert_false(d.upgrade_rate(tower), "only once")


func test_ammo_upgrade_on_a_tower_that_just_ran_dry() -> void:
	var near := d.cell_near_road(100.0)
	var tower := d.place_tower(near)
	for wave in 2:
		d.begin_wave()
		assert_true(await _until_dead(_spawn_near(near)))
		if wave == 0:
			d.end_wave()
	assert_eq(d.charges_left(tower), 0)
	assert_true(d.upgrade_ammo(tower))
	assert_eq(d.max_charges(tower), 3)
	assert_eq(d.charges_left(tower), 1)
	d.end_wave()
	assert_false(d.is_reloading(tower), "the new charge saves it from reloading")
	assert_false(d.upgrade_ammo(tower), "only once")


func test_ammo_upgrade_on_a_reloading_tower() -> void:
	var near := d.cell_near_road(100.0)
	var tower := d.place_tower(near)
	for wave in 2:
		d.begin_wave()
		assert_true(await _until_dead(_spawn_near(near)))
		d.end_wave()
	assert_true(d.is_reloading(tower))
	assert_true(d.upgrade_ammo(tower))
	assert_eq(d.charges_left(tower), 0)
	d.begin_wave()
	d.end_wave()
	assert_eq(d.charges_left(tower), 3)
	assert_false(d.is_reloading(tower))


func test_cannon_tower_stats() -> void:
	var tower := d.place_tower(d.cell_near_road(100.0), Driver.CANNON)
	assert_true(tower is CannonTower)
	assert_eq(d.fire_interval(tower), 2.0)


## Three Archer Towers around one road point.
func _ring_of_archers() -> Vector2i:
	var cells := d.buildable_cells()
	var best := Vector2i(-1, -1)
	for cell in cells:
		if d.distance_to_road(d.cell_pos(cell)) < 100.0:
			best = cell
			break
	assert_ne(best, Vector2i(-1, -1))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return d.cell_pos(a).distance_to(d.cell_pos(best)) < d.cell_pos(b).distance_to(d.cell_pos(best)))
	for cell in cells.slice(0, 3):
		d.place_tower(cell)
	return best


func test_no_overkill_skeleton_takes_one_arrow() -> void:
	var center := _ring_of_archers()
	assert_true(await _until_dead(_spawn_near(center, Driver.SKELETON)))
	await d.advance(1.0)
	assert_eq(arrows, 1)
	assert_true(d.ledger_is_empty())


func test_no_overkill_goblin_takes_two_arrows() -> void:
	var center := _ring_of_archers()
	assert_true(await _until_dead(_spawn_near(center, Driver.GOBLIN)))
	await d.advance(1.0)
	assert_eq(arrows, 2)
	assert_true(d.ledger_is_empty())


func test_no_overkill_on_a_stream_of_skeletons() -> void:
	var center := _ring_of_archers()
	var start := maxf(0.0, d.progress_near(d.cell_pos(center)) - 200.0)
	var skeletons: Array[Enemy] = []
	for i in 6:
		skeletons.append(d.spawn(Driver.SKELETON, start - i * 40.0))
	assert_true(await d.run_until(func() -> bool:
		return skeletons.all(func(s: Variant) -> bool: return not is_instance_valid(s) or not s.is_alive()), 15.0))
	await d.advance(1.0)
	assert_eq(arrows, 6)
	assert_true(d.ledger_is_empty())


func test_holds_fire_on_an_enemy_the_burn_will_finish() -> void:
	var center := _ring_of_archers()
	var goblin := _spawn_near(center, Driver.GOBLIN)
	goblin.progress += 40.0
	d.hit(goblin, 2.5)
	d.ignite_ground(goblin.global_position, 260.0, 1.0, 4.0)
	assert_true(await _until_dead(goblin))
	assert_eq(arrows, 0)


func test_counts_the_burn_with_its_own_arrow() -> void:
	var center := _ring_of_archers()
	var goblin := _spawn_near(center, Driver.GOBLIN)
	goblin.progress += 40.0
	d.ignite_ground(goblin.global_position, 260.0, 1.0, 6.0)
	assert_true(await _until_dead(goblin))
	assert_eq(arrows, 1)


func test_ledger_is_clear_after_a_restart_with_arrows_in_flight() -> void:
	var center := _ring_of_archers()
	for i in 5:
		_spawn_near(center, Driver.GIANT)
	assert_true(await d.run_until(func() -> bool: return arrows >= 3, 6.0))
	assert_false(d.ledger_is_empty())
	await d.restart()
	assert_true(d.ledger_is_empty())
