class_name Tower
extends Node2D
## Base for towers placed on the battlefield. Targets the in-range enemy furthest along the path
## and fires on a cooldown, using the stats of the card that placed it. Inactive (a placement
## preview) until `activate` is called. Subclasses decide what firing looks like. An Upgrade card
## can raise its attack rate once.
##
## Ammo: a tower holds `stats.charges` charges. Firing at least once in a wave spends one charge
## for that whole wave. A tower that spends its last charge keeps firing until the wave ends, then
## sits out the next wave reloading and comes back full. Pips under the base show the charges.

## Where the upgrade badge sits, relative to the cell center.
const BADGE_POS := Vector2(40, 8)
const UPGRADE_BURST_TIME := 0.6
const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_DARK := Color(0.5, 0.33, 0.08)
## Where the charge pips sit, relative to the cell center, and the gap between them.
const PIPS_POS := Vector2(0, 40)
const PIP_SPACING := 22.0
const PIP_POP_TIME := 0.35
const AMMO := Color(1.0, 0.72, 0.25)
const AMMO_DARK := Color(0.14, 0.1, 0.07)
const RELOAD_TINT := Color(0.55, 0.55, 0.6)

var stats: TowerStats
var upgraded := false
## Seconds between shots; starts at the card's value and shrinks when upgraded.
var fire_interval := 1.0
## Charges left before the tower must reload.
var charges_left := 0
## Sitting out the current (or next) wave; can't fire.
var reloading := false

var _fired_this_wave := false
var _pips: Node2D
var _pip_pop := -1.0
var _reload_spin := 0.0

var _projectiles: Node2D
var _cooldown := 0.0
var _badge: Node2D
var _burst := -1.0


func activate(tower_stats: TowerStats, projectile_layer: Node2D) -> void:
	stats = tower_stats
	fire_interval = stats.fire_interval
	_projectiles = projectile_layer
	charges_left = stats.charges
	if stats.charges > 0:
		_pips = Node2D.new()
		_pips.z_index = 1
		_pips.draw.connect(_draw_pips)
		add_child(_pips)


## True while this tower can shoot: unlimited ammo, a charge left, or already paid for this wave.
func can_fire() -> bool:
	if stats == null:
		return false
	if stats.charges <= 0:
		return true
	return not reloading and (_fired_this_wave or charges_left > 0)


## Called when a wave's combat begins.
func begin_wave() -> void:
	_fired_this_wave = false


## Called when a wave is cleared: a reloading tower refills, and an empty one starts reloading
## (it shows as reloading through the next preparation and sits out that wave).
func end_wave() -> void:
	_fired_this_wave = false
	if stats == null or stats.charges <= 0:
		return
	if reloading:
		reloading = false
		charges_left = stats.charges
	elif charges_left <= 0:
		reloading = true
	_on_reload_changed()
	_pips.queue_redraw()


## Dims the tower's art (sprite, cannon) while it reloads; the pips and badge stay bright.
func _on_reload_changed() -> void:
	for child in get_children():
		if child is CanvasItem and child != _pips and child != _badge:
			child.modulate = RELOAD_TINT if reloading else Color.WHITE


## Raises the attack rate by `attack_rate_bonus` (0.5 = 50% more shots). Only once per tower;
## returns false and changes nothing if it was already upgraded.
func upgrade(attack_rate_bonus: float) -> bool:
	if upgraded or stats == null:
		return false
	upgraded = true
	fire_interval = stats.fire_interval / (1.0 + attack_rate_bonus)
	_cooldown = minf(_cooldown, fire_interval)
	_badge = Node2D.new()
	_badge.z_index = 1
	_badge.draw.connect(_draw_badge)
	add_child(_badge)
	_burst = 0.0
	return true


func _process(delta: float) -> void:
	if _burst >= 0.0:
		_burst += delta
		if _burst >= UPGRADE_BURST_TIME:
			_burst = -1.0
		_badge.queue_redraw()
	if _pips and (reloading or _pip_pop >= 0.0):
		_reload_spin += delta
		if _pip_pop >= 0.0:
			_pip_pop += delta
			if _pip_pop >= PIP_POP_TIME:
				_pip_pop = -1.0
		_pips.queue_redraw()
	if _projectiles == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0 or not can_fire():
		return
	var target := find_target()
	if target:
		_cooldown = fire_interval
		if stats.charges > 0 and not _fired_this_wave:
			_fired_this_wave = true
			charges_left -= 1
			_pip_pop = 0.0
			_pips.queue_redraw()
		_fire(target)


