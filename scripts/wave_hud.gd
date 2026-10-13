class_name WaveHud
extends Control
## Top-left corner panel: the current wave ("Wave 3 / 10") with the phase underneath, e.g.
## "Battle in 5", "Fighting", or the result. Display only; main.gd feeds it.

const PANEL_SIZE := Vector2(200, 92)
const GOLD := Color(0.86, 0.66, 0.3)
const PANEL := Color(0.05, 0.07, 0.14, 0.82)
const TEXT := Color(1.0, 0.9, 0.62)

var _wave := 0
var _wave_count := 0
var _status := ""
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
	_font.font_weight = 700


func set_wave(wave: int, wave_count: int) -> void:
	_wave = wave
	_wave_count = wave_count
	queue_redraw()


func set_status(text: String) -> void:
	if text != _status:
		_status = text
		queue_redraw()


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = GOLD
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	draw_style_box(panel, Rect2(Vector2.ZERO, PANEL_SIZE))
	if _wave_count > 0:
		var wave_text := "Wave %d / %d" % [maxi(_wave, 1), _wave_count]
		draw_string(_font, Vector2(0, 44), wave_text, HORIZONTAL_ALIGNMENT_CENTER, PANEL_SIZE.x, 32, TEXT)
	draw_string(_font, Vector2(0, 76), _status, HORIZONTAL_ALIGNMENT_CENTER, PANEL_SIZE.x, 22, Color(TEXT, 0.8))
