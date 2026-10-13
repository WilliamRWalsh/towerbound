class_name UpgradeChooser
extends Control
## A pair of buttons that pops up over a tower so the player can pick which upgrade it gets.
## It only reports the pick; main.gd plays the card and spends its cost.

signal chosen(index: int)

const BUTTON_SIZE := Vector2(190, 92)
const GAP := 14.0
## How far above the anchor (the tower's cell center) the buttons sit, or below it (clearing the
## charge pips) for towers in the top half, where the HUD panels are.
const LIFT := 120.0
const DROP := 80.0
const MARGIN := 16.0

var _buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows one button per label, side by side beside `anchor` (canvas coordinates), kept on screen.
func open(anchor: Vector2, labels: PackedStringArray) -> void:
	close()
	var width := BUTTON_SIZE.x * labels.size() + GAP * (labels.size() - 1)
	var screen := get_viewport_rect().size
	var origin := anchor - Vector2(width * 0.5, LIFT + BUTTON_SIZE.y)
	if anchor.y < screen.y * 0.5:
		origin.y = anchor.y + DROP
	origin.x = clampf(origin.x, MARGIN, screen.x - MARGIN - width)
	for i in labels.size():
		var button := _make_button(labels[i])
		button.position = origin + Vector2((BUTTON_SIZE.x + GAP) * i, 0)
		button.pressed.connect(func() -> void: chosen.emit(i))
		add_child(button)
		_buttons.append(button)
	visible = true


func close() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	visible = false


func is_open() -> bool:
	return visible


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 26)
	for color in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color, Color(1.0, 0.92, 0.66))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.42, 0.26, 0.06, 0.96) if state == "pressed" else Color(0.2, 0.13, 0.05, 0.94)
		box.border_color = Color(1.0, 0.82, 0.3)
		box.set_border_width_all(3)
		box.set_corner_radius_all(16)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 8
		button.add_theme_stylebox_override(state, box)
	return button
