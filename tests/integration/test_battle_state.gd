extends GutTest
## The battle's one authoritative state: preparation, combat, then exactly one result.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func after_each() -> void:
	Engine.time_scale = 1.0


## A level of `wave_count` waves, each sending `per_wave` skeletons right after a short preparation.
func _small_level(wave_count: int, per_wave: int) -> LevelConfig:
	var level := Driver.make_level([], 0.5)
	var waves: Array[WaveConfig] = []
	for w in wave_count:
		var group := WaveGroup.new()
		group.pause_before = 0.1
		group.spacing = 0.1
		var enemies: Array[PackedScene] = []
		for i in per_wave:
			enemies.append(Driver.SKELETON)
		group.enemies = enemies
		var wave := WaveConfig.new()
		var groups: Array[WaveGroup] = [group]
		wave.groups = groups
		waves.append(wave)
	level.waves = waves
	return level


func _kill_everything() -> void:
	for enemy in d.living_enemies():
		d.hit(enemy, 100.0, Damage.Type.PIERCE)


func test_phases_run_in_order() -> void:
	d = Driver.new(self, _small_level(2, 2))
	var events: Array[String] = []
	var battle := d.battle()
	battle.combat_started.connect(func(n: int) -> void: events.append("combat %d" % n))
	battle.wave_cleared.connect(func(n: int) -> void: events.append("cleared %d" % n))
	battle.preparation_started.connect(func(n: int, _w: WaveConfig) -> void: events.append("prepare %d" % n))
	battle.ended.connect(func(r: Battle.State) -> void: events.append("ended %s" % Battle.State.keys()[r]))
	await d.advance(0.1)
	d.silence_turrets()
	for wave in 2:
		assert_true(await d.run_until(func() -> bool: return not d.spawns_pending() and d.is_fighting(), 3.0))
		await d.advance(0.1)
		_kill_everything()
		await d.advance(0.1)
	assert_eq(events, ["combat 1", "cleared 1", "prepare 2", "combat 2", "cleared 2", "ended VICTORY"] as Array[String])
	assert_eq(d.result(), "victory")


func test_a_wave_waits_for_survivors() -> void:
	d = Driver.new(self, _small_level(2, 3))
	await d.advance(0.1)
	d.silence_turrets()
	assert_true(await d.run_until(func() -> bool: return not d.spawns_pending() and d.is_fighting(), 3.0))
	var survivor := d.living_enemies()[0]
	for enemy in d.living_enemies():
		if enemy != survivor:
			d.hit(enemy, 100.0)
	await d.advance(5.0)
	assert_true(d.is_fighting(), "still fighting with one enemy left")
	assert_eq(d.wave_number(), 1)
	d.hit(survivor, 100.0)
	await d.advance(0.1)
	assert_true(d.is_preparing())
	assert_eq(d.wave_number(), 2)


func test_defeat_is_final() -> void:
	d = Driver.new(self, _small_level(1, 3))
	await d.advance(0.1)
	d.silence_turrets()
	assert_true(await d.run_until(func() -> bool: return not d.spawns_pending() and d.is_fighting(), 3.0))
	watch_signals(d.battle())
	d.castle().take_damage(100.0)
	assert_eq(d.result(), "defeat")
	# Nothing alive can be killed any more, so the last wave can't turn into a victory.
	_kill_everything()
	d.battle().defeat()
	await d.advance(1.0)
	assert_eq(d.result(), "defeat")
	assert_signal_emit_count(d.battle(), "ended", 1)
	assert_signal_not_emitted(d.battle(), "wave_cleared")


func test_no_kill_reward_after_the_result() -> void:
	d = Driver.new(self, Driver.make_level([], 999.0))
	await d.advance(0.1)
	var skeleton := d.spawn(Driver.SKELETON, 400.0)
	d.castle().take_damage(100.0)
	var mana := d.mana()
	d.hit(skeleton, 100.0)
	assert_eq(d.mana(), mana)
