class_name ManaBar
extends Gauge
## Vertical mana bar on the right edge: a crystal fill rising from 0 at the bottom to the maximum
## at the top, capped by the card-style gem showing the current mana. Display only.

const GEM_TEXTURE := preload("res://assets/ui/mana_gem.png")
const FILL_TIME := 0.35
const SURGE_TIME := 0.5

const CRYSTAL_TOP := Color(0.55, 0.85, 1.0)
const CRYSTAL_BOTTOM := Color(0.12, 0.35, 0.9)

## Current mana. Mana still riding a wisp toward the bar isn't shown until the wisp lands.
var value := 0.0:
	set(new_value):
		value = new_value
		_refresh()

## Mana granted but not yet shown because its wisp is still in flight.
var _incoming := 0.0

var _shown := 0.0:
	set(new_value):
		_shown = new_value
		queue_redraw()
var _number: Texture2D = null
var _fill_tween: Tween
## Brightness of the glow where a wisp just landed.
var _surge := 0.0:
	set(new_value):
		_surge = new_value
		queue_redraw()


## Shows the starting value immediately, without the fill animation.
func reset(new_value: float) -> void:
	_incoming = 0.0
	value = new_value
	_fill_tween.kill()
	_shown = new_value


## Sends a wisp carrying `amount` mana from a canvas position into the bar. Call it before
## raising `value`, so the bar holds that amount back until the wisp lands.
func send_wisp(from: Vector2, amount: float) -> void:
	_incoming += amount
	var wisp := ManaWisp.launch(get_parent(), from, func() -> Vector2: return _surface_point(_shown + amount * 0.5))
	wisp.arrived.connect(func() -> void:
		_incoming = maxf(0.0, _incoming - amount)
		_refresh()
		_surge = 1.0
		create_tween().tween_property(self, "_surge", 0.0, SURGE_TIME))


## Pulses the bar red, e.g. when a card costs more mana than is available.
func flash_insufficient() -> void:
	var tween := create_tween()
	_flash = 1.0
	tween.tween_property(self, "_flash", 0.0, 0.45)


func _refresh() -> void:
	var shown := maxf(0.0, value - _incoming)
	var whole := floori(shown + 0.001)
	_number = load("res://assets/ui/mana_%d.png" % whole) if whole <= 10 else null
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(self, "_shown", shown, FILL_TIME)


## Canvas position of the fill surface at a given mana level.
func _surface_point(level: float) -> Vector2:
	return get_global_transform() * Vector2(_inner_rect().get_center().x, _surface_y(level))


func _draw() -> void:
	_draw_gauge(_shown, CRYSTAL_TOP, CRYSTAL_BOTTOM)
	if _surge > 0.0:
		var inner := _inner_rect()
		var surface_y := _surface_y(_shown)
		draw_rect(Rect2(inner.position.x, surface_y - 5.0, inner.size.x, 10.0), Color(0.75, 0.95, 1.0, 0.7 * _surge))
		draw_circle(Vector2(size.x * 0.5, surface_y), 16.0 * _surge + 4.0, Color(0.5, 0.8, 1.0, 0.35 * _surge))

	# Gem with the current amount.
	draw_texture_rect(GEM_TEXTURE, _cap_rect(), false)
	if _number:
		draw_texture_rect(_number, _cap_rect(), false)
