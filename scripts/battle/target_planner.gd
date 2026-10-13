class_name TargetPlanner
extends RefCounted
## Shared targeting for every tower on a battlefield, so towers don't overkill. An enemy whose
## damage already in flight (the DamageLedger) plus what ground effects (burning ground) will deal
## it in the next moment covers its health is "doomed": towers skip it for the next enemy, and
## hold fire when everything in range is doomed. Only projectile commitments are stored, and they
## always resolve, so a wrong prediction corrects itself on the next query.

## Seconds of upcoming damage from ground effects counted as certain.
const HORIZON := 1.5

var _enemies: EnemyRegistry
var _ledger: DamageLedger
## The layer holding ground effects.
var _ground: Node2D


func _init(enemies: EnemyRegistry, ledger: DamageLedger, ground: Node2D) -> void:
	_enemies = enemies
	_ledger = ledger
	_ground = ground


## True when damage already in flight or about to burn will finish it.
func is_doomed(enemy: Enemy) -> bool:
	return _ledger.incoming(enemy) + predicted_area_damage(enemy, HORIZON) >= enemy.health - 0.001


## The living enemy within `reach` of `from` (map pixels) furthest along the path that isn't
## already doomed, or null.
func pick_target(from: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	for enemy in _enemies.living():
		if _enemies.map_position(enemy).distance_to(from) > reach:
			continue
		if best != null and enemy.progress <= best.progress:
			continue
		if not is_doomed(enemy):
			best = enemy
	return best


## Damage `enemy` will take from every ground effect over the next `horizon` seconds. Effects
## predict with `future_position`; barricades and later slows are ignored, so this only ever
## under-predicts.
func predicted_area_damage(enemy: Enemy, horizon: float) -> float:
	var total := 0.0
	for effect in _ground.get_children():
		if effect is AreaEffect:
			total += effect.predicted_damage_to(enemy, horizon)
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
