extends GutTest
## Castle health: fractional damage, capped repairs, and falling exactly once.

var castle: Castle


func before_each() -> void:
	castle = Castle.new()
	add_child_autofree(castle)
	castle.reset(20)


func test_starts_full() -> void:
	assert_eq(castle.health, 20.0)
	assert_true(castle.is_full())
	assert_false(castle.is_destroyed())


func test_takes_fractional_damage() -> void:
	for i in 7:
		castle.take_damage(0.85)
	assert_almost_eq(castle.health, 14.05, 0.001)


func test_reports_health_changes() -> void:
	watch_signals(castle)
	castle.take_damage(2.0)
	assert_signal_emitted_with_parameters(castle, "health_changed", [18.0, 20])


func test_falls_once_at_zero() -> void:
	watch_signals(castle)
	for i in 30:
		castle.take_damage(0.85)
	assert_true(castle.is_destroyed())
	assert_eq(castle.health, 0.0)
	assert_signal_emit_count(castle, "destroyed", 1)


func test_repair_is_capped_and_refused_when_full() -> void:
	assert_false(castle.heal(5), "full castle refuses a repair")
	castle.take_damage(7.0)
	assert_true(castle.heal(5))
	assert_eq(castle.health, 18.0)
	assert_true(castle.heal(5))
	assert_eq(castle.health, 20.0)


func test_fallen_castle_cannot_be_repaired_or_hurt() -> void:
	castle.take_damage(25.0)
	watch_signals(castle)
	assert_false(castle.heal(5))
	castle.take_damage(1.0)
	assert_eq(castle.health, 0.0)
	assert_signal_not_emitted(castle, "destroyed")
