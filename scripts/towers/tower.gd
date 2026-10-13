class_name Tower
extends Node2D
## Base for towers placed on the battlefield. Targets the in-range enemy furthest along the path
## that TargetPlanner doesn't already count as doomed, holding fire if every one is, and fires
## the stats' projectile on a cooldown. Works from its own copy of the stats of the card that
## placed it, so upgrades change only this tower. Inactive (a placement preview) until `activate`
## is called. Subclasses decide what firing looks like.
##
## Ammo (TowerAmmo) is counted in charges per wave; ChargePips under the base show it, and the
## tower dims while it sits out a wave reloading. Upgrade cards apply TowerUpgrades, each at most
## once per tower; UpgradeBadge shows them.

const RELOAD_TINT := Color(0.42, 0.42, 0.5)

## This tower's own copy of its stats.
var stats: TowerStats
var ammo: TowerAmmo

var _world: Battlefield
var _cooldown := 0.0
## Ids of the upgrades it has taken.
var _upgrades: Dictionary[StringName, bool] = {}
var _pips: ChargePips
var _badge: UpgradeBadge


## Brings the tower to life with a copy of `tower_stats`. Towers with ammo follow the battle's
## waves to spend and reload charges.
func activate(tower_stats: TowerStats, world: Battlefield) -> void:
	stats = tower_stats.duplicate()
	_world = world
	ammo = TowerAmmo.new(stats.charges)
	if ammo.is_unlimited():
		return
	ammo.changed.connect(_on_ammo_changed)
	_pips = ChargePips.new(ammo)
	add_child(_pips)
	if world.battle:
		world.battle.combat_started.connect(func(_number: int) -> void: begin_wave())
		world.battle.wave_cleared.connect(func(_number: int) -> void: end_wave())


func can_fire() -> bool:
	return ammo != null and ammo.can_fire()


## A wave's combat began.
func begin_wave() -> void:
	ammo.begin_wave()


## A wave was cleared: an empty tower starts reloading, a reloading one comes back full.
func end_wave() -> void:
	ammo.end_wave()


func has_upgrade(id: StringName) -> bool:
	return _upgrades.has(id)


## True while `upgrade` would still improve this tower.
func can_take(upgrade: TowerUpgrade) -> bool:
	return ammo != null and upgrade.can_apply(self)


## Applies `upgrade` and returns true, or returns false and changes nothing if it can't be taken.
func upgrade(upgrade: TowerUpgrade) -> bool:
	if not can_take(upgrade):
		return false
	_upgrades[upgrade.id] = true
	upgrade.apply(self)
	if _badge == null:
		_badge = UpgradeBadge.new()
		add_child(_badge)
	_badge.shown = _badge.shown or upgrade.shows_badge
	_badge.burst()
	return true


## Changes the time between shots; a shot already waiting longer comes sooner.
func set_fire_interval(seconds: float) -> void:
	stats.fire_interval = seconds
	_cooldown = minf(_cooldown, seconds)


## Dims the tower's art (sprite, cannon) while it reloads; the pips and badge stay bright.
func _on_ammo_changed() -> void:
	for child in get_children():
		if child is CanvasItem and child != _pips and child != _badge:
			child.modulate = RELOAD_TINT if ammo.reloading else Color.WHITE


func _process(delta: float) -> void:
	if _world == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0 or not can_fire():
		return
	var target := find_target()
	if target:
		_cooldown = stats.fire_interval
		ammo.note_shot()
		_fire(target)


## The living enemy in range furthest along the path that isn't already doomed, or null.
func find_target() -> Enemy:
	return _world.targeting.pick_target(_world.to_local(global_position), Units.px(stats.attack_range))


## Shoots at `target`. Subclasses that animate the shot call `_launch` with their muzzle.
func _fire(target: Enemy) -> void:
	_launch(target, global_position)


## Fires the stats' projectile from a canvas position.
func _launch(target: Enemy, from_global: Vector2) -> void:
	Projectile.fire(stats.projectile, _world, from_global, target, Hit.new(stats.damage, stats.damage_type),
		stats.projectile_speed)


func _draw() -> void:
	# Soft contact shadow under the tower base; the sprite child draws on top.
	draw_set_transform(Vector2(0, 34), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 60.0, Color(0, 0, 0, 0.3))
