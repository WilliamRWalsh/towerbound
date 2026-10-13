class_name AreaTargeting
extends CardTargeting
## Aims a circle of `radius` anywhere on the battlefield, or only on the road (snapping onto it)
## when `on_road` is set. The circle follows the pointer and turns red where it can't go.

## Map pixels from the road a drop can be and still snap onto it.
const SNAP_DISTANCE := 80.0

## Radius in world units at the 720 × 1280 reference resolution.
@export var radius := 70.0
@export var color := TargetOverlay.FIRE
@export var on_road := false


func begin(world: Battlefield, _card: CardData) -> void:
	world.overlay.show_circle(Units.px(radius), color)


func update(world: Battlefield, _card: CardData, global_pos: Vector2, over_field: bool) -> void:
	var point := _point(world, global_pos)
	var valid := point != Vector2.INF
	world.overlay.move_circle(point if valid else global_pos, over_field, valid)


func end(world: Battlefield) -> void:
	world.overlay.hide_circle()


func resolve(world: Battlefield, _card: CardData, global_pos: Vector2) -> CardTarget:
	var point := _point(world, global_pos)
	if point == Vector2.INF:
		return null
	var target := CardTarget.new(point)
	target.radius = Units.px(radius)
	return target


## The canvas point a drop at `global_pos` lands on, or Vector2.INF where it can't go.
func _point(world: Battlefield, global_pos: Vector2) -> Vector2:
	return world.road_point(global_pos, SNAP_DISTANCE) if on_road else global_pos
