class_name Enemy
extends PathFollow2D
## An enemy walking the enemy path; its look comes from the EnemyBody child and its numbers from
## `stats`. Dies once at zero health. A standing barricade in its way stops it, and at the end of
## the path it stops at the castle gate; either way it strikes what stopped it every
## `stats.attack_interval` until it is killed, or until the barricade breaks and it walks on.
## Drops out of play (`in_play`) the moment it dies or the battle halts, so towers and projectiles
## ignore it from then on.
## Enemies with `stats.revives` (zombies) fall DOWNED instead of dying and get back up after
## `stats.revive_delay`; only the final death emits `died`. A downed enemy stays in play so a
## battle halt still reaches it, but `is_alive` is false, so nothing can target or hurt it.
## Hits are scaled by `stats` and by any status effects (Chill makes it brittle against crush);
## a killing hit of one of `stats.final_death_types` keeps a reviving enemy down for good.

signal died(enemy: Enemy)

enum State { WALKING, ATTACKING, DOWNED, DYING, HALTED }

## Map pixels walked per radian of walk cycle.
const STRIDE := 4.5
## Only turn around when moving at least this much sideways, so near-vertical stretches
## don't flicker between facings.
const TURN_THRESHOLD := 0.3
## Enemies stop up to this many map pixels short of the gate so a crowd doesn't stack exactly.
const GATE_CROWD := 60.0
## Enemies stop this far short of a barricade, plus up to BARRICADE_CROWD more.
const BARRICADE_REACH := 22.0
const BARRICADE_CROWD := 40.0
## Seconds one full swing takes (raise, hold, strike, recover); the rest of the attack interval
## is spent waiting.
const SWING_TIME := 0.97
## Hit flash colors for weaknesses (a bright pop) and resistances (a dull clink).
const WEAK_FLASH := Color(1.0, 0.85, 0.35)
const RESIST_FLASH := Color(0.55, 0.57, 0.6)

@export var stats: EnemyStats
## Walk cycle speed relative to distance; short legs take quicker steps.
@export var stride_scale := 1.0

var state := State.WALKING
var health := 0.0
## The battlefield it walks on; set when spawned.
var world: Battlefield
var statuses := StatusEffects.new()

var _stop_ratio := 1.0
var _barricade_gap := BARRICADE_REACH
var _swing: Tween
## What it is striking while ATTACKING: the castle or a barricade. Both have `take_damage` and
## `is_standing`.
var _attack_target: Node2D
var _revive: Tween
var _revives_left := 0

@onready var _body: EnemyBody = $Body


func _ready() -> void:
	health = stats.max_health
	_revives_left = stats.revives
	var length := (get_parent() as Path2D).curve.get_baked_length()
	_stop_ratio = 1.0 - randf_range(0.0, GATE_CROWD) / maxf(1.0, length)
	_barricade_gap = BARRICADE_REACH + randf_range(0.0, BARRICADE_CROWD)


## True while it can still be targeted and hurt: walking, or striking the gate or a barricade.
func is_alive() -> bool:
	return state == State.WALKING or state == State.ATTACKING


## True until it dies for good or the battle halts it; a downed zombie is still in play.
func in_play() -> bool:
	return state != State.DYING and state != State.HALTED


## True while it stands at the castle gate.
func is_at_gate() -> bool:
	return state == State.ATTACKING and _attack_target is Castle


## True while a barricade has it stopped.
func is_blocked() -> bool:
	return state == State.ATTACKING and _attack_target is Barricade


func is_downed() -> bool:
	return state == State.DOWNED


## Canvas position projectiles aim for.
func aim_point() -> Vector2:
	return _body.to_global(Vector2(0, -_body.chest_height))


func has_status(id: StringName) -> bool:
	return statuses.has(id)


## Damage it would take from `amount` of `type`, after its resistances and status effects.
func damage_after_resistance(amount: float, type: int) -> float:
	return amount * stats.multiplier(type) * statuses.damage_multiplier(type)


func take_hit(hit: Hit) -> void:
	if not is_alive():
		return
	var multiplier := damage_after_resistance(1.0, hit.type)
	health -= hit.amount * multiplier
	_body.health_ratio = health / stats.max_health
	if multiplier > 1.01:
		_body.flash_color = WEAK_FLASH
	elif multiplier < 0.99:
		_body.flash_color = RESIST_FLASH
	else:
		_body.flash_color = Color.WHITE
	_body.flash = 1.0
	create_tween().tween_property(_body, "flash", 0.0, 0.18)
	var wobble := create_tween()
	wobble.tween_property(_body, "rotation", -0.14 * _body.scale.x, 0.05)
	wobble.tween_property(_body, "rotation", 0.0, 0.12)
	if health <= 0.001:
		if _revives_left > 0 and not stats.final_death_types.has(hit.type):
			_go_down()
		else:
			_die()


