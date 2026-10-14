extends GutTest
## Each wave pays a fixed total of mana, split between its enemies by reward weight, so killing
## every enemy pays exactly that total.

const Driver := preload("res://tests/support/battle_driver.gd")

var d: Driver


func after_each() -> void:
	Engine.time_scale = 1.0


## Starts a battle whose first wave is the woodland's wave `number`, with no mana.
func _start_at_wave(number: int) -> WaveConfig:
	var level := Driver.make_level([], 999.0)
	var wave: WaveConfig = level.waves[number - 1]
	level.waves = [wave] as Array[WaveConfig]
	d = Driver.new(self, level)
	await d.advance(0.2)
	d.silence_turrets()
	d.set_mana(0.0)
	return wave


func _kill_every_enemy(wave: WaveConfig) -> void:
	for entry in wave.enemy_counts():
		for i in entry[1]:
			var enemy := d.spawn(entry[0], 400.0)
			d.hit(enemy, 1000.0, Damage.Type.FIRE)


func test_clearing_wave_one_pays_three() -> void:
	_kill_every_enemy(await _start_at_wave(1))
	assert_almost_eq(d.mana(), 3.0, 0.001)


func test_clearing_wave_ten_pays_seven() -> void:
	_kill_every_enemy(await _start_at_wave(10))
	assert_almost_eq(d.mana(), 7.0, 0.001)
