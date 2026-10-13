class_name Card
extends Control
## A card in the hand, showing its CardData. Reports taps and drags; main.gd decides what they do
## and the hand positions the card.

signal tapped(card: Card)
signal drag_started(card: Card)
signal drag_moved(card: Card, global_pos: Vector2)
signal drag_released(card: Card, global_pos: Vector2)

const DRAG_THRESHOLD := 14.0
const BADGE_RADIUS := 15.0
## Badge center's distance in from the card's top and right edges.
const BADGE_INSET := 24.0

@export var data: CardData

var selected := false:
	set(value):
		selected = value
		queue_redraw()
## False when there isn't enough mana to play the card; it's drawn dimmed.
var affordable := true:
	set(value):
		affordable = value
		queue_redraw()
## True while discard mode is armed; the card gets a red outline as a discard target.
var discard_target := false:
	set(value):
		discard_target = value
		queue_redraw()
var dragging: bool:
	get:
		return _dragging
## True while it animates away after being discarded; the hand no longer lays it out.
var leaving := false
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
	elif discard_target:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.set_border_width_all(4)
		outline.set_corner_radius_all(16)
		outline.border_color = Color(1.0, 0.36, 0.28)
		outline.shadow_color = Color(1.0, 0.2, 0.1, 0.5)
		outline.shadow_size = 12
		draw_style_box(outline, Rect2(Vector2.ZERO, size).grow(3))
	draw_texture_rect(data.art, Rect2(Vector2.ZERO, size), false, Color.WHITE if affordable else Color(0.5, 0.5, 0.55))
	_draw_damage_badge()


## A small round badge in the top-right corner showing the damage type the card deals, so it can
## be matched against the wave preview's weaknesses and resistances.
func _draw_damage_badge() -> void:
	var type := data.damage_type()
	if type == Damage.NONE:
		return
	var center := Vector2(size.x - BADGE_INSET, BADGE_INSET)
	var dim := 1.0 if affordable else 0.55
	draw_circle(center + Vector2(1, 2), BADGE_RADIUS + 2.0, Color(0, 0, 0, 0.4))
	draw_circle(center, BADGE_RADIUS + 2.0, Color(0.86, 0.66, 0.3) * Color(dim, dim, dim))
	draw_circle(center, BADGE_RADIUS, Color(0.08, 0.07, 0.1))
	Damage.draw_icon(self, center, BADGE_RADIUS * 1.35, type)
	if not affordable:
		draw_circle(center, BADGE_RADIUS, Color(0, 0, 0, 0.4))
