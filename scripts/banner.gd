class_name Banner
extends Control
## Big center-screen announcements ("Enemies Gathering", "Wave 1 Defeated") on a dark ribbon.
## Messages queue up and play one after another. Display only; it never blocks input.

enum Style { NOTICE, DANGER, VICTORY }

const IN_TIME := 0.3
const HOLD_TIME := 2.0
const OUT_TIME := 0.45
const RIBBON_HEIGHT := 128.0

const TEXT_COLORS := {
	Style.NOTICE: Color(1.0, 0.9, 0.62),
	Style.DANGER: Color(1.0, 0.5, 0.36),
	Style.VICTORY: Color(1.0, 0.84, 0.3),
}
const RIBBON_COLORS := {
	Style.NOTICE: Color(0.05, 0.07, 0.14),
	Style.DANGER: Color(0.22, 0.03, 0.02),
	Style.VICTORY: Color(0.1, 0.08, 0.02),
}

var _queue: Array = []
var _showing := false
var _style := Style.NOTICE
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
	font.font_weight = 700
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = 58
	settings.outline_size = 14
	settings.outline_color = Color(0.08, 0.05, 0.03)
	settings.shadow_size = 6
	settings.shadow_color = Color(0, 0, 0, 0.55)
	settings.shadow_offset = Vector2(0, 4)
	_label = Label.new()
	_label.label_settings = settings
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	resized.connect(_layout)
	_layout()


func show_message(text: String, style := Style.NOTICE) -> void:
	_queue.append([text, style])
	if not _showing:
		_play_next()


## Drops anything queued or on screen, e.g. when the battle restarts.
func clear() -> void:
	_queue.clear()
	_showing = false
	modulate.a = 0.0


func _play_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var message: Array = _queue.pop_front()
	_label.text = message[0]
	_style = message[1]
	_label.label_settings.font_color = TEXT_COLORS[_style]
	queue_redraw()
	_label.scale = Vector2(0.82, 0.82)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, IN_TIME)
	tween.parallel().tween_property(_label, "scale", Vector2.ONE, IN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	tween.tween_callback(_play_next)


func _layout() -> void:
	_label.size = Vector2(size.x, RIBBON_HEIGHT)
	_label.position = Vector2(0, (size.y - RIBBON_HEIGHT) * 0.5)
	_label.pivot_offset = _label.size * 0.5
	queue_redraw()


func _draw() -> void:
	# A dark ribbon across the screen that fades out toward both edges, with thin gold rules.
	var top := (size.y - RIBBON_HEIGHT) * 0.5
	var ribbon: Color = RIBBON_COLORS[_style]
	var gold := Color(0.86, 0.66, 0.3, 0.9)
	_draw_band(top, RIBBON_HEIGHT, Color(ribbon, 0.8))
	_draw_band(top - 3.0, 2.0, gold)
	_draw_band(top + RIBBON_HEIGHT + 1.0, 2.0, gold)


## A horizontal band, solid in the middle and fading to clear at both screen edges.
func _draw_band(top: float, height: float, color: Color) -> void:
	var clear := Color(color, 0.0)
	var xs := [0.0, size.x * 0.28, size.x * 0.72, size.x]
	var colors := [clear, color, color, clear]
	for i in 3:
		draw_polygon(
			PackedVector2Array([Vector2(xs[i], top), Vector2(xs[i + 1], top), Vector2(xs[i + 1], top + height), Vector2(xs[i], top + height)]),
			PackedColorArray([colors[i], colors[i + 1], colors[i + 1], colors[i]]))
