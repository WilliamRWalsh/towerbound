class_name Enemy
extends PathFollow2D
## An enemy walking the enemy path; its look comes from the EnemyBody child and its numbers from
## `stats`. Dies once at zero health. At the end of the path it swings at the castle gate, deals
## its damage once, and vanishes. Leaves the "enemies" group the moment it dies or reaches the
## castle, so towers and projectiles ignore it from then on.

signal died(enemy: Enemy)
signal reached_castle(enemy: Enemy, damage: int)

enum State { WALKING, ATTACKING, DYING }

const GROUP := "enemies"
## Map pixels walked per radian of walk cycle.
const STRIDE := 4.5
## Only turn around when moving at least this much sideways, so near-vertical stretches
## don't flicker between facings.
const TURN_THRESHOLD := 0.3

@export var stats: EnemyStats
## Walk cycle speed relative to distance; short legs take quicker steps.
@export var stride_scale := 1.0

var state := State.WALKING
var health := 0

@onready var _body: EnemyBody = $Body


func _ready() -> void:
	health = stats.max_health
	add_to_group(GROUP)


func is_alive() -> bool:
	return state == State.WALKING


## Canvas position projectiles aim for.
func aim_point() -> Vector2:
	return _body.to_global(Vector2(0, -_body.chest_height))


func take_damage(amount: int) -> void:
	if state != State.WALKING:
		return
	health -= amount
	_body.health_ratio = float(health) / stats.max_health
	_body.flash = 1.0
	create_tween().tween_property(_body, "flash", 0.0, 0.18)
	var wobble := create_tween()
	wobble.tween_property(_body, "rotation", -0.14 * _body.scale.x, 0.05)
	wobble.tween_property(_body, "rotation", 0.0, 0.12)
	if health <= 0:
		_die()


func _process(delta: float) -> void:
	if state != State.WALKING:
		return
	var before := position
	progress += stats.speed * BuildGrid.MAP_PIXELS_PER_UNIT * delta
	var moved := position - before
	if absf(moved.x) > moved.length() * TURN_THRESHOLD:
		_body.scale.x = signf(moved.x) * absf(_body.scale.x)
	_body.walk_phase += moved.length() / (STRIDE * stride_scale)
	_body.weapon_angle = EnemyBody.WEAPON_REST + sin(_body.walk_phase) * 0.2
	if progress_ratio >= 1.0:
		_attack_castle()


func _die() -> void:
	state = State.DYING
	remove_from_group(GROUP)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_body, "death", 1.0, 0.55)
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)


func _attack_castle() -> void:
	state = State.ATTACKING
	remove_from_group(GROUP)
	var tween := create_tween()
	tween.tween_property(_body, "walk_phase", 0.0, 0.12)
	tween.parallel().tween_property(_body, "weapon_angle", EnemyBody.SWING_RAISED, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(_body, "weapon_angle", EnemyBody.SWING_STRUCK, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "swoosh", 1.0, 0.1)
	tween.tween_callback(func() -> void: reached_castle.emit(self, stats.castle_damage))
	tween.tween_property(_body, "swoosh", 0.0, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
