class_name BuildGrid
extends Node2D
## Build grid over the map's meadow. Works in map-pixel coordinates; the parent battlefield
## scales it with the map. Draws faint cell lines, and highlights cells while a card is aimed:
## open cells when placing a tower, upgradeable towers when upgrading.

signal tower_placed(cell: Vector2i)

enum CellState { BUILDABLE, BLOCKED, OCCUPIED }
enum Targeting { NONE, PLACE, UPGRADE }

const NO_CELL := Vector2i(-1, -1)

## Grid line positions in map pixels: 7 columns and 10 rows of roughly 107 × 106 px cells
## across the meadow.
@export var column_lines := _even_lines(104.0, 855.0, 7)
@export var row_lines := _even_lines(371.0, 1431.0, 10)
## Build mask exported by tools/build_woodland.py: white where the path, trees, or castle are.
@export var blocked_mask: Texture2D
## A cell is blocked when at least this fraction of its samples is masked.
@export_range(0.0, 1.0) var blocked_threshold := 0.3
## The battlefield placed towers fight on.
@export var world: Battlefield
## Manual corrections to the mask.
@export var extra_blocked: Array[Vector2i] = []
@export var extra_buildable: Array[Vector2i] = []

var _states: Dictionary[Vector2i, CellState] = {}
var _towers: Dictionary[Vector2i, Tower] = {}
var _targeting := Targeting.NONE
var _hover := NO_CELL
var _preview_range := 0.0
var _ghost: Node2D = null


func _ready() -> void:
	_detect_cells()


## Returns the cell under a global (canvas) position, or NO_CELL outside the grid.
func world_to_cell(global_pos: Vector2) -> Vector2i:
	var local := to_local(global_pos)
	var cell := Vector2i(_line_index(column_lines, local.x), _line_index(row_lines, local.y))
	return cell if _states.has(cell) else NO_CELL


func cell_rect(cell: Vector2i) -> Rect2:
	var top_left := Vector2(column_lines[cell.x], row_lines[cell.y])
	return Rect2(top_left, Vector2(column_lines[cell.x + 1], row_lines[cell.y + 1]) - top_left)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_rect(cell).get_center()


func can_build(cell: Vector2i) -> bool:
	return _states.get(cell, CellState.BLOCKED) == CellState.BUILDABLE


func place_tower(cell: Vector2i, tower_scene: PackedScene, stats: TowerStats) -> bool:
	if not can_build(cell):
		return false
	var tower: Node2D = tower_scene.instantiate()
	tower.position = cell_center(cell)
	$Towers.add_child(tower)
	tower.activate(stats, world)
	_states[cell] = CellState.OCCUPIED
	_towers[cell] = tower
	tower_placed.emit(cell)
	return true


## The tower standing in a cell, or null.
func tower_at(cell: Vector2i) -> Tower:
	return _towers.get(cell)


func can_upgrade(cell: Vector2i) -> bool:
	var tower := tower_at(cell)
	return tower != null and tower.can_upgrade()


func has_upgradeable_tower() -> bool:
	return _towers.keys().any(can_upgrade)


## Tells every placed tower a wave's combat has begun (towers track their ammo per wave).
func begin_wave() -> void:
	for tower: Tower in _towers.values():
		tower.begin_wave()


## Tells every placed tower the wave was cleared, so empty towers start or finish reloading.
func end_wave() -> void:
	for tower: Tower in _towers.values():
		tower.end_wave()


## Removes every placed tower and restores the detected cell states.
func clear() -> void:
	for tower in $Towers.get_children():
		tower.queue_free()
	_towers.clear()
	end_placement()
	_detect_cells()


## Shows buildable cells, a ghost tower, and its range while a card is being placed.
func begin_placement(tower_scene: PackedScene, stats: TowerStats) -> void:
	end_placement()
	_ghost = tower_scene.instantiate()
	_ghost.modulate = Color(1, 1, 1, 0.6)
	_ghost.visible = false
	add_child(_ghost)
	_preview_range = Units.px(stats.attack_range)
	_targeting = Targeting.PLACE
	queue_redraw()


## Highlights towers that can still be upgraded while an Upgrade card is aimed.
func begin_upgrade_targeting() -> void:
	end_placement()
	_targeting = Targeting.UPGRADE
	queue_redraw()