## The living enemy in range that is furthest along the path, or null.
func find_target() -> Enemy:
	var reach := stats.attack_range * BuildGrid.MAP_PIXELS_PER_UNIT * global_scale.x
	var best: Enemy = null
	for enemy: Enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if not enemy.is_alive() or global_position.distance_to(enemy.global_position) > reach:
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _fire(_target: Enemy) -> void:
	pass


func _draw() -> void:
	# Soft contact shadow under the tower base; the sprite child draws on top.
	draw_set_transform(Vector2(0, 34), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 60.0, Color(0, 0, 0, 0.3))


## Gold shield with two chevrons on the tower's side, plus a ring of light when first upgraded.
func _draw_badge() -> void:
	if _burst >= 0.0:
		var t := _burst / UPGRADE_BURST_TIME
		_badge.draw_arc(Vector2(0, -50), 40.0 + 70.0 * t, 0, TAU, 48, Color(GOLD, 1.0 - t), 6.0 * (1.0 - t) + 1.0)
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0)
			_badge.draw_circle(Vector2(0, -50) + dir * (30.0 + 90.0 * t), 5.0 * (1.0 - t), Color(1.0, 0.95, 0.6, 1.0 - t))
	var c := BADGE_POS
	var shield := PackedVector2Array([c + Vector2(-14, -16), c + Vector2(14, -16), c + Vector2(14, 2), c + Vector2(0, 16), c + Vector2(-14, 2)])
	var rim := PackedVector2Array([c + Vector2(-17, -19), c + Vector2(17, -19), c + Vector2(17, 3), c + Vector2(0, 20), c + Vector2(-17, 3)])
	_badge.draw_colored_polygon(rim, GOLD_DARK)
	_badge.draw_colored_polygon(shield, GOLD)
	for dy in [-4.0, 5.0]:
		_badge.draw_polyline(PackedVector2Array([c + Vector2(-8, dy + 4), c + Vector2(0, dy - 3), c + Vector2(8, dy + 4)]), GOLD_DARK, 3.5)


## A row of charge pips under the base: amber gems for charges left, dark sockets for spent ones.
## The charge spent this wave pops as it empties. While reloading, a turning amber arc rings them.
func _draw_pips() -> void:
	var n := stats.charges
	var start := PIPS_POS - Vector2(PIP_SPACING * (n - 1) * 0.5, 0)
	var back := Rect2(start - Vector2(17, 11), Vector2(PIP_SPACING * (n - 1) + 34, 22))
	_pips.draw_style_box(_pip_backing(), back)
	for i in n:
		var c := start + Vector2(PIP_SPACING * i, 0)
		var full := not reloading and i < charges_left
		if full:
			_draw_gem(c, 7.5, AMMO)
		else:
			_pips.draw_circle(c, 6.5, AMMO_DARK)
			_pips.draw_arc(c, 6.5, 0, TAU, 16, Color(AMMO, 0.35), 1.5)
		if _pip_pop >= 0.0 and i == charges_left:
			var t := _pip_pop / PIP_POP_TIME
			_pips.draw_circle(c, 7.5 * (1.0 - t) + 2.0, Color(1.0, 0.95, 0.7, 1.0 - t))
			_pips.draw_arc(c, 8.0 + 12.0 * t, 0, TAU, 20, Color(AMMO, 1.0 - t), 2.5)
	if reloading:
		var center := PIPS_POS
		var radius := back.size.x * 0.5 + 4.0
		var a := _reload_spin * 4.0
		_pips.draw_arc(center, radius, a, a + PI * 1.2, 24, Color(AMMO, 0.95), 3.0)
		_pips.draw_arc(center, radius, a + PI, a + PI * 2.2, 24, Color(AMMO, 0.35), 3.0)


func _draw_gem(c: Vector2, r: float, color: Color) -> void:
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	var rim := PackedVector2Array([c + Vector2(0, -r - 2.5), c + Vector2(r + 2.5, 0), c + Vector2(0, r + 2.5), c + Vector2(-r - 2.5, 0)])
	_pips.draw_colored_polygon(rim, GOLD_DARK)
	_pips.draw_colored_polygon(diamond, color)
	_pips.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.5), c, c + Vector2(-r * 0.5, -r * 0.5)]), Color(1.0, 0.95, 0.75))


static var _backing: StyleBoxFlat


static func _pip_backing() -> StyleBoxFlat:
	if _backing == null:
		_backing = StyleBoxFlat.new()
		_backing.bg_color = Color(0.05, 0.04, 0.03, 0.7)
		_backing.border_color = Color(GOLD_DARK, 0.9)
		_backing.set_border_width_all(2)
		_backing.set_corner_radius_all(11)
	return _backing
