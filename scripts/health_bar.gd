class_name HealthBar
extends Gauge
## Vertical castle health bar on the left edge, styled like the mana bar: a red fill capped by a
## faceted ruby heart showing the current health. Pulses red when the castle is struck and green when healed.
## Display only; main.gd feeds it from the Castle.

const HEART_TEXTURE := preload("res://assets/ui/heart_gem.png")
const FILL_TIME := 0.3
const PULSE_TIME := 0.45

const BLOOD_TOP := Color(1.0, 0.42, 0.34)
const BLOOD_BOTTOM := Color(0.55, 0.05, 0.06)
const HEAL_GLOW := Color(0.45, 1.0, 0.5)
const NUMBER_FILL := Color(240 / 255.0, 228 / 255.0, 205 / 255.0)
const NUMBER_STROKE := Color(18 / 255.0, 24 / 255.0, 48 / 255.0)

var _health := 0.0
var _shown := 0.0:
	set(new_value):
		_shown = new_value
		queue_redraw()
var _fill_tween: Tween
## 0–1 strength of the heal glow.
var _heal := 0.0:
	set(new_value):
		_heal = new_value
		queue_redraw()
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
	_font.font_weight = 700


func set_health(health: float, max_health: int, animate := true) -> void:
	var healed := health > _health
	_health = health
	max_value = max_health
	if _fill_tween:
		_fill_tween.kill()
	if not animate:
		_shown = health
		return
	_fill_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(self, "_shown", health, FILL_TIME)
	if healed:
		_heal = 1.0
		create_tween().tween_property(self, "_heal", 0.0, PULSE_TIME)
	else:
		_flash = 1.0
		create_tween().tween_property(self, "_flash", 0.0, PULSE_TIME)


func _draw() -> void:
	if _heal > 0.0:
		_draw_capsule(_track_rect().grow(FRAME + 2.0 + 8.0 * _heal), Color(HEAL_GLOW, 0.45 * _heal))
	_draw_gauge(_shown, BLOOD_TOP, BLOOD_BOTTOM)
	if _heal > 0.0:
		draw_rect(_inner_rect(), Color(HEAL_GLOW, 0.3 * _heal))
	_draw_heart(_cap_rect())


## Ruby heart gem (tools/draw_heart_gem.py) with the health number on it, the same size as the
## mana gem. Brightens when struck and turns green when healed.
func _draw_heart(cap: Rect2) -> void:
	var tint := Color.WHITE.lerp(Color(1.6, 1.4, 1.4), _flash).lerp(Color(0.7, 1.6, 0.8), _heal * 0.7)
	# A heart leaves its square's corners empty, so draw it a little larger to match the gem's weight.
	draw_texture_rect(HEART_TEXTURE, cap.grow(6.0), false, tint)

	# Rounds up, so the heart reads 0 only once the castle has fallen.
	var text := str(ceili(_health - 0.001))
	var font_size := 32 if text.length() < 2 else 28
	var center := cap.get_center() + Vector2(0, -2)
	var baseline := Vector2(cap.position.x, center.y + font_size * 0.36)
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, font_size, 7, NUMBER_STROKE)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, font_size, NUMBER_FILL)