## Moves the placement preview. Pass `over_grid = false` when the pointer is over UI.
func update_pointer(global_pos: Vector2, over_grid := true) -> void:
	if _targeting == Targeting.NONE:
		return
	_hover = world_to_cell(global_pos) if over_grid else NO_CELL
	if _ghost:
		_ghost.visible = over_grid
		_ghost.position = cell_center(_hover) if _hover != NO_CELL else to_local(global_pos)
	queue_redraw()


func end_placement() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_targeting = Targeting.NONE
	_hover = NO_CELL
	queue_redraw()


func _detect_cells() -> void:
	_states.clear()
	var image := blocked_mask.get_image() if blocked_mask else null
	for row in row_lines.size() - 1:
		for column in column_lines.size() - 1:
			var cell := Vector2i(column, row)
			var blocked := image != null and _blocked_fraction(image, cell) >= blocked_threshold
			_states[cell] = CellState.BLOCKED if blocked else CellState.BUILDABLE
	for cell in extra_blocked:
		if _states.has(cell):
			_states[cell] = CellState.BLOCKED
	for cell in extra_buildable:
		if _states.has(cell):
			_states[cell] = CellState.BUILDABLE


## Samples a 6 × 6 pattern inside the cell and returns the fraction the mask marks as blocked.
func _blocked_fraction(image: Image, cell: Vector2i) -> float:
	var hits := 0
	var rect := cell_rect(cell)
	for i in 6:
		for j in 6:
			var sample := rect.position + rect.size * Vector2(0.1 + 0.16 * i, 0.1 + 0.16 * j)
			if image.get_pixelv(Vector2i(sample)).r > 0.5:
				hits += 1
	return hits / 36.0


static func _even_lines(first: float, last: float, count: int) -> PackedFloat32Array:
	var lines := PackedFloat32Array()
	for i in count + 1:
		lines.append(lerpf(first, last, float(i) / count))
	return lines


## Index of the cell between grid lines that contains `value`, or -1 outside the grid.
func _line_index(lines: PackedFloat32Array, value: float) -> int:
	for i in lines.size() - 1:
		if value >= lines[i] and value < lines[i + 1]:
			return i
	return -1


func _draw() -> void:
	# Faint cell lines on open ground, like a grid chalked onto the meadow.
	for cell in _states:
		if _states[cell] != CellState.BLOCKED:
			draw_rect(cell_rect(cell), Color(1, 1, 0.9, 0.16), false, 1.5)
	if _targeting == Targeting.UPGRADE:
		_draw_upgrade_targets()
		return
	if _targeting != Targeting.PLACE:
		return
	for cell in _states:
		if _states[cell] == CellState.BUILDABLE:
			var rect := cell_rect(cell).grow(-3)
			draw_rect(rect, Color(0.7, 1.0, 0.5, 0.16))
			draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.5)
	if _hover == NO_CELL:
		return
	var hover_rect := cell_rect(_hover).grow(-2)
	if can_build(_hover):
		draw_circle(cell_center(_hover), _preview_range, Color(1.0, 0.9, 0.45, 0.14))
		draw_arc(cell_center(_hover), _preview_range, 0, TAU, 96, Color(1.0, 0.88, 0.4, 0.8), 3.0)
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.95), false, 4.0)
	else:
		draw_rect(hover_rect, Color(0.9, 0.15, 0.1, 0.4))
		draw_rect(hover_rect, Color(1.0, 0.3, 0.2, 0.9), false, 3.0)


func _draw_upgrade_targets() -> void:
	for cell in _towers:
		if can_upgrade(cell):
			var rect := cell_rect(cell).grow(-3)
			draw_rect(rect, Color(1.0, 0.85, 0.3, 0.3))
			draw_rect(rect, Color(1.0, 0.88, 0.45, 0.9), false, 3.0)
	if _hover == NO_CELL:
		return
	var hover_rect := cell_rect(_hover).grow(-2)
	if can_upgrade(_hover):
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.3))
		draw_rect(hover_rect, Color(1.0, 0.85, 0.3, 0.95), false, 4.0)
	else:
		draw_rect(hover_rect, Color(0.9, 0.15, 0.1, 0.4))
		draw_rect(hover_rect, Color(1.0, 0.3, 0.2, 0.9), false, 3.0)
