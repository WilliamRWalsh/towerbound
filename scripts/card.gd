class_name TowerCard
extends Control
## A tower card in the hand. Reports taps and drags; main.gd decides what they do and the hand
## positions the card.

signal tapped(card: TowerCard)
signal drag_started(card: TowerCard)
signal drag_moved(card: TowerCard, global_pos: Vector2)
signal drag_released(card: TowerCard, global_pos: Vector2)

const DRAG_THRESHOLD := 14.0

@export var art: Texture2D
@export var cost := 2
@export var tower_scene: PackedScene
## Combat stats the placed tower uses.
@export var tower_stats: TowerStats

var selected := false:
	set(value):
		selected = value
		queue_redraw()
## False when there isn't enough mana to play the card; it's drawn dimmed.
var affordable := true:
	set(value):
		affordable = value
		queue_redraw()
var dragging: bool:
	get:
		return _dragging
## Where the pointer pressed the card, in card-local coordinates.
var grab_offset := Vector2.ZERO

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.global_position
			grab_offset = event.position
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				drag_released.emit(self, event.global_position)
			else:
				tapped.emit(self)
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			drag_moved.emit(self, event.global_position)
		accept_event()


func _draw() -> void:
	if selected:
		var glow := StyleBoxFlat.new()
		glow.draw_center = false
		glow.set_border_width_all(4)
		glow.set_corner_radius_all(16)
		glow.border_color = Color(1.0, 0.84, 0.35)
		glow.shadow_color = Color(1.0, 0.8, 0.3, 0.55)
		glow.shadow_size = 14
		draw_style_box(glow, Rect2(Vector2.ZERO, size).grow(3))
	draw_texture_rect(art, Rect2(Vector2.ZERO, size), false, Color.WHITE if affordable else Color(0.5, 0.5, 0.55))
