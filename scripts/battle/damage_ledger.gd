class_name DamageLedger
extends RefCounted
## Damage already on its way to each enemy in projectiles, so towers can tell when an enemy is
## as good as dead. A projectile commits its damage when launched and releases it exactly once,
## when it hits, lands, or leaves the tree. One ledger per battlefield, so nothing outlives the
## battle that recorded it.

## Enemy instance id → committed damage, after the enemy's resistances.
var _incoming: Dictionary[int, float] = {}


## Records damage fired at `enemy`. Returns the committed amount, which the projectile hands back
## to `release`.
func commit(enemy: Enemy, amount: float, type: int) -> float:
	var scaled := enemy.damage_after_resistance(amount, type)
	var id := enemy.get_instance_id()
	_incoming[id] = _incoming.get(id, 0.0) + scaled
	return scaled


func release(enemy_id: int, amount: float) -> void:
	if not _incoming.has(enemy_id):
		return
	var left: float = _incoming[enemy_id] - amount
	if left <= 0.001:
		_incoming.erase(enemy_id)
	else:
		_incoming[enemy_id] = left


## Damage committed to `enemy` by projectiles still in flight.
func incoming(enemy: Enemy) -> float:
	return _incoming.get(enemy.get_instance_id(), 0.0)


func is_empty() -> bool:
	return _incoming.is_empty()