## Freezes the enemy in place when the battle ends; it can no longer be hurt or strike.
func halt() -> void:
	if state == State.DYING:
		return
	state = State.HALTED
	_stop_swing()
	if _revive:
		# Stays on the ground for good.
		_revive.kill()
		_revive = null
		create_tween().tween_property(_body, "death", 1.0, 0.3)


## Puts `effect` on the enemy for `duration` seconds, scaled by its resistance to the effect's
## element if the effect is resistible.
func apply_status(effect: StatusEffect, duration: float) -> void:
	if not is_alive():
		return
	if effect.resistible:
		duration *= stats.multiplier(effect.element)
	statuses.apply(effect, duration)


## Current walking speed multiplier from status effects.
func speed_multiplier() -> float:
	return statuses.speed_multiplier()


func _process(delta: float) -> void:
	_tick_statuses(delta)
	if state == State.ATTACKING and not _attack_target.is_standing():
		_resume_walking()
	if state != State.WALKING:
		return
	var before := position
	var start := progress
	progress += Units.px(stats.speed * speed_multiplier()) * delta
	var barricade := _barricade_ahead(start)
	if barricade:
		progress = maxf(start, barricade.progress - _barricade_gap)
		_attack(barricade)
		return
	var moved := position - before
	if absf(moved.x) > moved.length() * TURN_THRESHOLD:
		_body.scale.x = signf(moved.x) * absf(_body.scale.x)
	_body.walk_phase += moved.length() / (STRIDE * stride_scale)
	_body.weapon_angle = EnemyBody.WEAPON_REST + sin(_body.walk_phase) * 0.2
	if progress_ratio >= _stop_ratio:
		_attack(world.castle)


func _tick_statuses(delta: float) -> void:
	statuses.tick(delta)
	var tint := statuses.tint()
	if not is_equal_approx(_body.tint, tint.a):
		_body.tint = tint.a
	if tint.a > 0.0:
		_body.tint_color = Color(tint, 1.0)


func _die() -> void:
	state = State.DYING
	_stop_swing()
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_body, "death", 1.0, 0.55)
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)


## Collapses like a death but without `died`, lies still, twitches, and stands back up
## `revive_delay` seconds after falling, at full health, and carries on walking or striking.
func _go_down() -> void:
	_revives_left -= 1
	state = State.DOWNED
	_stop_swing()
	_revive = create_tween()
	_revive.tween_property(_body, "death", 1.0, 0.55)
	_revive.tween_interval(maxf(0.0, stats.revive_delay - 1.65))
	for i in 3:
		_revive.tween_property(_body, "death", 0.9, 0.08)
		_revive.tween_property(_body, "death", 1.0, 0.12)
	_revive.tween_property(_body, "death", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_revive.tween_callback(_get_up)


func _get_up() -> void:
	_revive = null
	if state != State.DOWNED:
		return
	health = stats.max_health
	_body.health_ratio = 1.0
	_body.risen = true
	if _attack_target and _attack_target.is_standing():
		state = State.ATTACKING
		_start_swing()
	else:
		_attack_target = null
		state = State.WALKING


## The nearest standing barricade it has walked up to: one it hadn't passed yet, now within its
## stopping gap.
func _barricade_ahead(start: float) -> Barricade:
	var nearest: Barricade = null
	for barricade in world.barricades.standing():
		if barricade.progress <= start or progress + _barricade_gap < barricade.progress:
			continue
		if nearest == null or barricade.progress < nearest.progress:
			nearest = barricade
	return nearest


## Stops walking and starts striking `target` (the castle or a barricade).
func _attack(target: Node2D) -> void:
	state = State.ATTACKING
	_attack_target = target
	var settle := create_tween()
	settle.tween_property(_body, "walk_phase", 0.0, 0.12)
	_start_swing()


func _resume_walking() -> void:
	_stop_swing()
	_attack_target = null
	_body.weapon_angle = EnemyBody.WEAPON_REST
	state = State.WALKING


## One chop: raise, strike (dealing damage once), recover, and wait out the rest of the attack
## interval (longer if a status slows strikes when the swing starts) before the next swing.
func _start_swing() -> void:
	_swing = create_tween()
	_swing.tween_property(_body, "weapon_angle", EnemyBody.SWING_RAISED, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing.tween_interval(0.12)
	_swing.tween_property(_body, "weapon_angle", EnemyBody.SWING_STRUCK, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.parallel().tween_property(_body, "swoosh", 1.0, 0.1)
	_swing.tween_callback(_strike)
	_swing.tween_property(_body, "swoosh", 0.0, 0.2)
	_swing.tween_property(_body, "weapon_angle", EnemyBody.WEAPON_REST, 0.25)
	var interval := stats.attack_interval * statuses.strike_interval_multiplier()
	_swing.tween_interval(maxf(0.0, interval - SWING_TIME))
	_swing.tween_callback(_start_swing)


func _strike() -> void:
	if state == State.ATTACKING and _attack_target.is_standing():
		_attack_target.take_damage(stats.strike_damage)


func _stop_swing() -> void:
	if _swing:
		_swing.kill()
		_swing = null
	_body.swoosh = 0.0
