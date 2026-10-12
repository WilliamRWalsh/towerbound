class_name CannonTower
extends Tower
## Stone Cannon Tower: an iron cannon on the roof turns to face its target and lobs a heavy
## cannonball, kicking back with a flash and a puff of smoke.

## Turntable center, relative to the tower's cell center (the roof of the sprite).
const GUN_PIVOT := Vector2(0, -122)
const BARREL_LENGTH := 34.0
## Radians per second the cannon turns while tracking.
const TURN_SPEED := 5.0
const SMOKE_TIME := 0.6

const IRON := Color(0.26, 0.27, 0.31)
const IRON_LIGHT := Color(0.55, 0.57, 0.63)
const IRON_DARK := Color(0.1, 0.1, 0.12)
const WOOD := Color(0.47, 0.31, 0.17)
const WOOD_DARK := Color(0.28, 0.17, 0.09)

var _aim := PI / 2  # pointing down the screen until something comes into range
var _recoil := 0.0
var _flash := 0.0
## Each puff: [position relative to the pivot, age in seconds, drift].
var _smoke: Array = []

@onready var _gun: Node2D = $Gun


func _ready() -> void:
	_gun.position = GUN_PIVOT
	_gun.draw.connect(_draw_gun)


func _process(delta: float) -> void:
	super(delta)
	if _projectiles:
		var target := find_target()
		if target:
			var want := (target.global_position - _gun.global_position).angle()
			_aim = rotate_toward(_aim, want, TURN_SPEED * delta)
	for puff in _smoke:
		puff[1] += delta
		puff[0] += puff[2] * delta
	_smoke = _smoke.filter(func(puff: Array) -> bool: return puff[1] < SMOKE_TIME)
	_gun.queue_redraw()


func _fire(target: Enemy) -> void:
	_aim = (target.global_position - _gun.global_position).angle()
	var dir := Vector2.from_angle(_aim)
	var muzzle := dir * (BARREL_LENGTH + 4.0)
	Cannonball.launch(_projectiles, _gun.to_global(muzzle), target, stats.damage, stats.projectile_speed)
	for i in 4:
		var drift := dir.rotated(randf_range(-0.6, 0.6)) * randf_range(14, 34) + Vector2(0, -18)
		_smoke.append([muzzle, randf_range(-0.05, 0.0), drift])
	var tween := create_tween()
	tween.tween_property(self, "_recoil", 1.0, 0.05)
	tween.tween_property(self, "_recoil", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash = 1.0
	create_tween().tween_property(self, "_flash", 0.0, 0.14)


func _draw_gun() -> void:
	# Wooden turntable, then the barrel along the aim with its recoil.
	_gun.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.72))
	_gun.draw_circle(Vector2.ZERO, 19.0, WOOD_DARK)
	_gun.draw_circle(Vector2.ZERO, 16.0, WOOD)
	_gun.draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(0.22, 0.22, 0.25), 2.0)
	var back := -_recoil * 7.0
	_gun.draw_set_transform(Vector2.ZERO, _aim)
	var body := PackedVector2Array([
		Vector2(back - 8, -8), Vector2(back + BARREL_LENGTH, -6), Vector2(back + BARREL_LENGTH, 6), Vector2(back - 8, 8),
	])
	_gun.draw_colored_polygon(PackedVector2Array([
		body[0] + Vector2(-1.5, -1.5), body[1] + Vector2(1.5, -1.5), body[2] + Vector2(1.5, 1.5), body[3] + Vector2(-1.5, 1.5),
	]), IRON_DARK)
	_gun.draw_circle(Vector2(back - 8, 0), 9.5, IRON_DARK)
	_gun.draw_colored_polygon(body, IRON)
	_gun.draw_circle(Vector2(back - 8, 0), 8.0, IRON)
	_gun.draw_circle(Vector2(back - 15, 0), 3.5, IRON_DARK)
	# Reinforcing rings and the flared muzzle.
	for x in [2.0, 16.0]:
		_gun.draw_rect(Rect2(back + x, -8, 3, 16), IRON_DARK)
	_gun.draw_rect(Rect2(back + BARREL_LENGTH - 4, -8.5, 6, 17), IRON_DARK)
	_gun.draw_rect(Rect2(back + BARREL_LENGTH - 3, -7, 4, 14), IRON)
	_gun.draw_line(Vector2(back - 6, -4), Vector2(back + BARREL_LENGTH - 4, -3.5), IRON_LIGHT, 2.0)
	if _flash > 0.0:
		var tip := Vector2(back + BARREL_LENGTH + 4, 0)
		_gun.draw_circle(tip + Vector2(6, 0), 14.0 * _flash, Color(1.0, 0.62, 0.2, 0.7 * _flash))
		_gun.draw_circle(tip + Vector2(4, 0), 8.0 * _flash, Color(1.0, 0.95, 0.7, _flash))
	_gun.draw_set_transform(Vector2.ZERO)
	for puff in _smoke:
		var t: float = clampf(puff[1] / SMOKE_TIME, 0.0, 1.0)
		if puff[1] < 0.0:
			continue
		_gun.draw_circle(puff[0], 7.0 + 12.0 * t, Color(0.82, 0.8, 0.78, 0.75 * (1.0 - t)))
