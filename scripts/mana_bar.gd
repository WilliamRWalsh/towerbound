class_name ManaBar
extends Control
## Vertical mana bar on the right edge: a crystal fill rising from 0 at the bottom to the maximum
## at the top, capped by the card-style gem showing the current mana. Display only.

const GEM_TEXTURE := preload("res://assets/ui/mana_gem.png")
const GEM_SIZE := 78.0
const TRACK_WIDTH := 26.0
const FRAME := 4.0
const FILL_TIME := 0.35
const SURGE_TIME := 0.5

const GOLD := Color(0.86, 0.66, 0.3)
const GOLD_DARK := Color(0.45, 0.3, 0.12)
const TRACK := Color(0.05, 0.08, 0.18, 0.92)
const CRYSTAL_TOP := Color(0.55, 0.85, 1.0)
const CRYSTAL_BOTTOM := Color(0.12, 0.35, 0.9)

@export var max_value := 10

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
var _flash := 0.0:
	set(new_value):
		_flash = new_value
		queue_redraw()
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


func _track_rect() -> Rect2:
	return Rect2(size.x * 0.5 - TRACK_WIDTH * 0.5, GEM_SIZE * 0.5, TRACK_WIDTH, size.y - GEM_SIZE * 0.5)


## Canvas position of the fill surface at a given mana level.
func _surface_point(level: float) -> Vector2:
	var inner := _track_rect().grow(-3.0)
	var fraction := clampf(level / max_value, 0.0, 1.0)
	return get_global_transform() * Vector2(inner.get_center().x, inner.end.y - inner.size.y * fraction)


func _draw() -> void:
	var center_x := size.x * 0.5
	var track := _track_rect()

	# Gold frame and dark channel.
	_draw_capsule(track.grow(FRAME + 2.0), GOLD_DARK)
	_draw_capsule(track.grow(FRAME), GOLD)
	_draw_capsule(track, TRACK.lerp(Color(0.5, 0.05, 0.05), _flash * 0.6))

	# Crystal fill, rising from the bottom.
	var inner := track.grow(-3.0)
	var fraction := clampf(_shown / max_value, 0.0, 1.0)
	if fraction > 0.0:
		var fill_height := inner.size.y * fraction
		var fill := Rect2(inner.position.x, inner.end.y - fill_height, inner.size.x, fill_height)
		var top_color := CRYSTAL_BOTTOM.lerp(CRYSTAL_TOP, fraction)
		var points := PackedVector2Array([fill.position, Vector2(fill.end.x, fill.position.y), fill.end, Vector2(fill.position.x, fill.end.y)])
		draw_polygon(points, PackedColorArray([top_color, top_color, CRYSTAL_BOTTOM, CRYSTAL_BOTTOM]))
		# Glassy highlight down the left side and a bright surface line.
		draw_rect(Rect2(fill.position + Vector2(3, 2), Vector2(4, maxf(0.0, fill.size.y - 4))), Color(1, 1, 1, 0.3))
		draw_line(fill.position, Vector2(fill.end.x, fill.position.y), Color(0.85, 0.97, 1.0, 0.95), 2.0)
	if _surge > 0.0:
		var surface_y := inner.end.y - inner.size.y * fraction
		draw_rect(Rect2(inner.position.x, surface_y - 5.0, inner.size.x, 10.0), Color(0.75, 0.95, 1.0, 0.7 * _surge))
		draw_circle(Vector2(center_x, surface_y), 16.0 * _surge + 4.0, Color(0.5, 0.8, 1.0, 0.35 * _surge))

	# One notch per mana.
	for i in range(1, max_value):
		var y := inner.end.y - inner.size.y * float(i) / max_value
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + 7, y), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(inner.end.x - 7, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.35), 1.5)

	# Gem with the current amount.
	var gem := Rect2(center_x - GEM_SIZE * 0.5, 0, GEM_SIZE, GEM_SIZE)
	draw_texture_rect(GEM_TEXTURE, gem, false)
	if _number:
		draw_texture_rect(_number, gem, false)


func _draw_capsule(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(rect.size.x * 0.5))
	draw_style_box(box, rect)
