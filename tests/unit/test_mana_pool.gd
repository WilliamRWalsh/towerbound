extends GutTest
## Mana: capped, snapped to hundredths, spent only when affordable.


func test_starts_at_the_given_value() -> void:
	var mana := ManaPool.new(6.0, 10.0)
	assert_eq(mana.value, 6.0)
	assert_eq(mana.max_value, 10.0)


func test_spend_only_when_affordable() -> void:
	var mana := ManaPool.new(3.0, 10.0)
	assert_true(mana.spend(2.0))
	assert_eq(mana.value, 1.0)
	assert_false(mana.spend(2.0))
	assert_eq(mana.value, 1.0)


func test_tenths_add_up_to_whole_costs() -> void:
	var mana := ManaPool.new(0.0, 10.0)
	for i in 30:
		mana.add(0.1)
	assert_true(mana.can_afford(3))
	assert_true(mana.spend(3))
	assert_eq(mana.value, 0.0)


func test_capped_at_max() -> void:
	var mana := ManaPool.new(9.5, 10.0)
	assert_almost_eq(mana.room_for(3.0), 0.5, 0.001)
	mana.add(3.0)
	assert_eq(mana.value, 10.0)
	assert_eq(mana.room_for(1.0), 0.0)


func test_never_negative() -> void:
	var mana := ManaPool.new(1.0, 10.0)
	mana.value = -4.0
	assert_eq(mana.value, 0.0)


func test_reports_changes() -> void:
	var mana := ManaPool.new(5.0, 10.0)
	watch_signals(mana)
	mana.spend(2.0)
	assert_signal_emitted_with_parameters(mana, "changed", [3.0])
