class_name Enemy
extends PathFollow2D
## An enemy walking the enemy path; its look comes from the EnemyBody child and its numbers from
## `stats`. Dies once at zero health. At the end of the path it stands at the castle gate and
## keeps striking it every `stats.attack_interval` until it is killed. A standing barricade in its
## way stops it the same way until the barricade breaks. Leaves the "enemies" group
## the moment it dies or the battle halts, so towers and projectiles ignore it from then on.
## Enemies with `stats.revives` (zombies) fall DOWNED instead of dying and get back up after
## `stats.revive_delay`; only the final death emits `died`. A downed enemy stays in the group so
## a battle halt still reaches it, but `is_alive` is false, so nothing can target or hurt it.

signal died(enemy: Enemy)
signal attacked_castle(enemy: Enemy, damage: float)

enum State { WALKING, ATTACKING, BLOCKED, DOWNED, DYING, HALTED }

const GROUP := "enemies"
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

@export var stats: EnemyStats
## Walk cycle speed relative to distance; short legs take quicker steps.
@export var stride_scale := 1.0

var state := State.WALKING
var health := 0.0

var _stop_ratio := 1.0
var _barricade_gap := BARRICADE_REACH
var _swing: Tween
## The barricade it is breaking while BLOCKED.
var _blocker: Barricade
var _revive: Tween
var _revives_left := 0
## Whether it had reached the gate, so it goes back to striking after getting up.
var _at_gate := false

@onready var _body: EnemyBody = $Body


func _ready() -> void:
	health = stats.max_health
	_revives_left = stats.revives
	add_to_group(GROUP)
	var length := (get_parent() as Path2D).curve.get_baked_length()
	_stop_ratio = 1.0 - randf_range(0.0, GATE_CROWD) / maxf(1.0, length)
	_barricade_gap = BARRICADE_REACH + randf_range(0.0, BARRICADE_CROWD)


## True while it can still be targeted and hurt: walking or attacking the gate or a barricade.
func is_alive() -> bool:
	return state == State.WALKING or state == State.ATTACKING or state == State.BLOCKED


## Canvas position projectiles aim for.
func aim_point() -> Vector2:
	return _body.to_global(Vector2(0, -_body.chest_height))


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	health -= amount
	_body.health_ratio = health / stats.max_health
	_body.flash = 1.0
	create_tween().tween_property(_body, "flash", 0.0, 0.18)
	var wobble := create_tween()
	wobble.tween_property(_body, "rotation", -0.14 * _body.scale.x, 0.05)
	wobble.tween_property(_body, "rotation", 0.0, 0.12)
	if health <= 0.001:
		if _revives_left > 0:
			_go_down()
		else:
			_die()


## Freezes the enemy in place when the battle ends; it can no longer be hurt or strike.
func halt() -> void:
	if state == State.DYING:
		return
	state = State.HALTED
	remove_from_group(GROUP)
	_stop_swing()
	if _revive:
		# Stays on the ground for good.
		_revive.kill()
		_revive = null
		create_tween().tween_property(_body, "death", 1.0, 0.3)


func _process(delta: float) -> void:
	if state == State.BLOCKED and not _blocker.is_standing():
		_resume_walking()
	if state != State.WALKING:
		return
	var before := position
	var start := progress
	progress += stats.speed * BuildGrid.MAP_PIXELS_PER_UNIT * delta
	var barricade := _barricade_ahead(start)
	if barricade:
		progress = maxf(start, barricade.progress - _barricade_gap)
		_block(barricade)
		return
	var moved := position - before
	if absf(moved.x) > moved.length() * TURN_THRESHOLD:
		_body.scale.x = signf(moved.x) * absf(_body.scale.x)
	_body.walk_phase += moved.length() / (STRIDE * stride_scale)
	_body.weapon_angle = EnemyBody.WEAPON_REST + sin(_body.walk_phase) * 0.2
	if progress_ratio >= _stop_ratio:
		_reach_gate()


func _die() -> void:
	state = State.DYING
	remove_from_group(GROUP)
	_stop_swing()
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_body, "death", 1.0, 0.55)
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)


## Collapses like a death but without `died`, lies still, twitches, and stands back up
## `revive_delay` seconds after falling, at full health and carries on walking or striking the gate.
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
	if _at_gate:
		state = State.ATTACKING
		_start_swing()
	elif _blocker and _blocker.is_standing():
		state = State.BLOCKED
		_start_swing()
	else:
		_blocker = null
		state = State.WALKING


## The nearest standing barricade it has walked up to: one it hadn't passed yet, now within its
## stopping gap.
func _barricade_ahead(start: float) -> Barricade:
	var nearest: Barricade = null
	for barricade: Barricade in get_tree().get_nodes_in_group(Barricade.GROUP):
		if barricade.progress <= start or progress + _barricade_gap < barricade.progress:
			continue
		if nearest == null or barricade.progress < nearest.progress:
			nearest = barricade
	return nearest


func _block(barricade: Barricade) -> void:
	state = State.BLOCKED
	_blocker = barricade
	var settle := create_tween()
	settle.tween_property(_body, "walk_phase", 0.0, 0.12)
	_start_swing()


func _resume_walking() -> void:
	_stop_swing()
	_blocker = null
	_body.weapon_angle = EnemyBody.WEAPON_REST
	state = State.WALKING


func _reach_gate() -> void:
	state = State.ATTACKING
	_at_gate = true
	var settle := create_tween()
	settle.tween_property(_body, "walk_phase", 0.0, 0.12)
	_start_swing()


## One chop at the gate or a barricade: raise, strike (dealing damage once), recover, and wait out the rest of
## the attack interval before the next swing.
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
	_swing.tween_interval(maxf(0.0, stats.attack_interval - SWING_TIME))
	_swing.tween_callback(_start_swing)


func _strike() -> void:
	if state == State.ATTACKING:
		attacked_castle.emit(self, stats.castle_damage)
	elif state == State.BLOCKED and _blocker.is_standing():
		_blocker.take_damage(stats.castle_damage)


func _stop_swing() -> void:
	if _swing:
		_swing.kill()
		_swing = null
	_body.swoosh = 0.0
