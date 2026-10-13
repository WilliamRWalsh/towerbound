class_name WavePreview
extends Control
## Panel under the top HUD showing what the coming wave sends: one column per enemy type with
## its art, how many, and its weaknesses (green ▲) and resistances (grey ▼) by damage type.
## Fades in for the preparation phase and out when combat starts, and fades back while a card
## is being aimed so it doesn't hide the battlefield. Display only; main.gd feeds it.

const HEIGHT := 150.0
const COLUMN_MAX := 132.0
const FADE_TIME := 0.3
## Faded opacity while a card is aimed.
const DIM_ALPHA := 0.2
## Tallest an enemy's art is drawn, in canvas units, and the share of its in-game size.
const ART_HEIGHT := 74.0
const ART_SCALE := 1.0
const ART_FEET_Y := 84.0
const ICON_SIZE := 26.0
const WEAK := Color(0.45, 0.9, 0.4)
const RESIST := Color(0.65, 0.65, 0.7)

var dimmed := false:
	set(value):
		if value != dimmed:
			dimmed = value
			_fade_to(_target_alpha())

var _showing := false
var _font: Font
var _fade: Tween
## One entry per enemy type: [EnemyStats, count, EnemyBody].
var _columns: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_font = get_theme_font(&"font", &"HudText")


## Fills the panel with the wave's enemies and fades it in.
func show_wave(wave: WaveConfig) -> void:
	for column in _columns:
		column[2].queue_free()
	_columns.clear()
	for entry in wave.enemy_counts():
		var enemy: Enemy = (entry[0] as PackedScene).instantiate()
		var body: EnemyBody = enemy.get_node("Body")
		enemy.remove_child(body)
		var stats := enemy.stats
		enemy.free()
		var in_game := body.scale.y
		body.scale = Vector2.ONE * minf(in_game * ART_SCALE, ART_HEIGHT / (body.chest_height * 1.75))
		add_child(body)
		_columns.append([stats, entry[1], body])
	_layout_columns()
	_showing = true
	visible = true
	_fade_to(_target_alpha())


func hide_wave() -> void:
	_showing = false
	_fade_to(0.0)


func _target_alpha() -> float:
	if not _showing:
		return 0.0
	return DIM_ALPHA if dimmed else 1.0


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_TIME)
	if alpha <= 0.0:
		_fade.tween_callback(func() -> void: visible = false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_columns()


func _column_width() -> float:
	return minf(COLUMN_MAX, (size.x - 20.0) / maxf(1.0, _columns.size()))


func _column_center(i: int) -> float:
	var width := _column_width()
	return size.x * 0.5 + (i - (_columns.size() - 1) * 0.5) * width


func _layout_columns() -> void:
	for i in _columns.size():
		var body: EnemyBody = _columns[i][2]
		body.position = Vector2(_column_center(i), ART_FEET_Y)
	queue_redraw()


func _draw() -> void:
	draw_style_box(get_theme_stylebox(&"panel", &"HudPanel"), Rect2(Vector2.ZERO, Vector2(size.x, HEIGHT)))
	for i in _columns.size():
		var stats: EnemyStats = _columns[i][0]
		var cx := _column_center(i)
		draw_string(_font, Vector2(cx - 60, 110), "×%d" % _columns[i][1], HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Palette.TEXT)
		_draw_traits(stats, cx, 131)


## Weak and resisted damage types as icons with an arrow, then a "gets back up" mark for enemies
## that revive.
func _draw_traits(stats: EnemyStats, cx: float, y: float) -> void:
	var marks: Array = []
	for type in Damage.Type.values():
		var m := stats.multiplier(type)
		if m > 1.01:
			marks.append([type, true])
		elif m < 0.99:
			marks.append([type, false])
	var step := ICON_SIZE + 16.0
	var count := marks.size() + (1 if stats.revives > 0 else 0)
	var x := cx - (count - 1) * step * 0.5
	for mark in marks:
		Damage.draw_icon(self, Vector2(x - 6, y), ICON_SIZE, mark[0])
		_draw_arrow(Vector2(x + 13, y), mark[1])
		x += step
	if stats.revives > 0:
		# Gets back up once killed: a curved arrow looping up.
		draw_arc(Vector2(x, y + 1), 9.0, PI * 0.1, PI * 1.6, 14, Palette.TEXT, 3.0)
		var tip := Vector2(x, y + 1) + Vector2.from_angle(PI * 1.6) * 9.0
		draw_colored_polygon(PackedVector2Array([tip + Vector2(7, -1), tip + Vector2(-2, -7), tip + Vector2(-1, 6)]), Palette.TEXT)


## A small ▲ (weak: takes more) or ▼ (resists: takes less) beside an icon.
func _draw_arrow(at: Vector2, weak: bool) -> void:
	var color := WEAK if weak else RESIST
	var points := PackedVector2Array([at + Vector2(-6, 4), at + Vector2(6, 4), at + Vector2(0, -6)]) if weak \
		else PackedVector2Array([at + Vector2(-6, -4), at + Vector2(6, -4), at + Vector2(0, 6)])
	draw_colored_polygon(points, color)
