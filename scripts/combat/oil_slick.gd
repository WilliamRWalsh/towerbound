class_name OilSlick
extends AreaEffect
## A pool of lamp oil spilled on the road. Enemies wading through it get its slow. Fire touching it
## (a Fireball blast or burning ground) ignites it into a long, hot BurningGround patch and uses it
## up; that patch can ignite the next slick in turn. Dries up after `duration`.

## How often enemies inside are slowed; each slow outlasts the tick so it never flickers off.
const TICK := 0.2
const FADE_TIME := 1.0
## Share of the slick's radius that has to overlap a fire to catch.
const CATCH_SHARE := 0.6

var _slow: StatusEffect
var _blaze: BurnSpec
## True once it has ignited or dried up; it can't catch again.
var _spent := false
## Blobs making up the puddle's outline: [offset, radius].
var _blobs: Array = []


## Spills a slick at a canvas position. `slick_radius` is in map pixels; enemies inside get `slow`,
## and it burns like `blaze` once ignited.
static func spill(battle_world: Battlefield, at_global: Vector2, slick_radius: float, slow: StatusEffect,
		slick_duration: float, blaze: BurnSpec) -> OilSlick:
	var slick := OilSlick.new()
	slick.radius = slick_radius
	slick.duration = slick_duration
	slick.tick_interval = TICK
	slick._slow = slow
	slick._blaze = blaze
	for i in 7:
		var spot := Vector2.from_angle(TAU * i / 7.0 + randf_range(-0.3, 0.3)) * slick_radius * randf_range(0.3, 0.5)
		slick._blobs.append([spot, slick_radius * randf_range(0.5, 0.62)])
	slick.place(battle_world, at_global)
	return slick


## Fire catches when it reaches far enough into the slick.
func touched_by(type: Damage.Type, center: Vector2, reach: float) -> void:
	if type == Damage.Type.FIRE and position.distance_to(center) <= reach + radius * CATCH_SHARE:
		ignite()


## Bursts into flame, leaving a burning patch the size of the slick. Only the first call counts.
func ignite() -> void:
	if _spent:
		return
	_spent = true
	BurningGround.ignite(world, global_position, radius, _blaze)
	queue_free()


## A slick that has just dried up slows nothing.
func _tick() -> void:
	if age >= duration:
		return
	for enemy in enemies_inside():
		enemy.apply_status(_slow, TICK * 2.0)


func _expire() -> void:
	_spent = true
	queue_free()


func _draw() -> void:
	var fade_out := fade(FADE_TIME)
	var grow := clampf(age / 0.25, 0.0, 1.0)
	# A dark, glossy pool of overlapping blobs: see-through enough to show the road, with a pale
	# rim and swirls of rainbow sheen, filling the circle that was aimed.
	for blob in _blobs:
		draw_circle(blob[0] * grow, blob[1] * grow + 4.0, Color(0.85, 0.8, 0.95, 0.18 * fade_out))
	for blob in _blobs:
		draw_circle(blob[0] * grow, blob[1] * grow, Color(0.12, 0.08, 0.16, 0.68 * fade_out))
	var shimmer := 0.5 + 0.5 * sin(age * 2.0)
	for i in _blobs.size():
		var blob: Array = _blobs[i]
		var c: Vector2 = blob[0] * grow * 0.7
		var r: float = blob[1] * grow
		var turn := age * 0.3 + i
		draw_arc(c, r * 0.55, turn, turn + 1.4, 14, Color(0.6, 0.42, 0.9, (0.45 + 0.25 * shimmer) * fade_out), 4.0)
		draw_arc(c, r * 0.38, turn + 2.2, turn + 3.4, 12, Color(0.35, 0.8, 0.72, (0.4 + 0.25 * (1.0 - shimmer)) * fade_out), 3.0)
		draw_arc(c, r * 0.7, turn + 4.0, turn + 4.8, 10, Color(0.95, 0.78, 0.4, 0.3 * fade_out), 2.5)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.2) * grow, 6.0 * grow, Color(1, 1, 1, 0.35 * fade_out))
