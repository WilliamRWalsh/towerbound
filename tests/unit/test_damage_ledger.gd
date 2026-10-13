extends GutTest
## Damage committed by projectiles in flight: scaled by resistance, released exactly once.

const BIG_GOBLIN := preload("res://scenes/enemies/big_goblin.tscn")

var enemy: Enemy


func before_each() -> void:
	enemy = autofree(BIG_GOBLIN.instantiate())


func test_commit_scales_by_resistance() -> void:
	var ledger := DamageLedger.new()
	assert_almost_eq(ledger.commit(enemy, 1.5, Damage.Type.PIERCE), 2.25, 0.001)
	assert_almost_eq(ledger.commit(enemy, 3.0, Damage.Type.CRUSH), 1.5, 0.001)
	assert_almost_eq(ledger.incoming(enemy), 3.75, 0.001)


func test_release_clears_the_entry() -> void:
	var ledger := DamageLedger.new()
	var first := ledger.commit(enemy, 1.5, Damage.Type.PIERCE)
	var second := ledger.commit(enemy, 1.5, Damage.Type.PIERCE)
	ledger.release(enemy.get_instance_id(), first)
	assert_almost_eq(ledger.incoming(enemy), second, 0.001)
	assert_false(ledger.is_empty())
	ledger.release(enemy.get_instance_id(), second)
	assert_true(ledger.is_empty())
	assert_eq(ledger.incoming(enemy), 0.0)


func test_release_of_unknown_enemy_is_harmless() -> void:
	var ledger := DamageLedger.new()
	ledger.release(12345, 3.0)
	assert_true(ledger.is_empty())
