class_name TowerTargeting
extends CardTargeting
## Aims at a placed tower the card can act on (Upgrade), highlighting each one while held.


func begin(world: Battlefield, card: CardData) -> void:
	world.placement.show_tower_targets(func(tower: Tower) -> bool: return card.can_play_on(world, _target(world, tower)))


func update(world: Battlefield, _card: CardData, global_pos: Vector2, over_field: bool) -> void:
	world.placement.update_pointer(global_pos, over_field)


func end(world: Battlefield) -> void:
	world.placement.clear()


func resolve(world: Battlefield, _card: CardData, global_pos: Vector2) -> CardTarget:
	var cell := world.grid.world_to_cell(global_pos)
	var tower := world.grid.tower_at(cell)
	return _target(world, tower) if tower else null


func has_any_target(world: Battlefield, card: CardData) -> bool:
	return world.grid.towers().any(func(tower: Tower) -> bool: return card.can_play_on(world, _target(world, tower)))


func _target(world: Battlefield, tower: Tower) -> CardTarget:
	var grid := world.grid
	var cell := grid.world_to_cell(tower.global_position)
	var target := CardTarget.new(grid.to_global(grid.cell_center(cell)))
	target.cell = cell
	target.tower = tower
	return target
