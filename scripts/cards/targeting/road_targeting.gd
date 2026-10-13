class_name RoadTargeting
extends CardTargeting
## Aims a barricade across the road: snaps to the nearest point on it, and is invalid too far from
## the road, near either end of it, or too close to another barricade. Shows a ghost barricade,
## green or red.


func begin(world: Battlefield, _card: CardData) -> void:
	world.barricades.begin_preview()


func update(world: Battlefield, _card: CardData, global_pos: Vector2, over_field: bool) -> void:
	world.barricades.update_preview(global_pos, over_field)


func end(world: Battlefield) -> void:
	world.barricades.end_preview()


func resolve(world: Battlefield, _card: CardData, global_pos: Vector2) -> CardTarget:
	var offset := world.barricades.snap(global_pos)
	if offset == BarricadeLayer.INVALID:
		return null
	var target := CardTarget.new(world.road_point_at(offset))
	target.road_offset = offset
	return target
