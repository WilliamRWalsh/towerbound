class_name Gauge
extends Control
## Base for the vertical bars on the screen edges (mana, castle health): a gold-framed capsule whose
## fill rises from 0 at the bottom to `max_value` at the top, with a notch per point and a cap
## drawn at the top by the subclass. Display only.

const CAP_SIZE := 78.0
const TRACK_WIDTH := 26.0
const FRAME := 4.0

const TRACK := Color(0.05, 0.08, 0.18, 0.92)
const FLASH_BAD := Color(0.5, 0.05, 0.05)

@export var max_value := 10

## 0–1 strength of a red pulse in the channel.
var _flash := 0.0:
	set(new_value):
		_flash = new_value
		queue_redraw()


func _track_rect() -> Rect2:
	return Rect2(size.x * 0.5 - TRACK_WIDTH * 0.5, CAP_SIZE * 0.5, TRACK_WIDTH, size.y - CAP_SIZE * 0.5)


## The channel's inside, where the fill goes.
func _inner_rect() -> Rect2:
	return _track_rect().grow(-3.0)


## Canvas-local y of the fill surface at a given level.
func _surface_y(level: float) -> float:
	var inner := _inner_rect()
	return inner.end.y - inner.size.y * clampf(level / max_value, 0.0, 1.0)


## Gold frame, the dark channel, and the fill up to `level`, shaded from `bottom` to `top`
## (the top color is reached only when full).
func _draw_gauge(level: float, top: Color, bottom: Color) -> void:
	var track := _track_rect()
	_draw_capsule(track.grow(FRAME + 2.0), Palette.GOLD_DARK)
	_draw_capsule(track.grow(FRAME), Palette.GOLD)
	_draw_capsule(track, TRACK.lerp(FLASH_BAD, _flash * 0.6))

	var inner := _inner_rect()
	var fraction := clampf(level / max_value, 0.0, 1.0)
	if fraction > 0.0:
		var fill_height := inner.size.y * fraction
		var fill := Rect2(inner.position.x, inner.end.y - fill_height, inner.size.x, fill_height)
		var top_color := bottom.lerp(top, fraction)
		var points := PackedVector2Array([fill.position, Vector2(fill.end.x, fill.position.y), fill.end, Vector2(fill.position.x, fill.end.y)])
		draw_polygon(points, PackedColorArray([top_color, top_color, bottom, bottom]))
		# Glassy highlight down the left side and a bright surface line.
		draw_rect(Rect2(fill.position + Vector2(3, 2), Vector2(4, maxf(0.0, fill.size.y - 4))), Color(1, 1, 1, 0.3))
		draw_line(fill.position, Vector2(fill.end.x, fill.position.y), top.lerp(Color.WHITE, 0.7), 2.0)

	# One notch per point.
	for i in range(1, max_value):
		var y := inner.end.y - inner.size.y * float(i) / max_value
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + 7, y), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(inner.end.x - 7, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.35), 1.5)


## Square at the top of the bar where the subclass draws its cap.
func _cap_rect() -> Rect2:
	return Rect2(size.x * 0.5 - CAP_SIZE * 0.5, 0, CAP_SIZE, CAP_SIZE)


func _draw_capsule(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(rect.size.x * 0.5))
	draw_style_box(box, rect)
