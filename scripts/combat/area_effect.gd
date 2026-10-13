class_name AreaEffect
extends Node2D
## Base for effects lying on the battlefield's ground layer, under the enemies: burning ground, an
## oil slick, caltrops. Lasts `duration` seconds (or until it ends itself), ticks every
## `tick_interval` seconds (or every frame), and works on the living enemies inside it. Damage
## that covers the ground reaches every effect there through `touched_by`, so effects can react
## to each other (fire ignites oil). Burn and other damage over time it is about to deal is
## offered to TargetPlanner through `predicted_damage_to`, so towers don't overkill. Positions
## and radii are in map pixels.

var world: Battlefield
var radius := 0.0
## Seconds it lasts, or INF until it ends itself.
var duration := INF
var age := 0.0
## Seconds between ticks, or 0 to tick every frame.
var tick_interval := 0.0
## Age at which the next tick happens.
var next_tick := 0.0


## Tells every effect on the ground that damage of `type` covered a circle (map pixels).
static func touch_all(battle_world: Battlefield, type: Damage.Type, center: Vector2, reach: float) -> void:
	for effect in battle_world.ground.get_children():
		if effect is AreaEffect:
			effect.touched_by(type, center, reach)


## Adds it to the battlefield's ground layer at a canvas position.
func place(battle_world: Battlefield, at_global: Vector2) -> void:
	world = battle_world
	world.ground.add_child(self)
	position = world.ground.to_local(at_global)


func _process(delta: float) -> void:
	age += delta
	if tick_interval <= 0.0:
		_tick()
	else:
		while age >= next_tick and next_tick <= duration:
			_tick()
			next_tick += tick_interval
	if age >= duration:
		_expire()
	queue_redraw()


## One tick's work.
func _tick() -> void:
	pass


## It has run out.
func _expire() -> void:
	queue_free()


## Damage of `type` covered a circle of `reach` around `center` (map pixels), touching the ground.
func touched_by(_type: Damage.Type, _center: Vector2, _reach: float) -> void:
	pass


## Damage it will deal `enemy` over the next `horizon` seconds, as far as it can tell.
func predicted_damage_to(_enemy: Enemy, _horizon: float) -> float:
	return 0.0


## The living enemies inside its circle.
func enemies_inside() -> Array[Enemy]:
	return world.enemies.in_radius(position, radius)


## Whether a canvas position is inside its circle, by the same test `enemies_inside` uses.
func contains(point_global: Vector2) -> bool:
	return get_parent().to_local(point_global).distance_to(position) <= radius


## 1 while it lasts, falling to 0 over its last `fade_time` seconds.
func fade(fade_time: float) -> float:
	return clampf((duration - age) / fade_time, 0.0, 1.0)
