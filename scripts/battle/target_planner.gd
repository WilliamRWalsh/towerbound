class_name TargetPlanner
extends RefCounted
## Shared targeting for every tower, so towers don't overkill. Keeps a ledger of damage already
## on its way in projectiles, and predicts the burn damage each enemy will take from burning
## ground in the next moment. An enemy whose expected damage covers its health is "doomed":
## towers skip it for the next enemy, and hold fire when everything in range is doomed.
## Nothing is cached except projectile commitments, which always resolve when the projectile
## hits or lands, so a wrong prediction corrects itself on the next query.

## Seconds of upcoming burn ticks counted as certain damage.
const BURN_HORIZON := 1.5

## Enemy instance id → damage (after resistance) committed by projectiles in flight.
static var _incoming: Dictionary = {}


## Records a projectile fired at `enemy`. Returns the committed amount, which the projectile hands
## back to `release` exactly once when it hits, lands, or leaves the tree.
static func commit(enemy: Enemy, amount: float, type: int) -> float:
	var scaled := enemy.damage_after_resistance(amount, type)
	var id := enemy.get_instance_id()
	_incoming[id] = _incoming.get(id, 0.0) + scaled
	return scaled


static func release(enemy_id: int, amount: float) -> void:
	if not _incoming.has(enemy_id):
		return
	var left: float = _incoming[enemy_id] - amount
	if left <= 0.001:
		_incoming.erase(enemy_id)
	else:
		_incoming[enemy_id] = left


## Damage committed to `enemy` by projectiles still in flight.
static func incoming(enemy: Enemy) -> float:
	return _incoming.get(enemy.get_instance_id(), 0.0)


## True when damage already in flight or about to burn will finish it.
static func is_doomed(enemy: Enemy) -> bool:
	return incoming(enemy) + predicted_burn(enemy, BURN_HORIZON) >= enemy.health - 0.001


## The living, in-range enemy furthest along the path that isn't already doomed, or null.
## `reach` is a canvas distance from `from_global`.
static func pick_target(tree: SceneTree, from_global: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	for enemy: Enemy in tree.get_nodes_in_group(Enemy.GROUP):
		if not enemy.is_alive() or from_global.distance_to(enemy.global_position) > reach:
			continue
		if best != null and enemy.progress <= best.progress:
			continue
		if not is_doomed(enemy):
			best = enemy
	return best


## Burn damage `enemy` will take from every burning patch over the next `horizon` seconds, assuming
## a walking enemy keeps its current speed along the path and a striking one stays put. Barricades
## and later slows are ignored, so this only ever under-predicts.
static func predicted_burn(enemy: Enemy, horizon: float) -> float:
	var patches := enemy.get_tree().get_nodes_in_group(BurningGround.GROUP)
	if patches.is_empty():
		return 0.0
	var total := 0.0
	var fire := enemy.damage_after_resistance(1.0, Damage.Type.FIRE)
	for patch: BurningGround in patches:
		for t in patch.upcoming_ticks(horizon):
			if patch.contains(future_position(enemy, t)):
				total += patch.tick_damage() * fire
	return total


## Where `enemy` will be in `seconds`, keeping its sideways offset from the path.
static func future_position(enemy: Enemy, seconds: float) -> Vector2:
	if enemy.state != Enemy.State.WALKING:
		return enemy.global_position
	var path := enemy.get_parent() as Path2D
	var curve := path.curve
	var offset := enemy.global_position - path.to_global(curve.sample_baked(enemy.progress))
	var step := Units.px(enemy.stats.speed * enemy.speed_multiplier()) * seconds
	var ahead := minf(enemy.progress + step, curve.get_baked_length())
	return path.to_global(curve.sample_baked(ahead)) + offset
