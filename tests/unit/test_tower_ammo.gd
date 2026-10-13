extends GutTest
## Tower charges: one per wave fired in, reload after the last, unlimited when capacity is 0.


func _fire_wave(ammo: TowerAmmo, shots := 1) -> void:
	ammo.begin_wave()
	for i in shots:
		if ammo.can_fire():
			ammo.note_shot()
	ammo.end_wave()


func test_fire_fire_reload() -> void:
	var ammo := TowerAmmo.new(2)
	_fire_wave(ammo, 3)
	assert_eq(ammo.left, 1, "several shots in one wave spend one charge")
	_fire_wave(ammo)
	assert_eq(ammo.left, 0)
	assert_true(ammo.reloading)
	ammo.begin_wave()
	assert_false(ammo.can_fire(), "sits out the next wave")
	ammo.end_wave()
	assert_false(ammo.reloading)
	assert_eq(ammo.left, 2)


func test_keeps_firing_on_its_last_charge_until_the_wave_ends() -> void:
	var ammo := TowerAmmo.new(1)
	ammo.begin_wave()
	ammo.note_shot()
	assert_eq(ammo.left, 0)
	assert_true(ammo.can_fire())


func test_a_wave_without_shots_keeps_the_charge() -> void:
	var ammo := TowerAmmo.new(2)
	_fire_wave(ammo, 0)
	assert_eq(ammo.left, 2)


func test_spent_fires_once_per_wave() -> void:
	var ammo := TowerAmmo.new(2)
	watch_signals(ammo)
	_fire_wave(ammo, 4)
	assert_signal_emit_count(ammo, "spent", 1)


func test_extra_capacity_counts_now_unless_reloading() -> void:
	var ammo := TowerAmmo.new(2)
	_fire_wave(ammo)
	ammo.add_capacity(1)
	assert_eq(ammo.capacity, 3)
	assert_eq(ammo.left, 2)
	var reloading := TowerAmmo.new(1)
	_fire_wave(reloading)
	assert_true(reloading.reloading)
	reloading.add_capacity(1)
	assert_eq(reloading.left, 0)
	reloading.begin_wave()
	reloading.end_wave()
	assert_eq(reloading.left, 2)


func test_unlimited() -> void:
	var ammo := TowerAmmo.new(0)
	assert_true(ammo.is_unlimited())
	_fire_wave(ammo, 5)
	_fire_wave(ammo, 5)
	assert_true(ammo.can_fire())
	assert_false(ammo.reloading)


func test_upgrade_labels_follow_their_numbers() -> void:
	var rate := RateUpgrade.new()
	rate.attack_rate_bonus = 0.25
	assert_eq(rate.label(), "Rate of Fire\n+25% speed")
	var more := AmmoUpgrade.new()
	more.extra_charges = 2
	assert_eq(more.label(), "Ammo\n+2 charges")
	assert_eq(load("res://data/upgrades/ammo.tres").label(), "Ammo\n+1 charge")
