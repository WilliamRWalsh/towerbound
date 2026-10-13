class_name CellTargeting
extends CardTargeting
## Aims at an open build cell. Shows the open cells, plus a ghost and the range of the tower the
## card places, if it places one.


func begin(world: Battlefield, card: CardData) -> void:
	var place := card.find_effect(PlaceTowerEffect) as PlaceTowerEffect
	if place:
		world.placement.show_placement(place.tower_scene, place.tower_stats)


func update(world: Battlefield, _card: CardData, global_pos: Vector2, over_field: bool) -> void:
	world.placement.update_pointer(global_pos, over_field)


func end(world: Battlefield) -> void:
	world.placement.clear()


func resolve(world: Battlefield, _card: CardData, global_pos: Vector2) -> CardTarget:
	var grid := world.grid
	var cell := grid.world_to_cell(global_pos)
	if not grid.can_build(cell):
		return null
	var target := CardTarget.new(grid.to_global(grid.cell_center(cell)))
	target.cell = cell
	return target
