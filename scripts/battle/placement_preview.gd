class_name PlacementPreview
extends Node2D
## What the build grid shows while a card is aimed at it. Placing a tower: the open cells, a ghost
## of the tower under the pointer, and its range, or red over a cell it can't go on. Aiming at
## towers (Upgrade): the towers the card can target, and red over anything else. Display only;
## the card decides what a drop does. Draws under the towers and enemies, in map pixels.

enum Mode { NONE, PLACE, TOWERS }

@export var grid: BuildGrid

var _mode := Mode.NONE
var _hover := BuildGrid.NO_CELL
var _preview_range := 0.0
var _ghost: Node2D = null
## Which towers count as targets in TOWERS mode.
var _is_target_tower: Callable


## Shows open cells, a ghost tower, and its range while a tower card is aimed.
func show_placement(tower_scene: PackedScene, stats: TowerStats) -> void:
	clear()
	_ghost = tower_scene.instantiate()
	_ghost.modulate = Color(1, 1, 1, 0.6)
	_ghost.visible = false
	# The ghost sorts with the real towers by height.
	grid.add_child(_ghost)
	_preview_range = Units.px(stats.attack_range)
	_mode = Mode.PLACE
	queue_redraw()


## Highlights the towers `is_target(tower)` accepts while a card aimed at towers is held.
func show_tower_targets(is_target: Callable) -> void:
	clear()
	_is_target_tower = is_target
	_mode = Mode.TOWERS
	queue_redraw()


## Moves the preview. Pass `over_grid = false` when the pointer is over UI.
func update_pointer(global_pos: Vector2, over_grid := true) -> void:
	if _mode == Mode.NONE:
		return
	_hover = grid.world_to_cell(global_pos) if over_grid else BuildGrid.NO_CELL
	if _ghost:
		_ghost.visible = over_grid
		_ghost.position = grid.cell_center(_hover) if _hover != BuildGrid.NO_CELL else grid.to_local(global_pos)
	queue_redraw()


func clear() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_mode = Mode.NONE
	_hover = BuildGrid.NO_CELL
	queue_redraw()


func _is_target(tower: Tower) -> bool:
	return tower != null and _is_target_tower.is_valid() and _is_target_tower.call(tower)


func _draw() -> void:
	if _mode == Mode.TOWERS:
		_draw_tower_targets()
		return
	if _mode != Mode.PLACE:
		return
	for cell in grid.cells():
		if grid.can_build(cell):
			var rect := grid.cell_rect(cell).grow(-3)
			draw_rect(rect, Color(0.7, 1.0, 0.5, 0.16))
			draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.5)
	if _hover == BuildGrid.NO_CELL:
		return
	var hover_rect := grid.cell_rect(_hover).grow(-2)
	if grid.can_build(_hover):
		draw_circle(grid.cell_center(_hover), _preview_range, Color(1.0, 0.9, 0.45, 0.14))
		draw_arc(grid.cell_center(_hover), _preview_range, 0, TAU, 96, Color(1.0, 0.88, 0.4, 0.8), 3.0)
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.95), false, 4.0)
	else:
		draw_rect(hover_rect, Color(0.9, 0.15, 0.1, 0.4))
		draw_rect(hover_rect, Color(1.0, 0.3, 0.2, 0.9), false, 3.0)


func _draw_tower_targets() -> void:
	for cell in grid.cells():
		if _is_target(grid.tower_at(cell)):
			var rect := grid.cell_rect(cell).grow(-3)
			draw_rect(rect, Color(1.0, 0.85, 0.3, 0.3))
			draw_rect(rect, Color(1.0, 0.88, 0.45, 0.9), false, 3.0)
	if _hover == BuildGrid.NO_CELL:
		return
	var hover_rect := grid.cell_rect(_hover).grow(-2)
	if _is_target(grid.tower_at(_hover)):
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.3))
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.95), false, 4.0)
	else:
		draw_rect(hover_rect, Color(0.9, 0.15, 0.1, 0.4))
		draw_rect(hover_rect, Color(1.0, 0.3, 0.2, 0.9), false, 3.0)
