extends GutTest
## Spells and ground effects: Fireball and its burning ground, Oil Slick slowing and igniting into
## a chain of blazes, Chill, and the caltrops a discarded Barricade leaves.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func after_each() -> void:
	Engine.time_scale = 1.0


func _start(deck: Array) -> void:
	d = Driver.new(self, Driver.make_level(deck, 999.0))
	await d.advance(0.3)
	d.silence_turrets()


func _gone(enemy: Variant) -> bool:
	return not is_instance_valid(enemy) or not enemy.is_alive()


func test_fireball_hits_everything_in_its_radius_once() -> void:
	await _start([Driver.FIREBALL, Driver.CHILL, Driver.OIL, Driver.ARCHER])
	var group: Array[Enemy] = []
	var deaths := {}
	for i in 3:
		var skeleton := d.spawn(Driver.SKELETON, 900.0, (i - 1) * 10.0)
		skeleton.died.connect(func(e: Enemy) -> void: deaths[e.get_instance_id()] = deaths.get(e.get_instance_id(), 0) + 1)
		group.append(skeleton)
	var goblin := d.spawn(Driver.GOBLIN, 400.0)
	# Lead the target: the group walks on while the meteor falls.
	await d.play_card("Fireball", d.road_pos(930.0))
	await d.advance(0.5)
	for skeleton in group:
		assert_true(_gone(skeleton))
	assert_eq(deaths.size(), 3)
	for count in deaths.values():
		assert_eq(count, 1)
	assert_almost_eq(d.mana(), 6.0 - 3.0 + 3 * 0.3, 0.001)
	assert_eq(goblin.health, 3.0, "far away goblin untouched")


func test_fireball_leaves_burning_ground_for_ten_seconds() -> void:
	await _start([Driver.FIREBALL, Driver.CHILL, Driver.OIL, Driver.ARCHER])
	await d.play_card("Fireball", d.road_pos(900.0))
	await d.advance(0.5)
	assert_eq(d.count_in(d.ground_layer(), BurningGround), 1)
	var giant := d.spawn(Driver.GIANT, 840.0)
	await d.advance(2.0)
	assert_lt(giant.health, 25.0, "burns enemies that walk in later")
	assert_gt(giant.health, 22.0)
	await d.advance(8.0)
	assert_eq(d.count_in(d.ground_layer(), BurningGround), 0, "burns out")


func test_oil_slick_snaps_to_the_road_and_slows() -> void:
	await _start([Driver.OIL, Driver.OIL, Driver.CHILL, Driver.ARCHER])
	await d.play_card("Oil Slick", d.cell_pos(d.cell_far_from_road(150.0)))
	assert_eq(d.mana(), 6.0, "off the road")
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 0)
	await d.press_cancel()
	await d.play_card("Oil Slick", d.road_pos(800.0))
	assert_eq(d.mana(), 5.0)
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 1)
	var goblin := d.spawn(Driver.GOBLIN, 790.0)
	await d.advance(0.3)
	assert_almost_eq(d.speed_multiplier(goblin), 0.6, 0.001)
	await d.advance(3.0)
	assert_almost_eq(d.speed_multiplier(goblin), 1.0, 0.001, "back to full speed past the slick")


func test_fire_ignites_oil_and_the_blaze_spreads() -> void:
	await _start([Driver.OIL, Driver.OIL, Driver.FIREBALL, Driver.CHILL])
	# A straight stretch of road: the Fireball reaches the near slick but not the far one, and
	# the near slick's blaze reaches the far one.
	var fire_at := 170.0
	var near := fire_at + 78.0
	var far := fire_at + 183.0
	await d.play_card("Oil Slick", d.road_pos(near))
	await d.play_card("Oil Slick", d.road_pos(far))
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 2)
	await d.play_card("Fireball", d.road_pos(fire_at))
	await d.advance(0.3)
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 1, "the near slick caught")
	assert_eq(d.count_in(d.ground_layer(), BurningGround), 2)
	await d.advance(0.8)
	assert_eq(d.count_in(d.ground_layer(), OilSlick), 0, "the blaze spread to the far slick")
	assert_eq(d.count_in(d.ground_layer(), BurningGround), 3)


func test_oil_blaze_burns_hot() -> void:
	await _start([Driver.OIL, Driver.FIREBALL, Driver.CHILL, Driver.ARCHER])
	await d.play_card("Oil Slick", d.road_pos(900.0))
	var giant := d.spawn(Driver.GIANT, 900.0)
	giant.process_mode = Node.PROCESS_MODE_DISABLED
	await d.play_card("Fireball", d.road_pos(900.0))
	await d.advance(0.3)
	var after_impact := giant.health
	assert_almost_eq(after_impact, 22.0, 0.001, "impact deals 3")
	await d.advance(2.0)
	# Fireball patch (1/s) and oil blaze (2.5/s) together.
	assert_almost_eq(after_impact - giant.health, 7.0, 0.6)


func test_chill_damages_and_chills_an_area() -> void:
	await _start([Driver.CHILL, Driver.OIL, Driver.FIREBALL, Driver.ARCHER])
	var goblin := d.spawn(Driver.GOBLIN, 800.0)
	var far := d.spawn(Driver.GOBLIN, 300.0)
	goblin.process_mode = Node.PROCESS_MODE_DISABLED
	await d.play_card("Chill", goblin.global_position)
	assert_eq(d.mana(), 4.0)
	assert_almost_eq(goblin.health, 2.5, 0.001)
	assert_true(d.is_chilled(goblin))
	assert_false(d.is_chilled(far))
	assert_eq(far.health, 3.0)


func test_caltrops_hurt_the_first_eight_enemies_across() -> void:
	await _start([Driver.BARRICADE, Driver.CHILL, Driver.OIL, Driver.ARCHER])
	await d.press_discard()
	await d.tap_card("Barricade")
	assert_eq(d.count_in(d.ground_layer(), Caltrops), 1)
	var goblins: Array[Enemy] = []
	var start := d.road_length() - 270.0 - 150.0
	for i in 10:
		goblins.append(d.spawn(Driver.GOBLIN, start - i * 12.0, (i % 5 - 2) * 8.0))
	await d.advance(4.0)
	var hurt := goblins.filter(func(g: Enemy) -> bool: return g.health < 3.0).size()
	assert_eq(hurt, 8)
	assert_eq(d.count_in(d.ground_layer(), Caltrops), 0, "used up")
