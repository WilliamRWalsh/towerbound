extends GutTest
## How an enemy's status effects add up: strongest slow, slowest strikes, stacked damage
## multipliers, the longer duration on reapply, and a tint that fades as an effect runs out.

const CHILL := preload("res://data/status/chill.tres")
const OIL := preload("res://data/status/oil_slow.tres")


func test_nothing_on_means_no_change() -> void:
	var statuses := StatusEffects.new()
	assert_eq(statuses.speed_multiplier(), 1.0)
	assert_eq(statuses.strike_interval_multiplier(), 1.0)
	assert_eq(statuses.damage_multiplier(Damage.Type.CRUSH), 1.0)
	assert_eq(statuses.tint().a, 0.0)


func test_strongest_slow_wins() -> void:
	var statuses := StatusEffects.new()
	statuses.apply(OIL, 10.0)
	assert_almost_eq(statuses.speed_multiplier(), 0.6, 0.001)
	statuses.apply(CHILL, 2.0)
	assert_almost_eq(statuses.speed_multiplier(), 0.5, 0.001)
	statuses.tick(2.5)
	assert_almost_eq(statuses.speed_multiplier(), 0.6, 0.001, "back to the oil's slow once chill ends")


func test_chill_slows_strikes_and_makes_brittle() -> void:
	var statuses := StatusEffects.new()
	statuses.apply(CHILL, 5.0)
	assert_eq(statuses.strike_interval_multiplier(), 1.5)
	assert_eq(statuses.damage_multiplier(Damage.Type.CRUSH), 1.5)
	assert_eq(statuses.damage_multiplier(Damage.Type.PIERCE), 1.0)


func test_reapplying_keeps_the_longer_duration() -> void:
	var statuses := StatusEffects.new()
	statuses.apply(CHILL, 5.0)
	statuses.apply(CHILL, 2.0)
	statuses.tick(4.0)
	assert_true(statuses.has(&"chill"))
	statuses.tick(1.1)
	assert_false(statuses.has(&"chill"))


func test_tint_fades_out_at_the_end() -> void:
	var statuses := StatusEffects.new()
	statuses.apply(CHILL, 1.0)
	assert_eq(statuses.tint().a, 1.0)
	statuses.tick(0.8)
	assert_almost_eq(statuses.tint().a, 0.5, 0.01)
	assert_almost_eq(statuses.tint().b, CHILL.tint.b, 0.001)
