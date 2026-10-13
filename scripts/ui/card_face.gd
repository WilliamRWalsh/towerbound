class_name CardFace
extends RefCounted
## Draws a card's face from its CardData: the painting under the shared gold frame, the icon, the
## cost on the gem, the title in small caps, the description, and the three stat boxes. Laid out
## in the card art's own pixels (830 × 1429, as tools/export_card_faces.py measures them) and
## scaled to whatever size the card is shown at. Text is filled in from the card's numbers when
## the face is built, so it never goes stale.

const SIZE := Vector2(830, 1429)
const FRAME := preload("res://assets/cards/frame.png")
const PAINTING_RECT := Rect2(44, 43, 741, 805)
const ICON_RECT := Rect2(98, 1043, 128, 128)
const COST_RECT := Rect2(13, 4, 284, 284)

const TITLE_CENTER_X := 418.0
const TITLE_BASELINE := 947.0
const TITLE_INITIAL_SIZE := 60
const TITLE_SIZE := 47
const BODY_LEFT := 272.0
const BODY_WIDTH := 472.0
const BODY_FIRST_BASELINE := 1080.0
const BODY_LINE_STEP := 50.0
const BODY_SIZE := 38
const BODY_LINES := 3
## Each stat box's interior x range; values are centered on STAT_VALUE_Y, labels on STAT_LABEL_Y.
const STAT_BOXES := [Vector2(66, 276), Vector2(312, 538), Vector2(566, 750)]
## With an icon (assets/cards/stat_icons), the icon is centered on the box's slot and the text
## moves right to make room.
const STAT_ICON_SLOTS := [Vector2(123, 1281), Vector2(356, 1281), Vector2(614, 1281)]
const STAT_TEXT_X_WITH_ICON := [206.0, 446.0, 702.0]
const STAT_VALUE_Y := 1282.0
const STAT_LABEL_Y := 1330.0
const STAT_VALUE_SIZE := 62
const STAT_LABEL_SIZE := 26

const INK := Color8(36, 28, 22)
const STAT_INK := Color8(238, 228, 205)
const LABEL_INK := Color8(226, 206, 160)

var _data: CardData
var _title_font: Font
var _body_font: Font
var _cost: Texture2D
var _body_size := BODY_SIZE
var _body_lines: PackedStringArray = []
## Each stat: [value, label, value font size, icon or null].
var _stats: Array = []


## `context` holds battle values the text can show (e.g. {castle_max}).
func _init(data: CardData, title_font: Font, body_font: Font, context: Dictionary = {}) -> void:
	_data = data
	_title_font = title_font
	_body_font = body_font
	_cost = load("res://assets/ui/mana_%d.png" % clampi(data.cost, 0, 10))
	var values := data.text_values(context)
	_wrap_description(data.description.format(values))
	for i in mini(data.stats.size(), STAT_BOXES.size()):
		var parts := data.stats[i].format(values).split("|")
		var value := parts[0]
		var icon: Texture2D = load("res://assets/cards/stat_icons/%s.png" % parts[2]) if parts.size() > 2 else null
		var width: float = STAT_BOXES[i].y - STAT_BOXES[i].x - 36.0
		if icon:
			width = STAT_BOXES[i].y - STAT_ICON_SLOTS[i].x - icon.get_width() * 0.5 - 24.0
		var size := STAT_VALUE_SIZE
		while size > 20 and _body_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			size -= 2
		_stats.append([value, parts[1] if parts.size() > 1 else "", size, icon])


## The description, wrapped to the text box and spelled out line by line.
func description_lines() -> PackedStringArray:
	return _body_lines


## The stat boxes' text, as "value LABEL". Each stat in the data is "value|LABEL", or
## "value|LABEL|icon" to show an icon from assets/cards/stat_icons.
func stat_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for stat in _stats:
		texts.append("%s %s" % [stat[0], stat[1]])
	return texts


## Draws the face filling `rect_size` on `canvas`, multiplied by `tint` (dimmed when unaffordable).
func draw(canvas: CanvasItem, rect_size: Vector2, tint := Color.WHITE) -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, rect_size / SIZE)
	if _data.painting:
		canvas.draw_texture_rect(_data.painting, PAINTING_RECT, false, tint)
	canvas.draw_texture_rect(FRAME, Rect2(Vector2.ZERO, SIZE), false, tint)
	if _data.icon:
		canvas.draw_texture_rect(_data.icon, ICON_RECT, false, tint)
	canvas.draw_texture_rect(_cost, COST_RECT, false, tint)
	_draw_title(canvas, tint)
	for i in _body_lines.size():
		canvas.draw_string(_body_font, Vector2(BODY_LEFT, BODY_FIRST_BASELINE + i * BODY_LINE_STEP), _body_lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, _body_size, INK * tint)
	for i in _stats.size():
		var box: Vector2 = STAT_BOXES[i]
		var text_x := (box.x + box.y) * 0.5
		var icon: Texture2D = _stats[i][3]
		if icon:
			var slot: Vector2 = STAT_ICON_SLOTS[i]
			canvas.draw_texture(icon, slot - icon.get_size() * 0.5, tint)
			text_x = STAT_TEXT_X_WITH_ICON[i]
		_draw_centered(canvas, _body_font, _stats[i][0], text_x, STAT_VALUE_Y, _stats[i][2], STAT_INK * tint)
		_draw_centered(canvas, _title_font, _stats[i][1], text_x, STAT_LABEL_Y, STAT_LABEL_SIZE, LABEL_INK * tint)
	canvas.draw_set_transform(Vector2.ZERO)


## The title in small caps: each word's initial larger, the rest smaller, all on one baseline.
func _draw_title(canvas: CanvasItem, tint: Color) -> void:
	var pieces: Array = []
	var words := _data.title.to_upper().split(" ", false)
	for i in words.size():
		if i > 0:
			pieces.append([" ", TITLE_SIZE])
		pieces.append([words[i].left(1), TITLE_INITIAL_SIZE])
		pieces.append([words[i].substr(1), TITLE_SIZE])
	var total := 0.0
	for piece in pieces:
		total += _title_font.get_string_size(piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, piece[1]).x
	var x := TITLE_CENTER_X - total * 0.5
	for piece in pieces:
		canvas.draw_string(_title_font, Vector2(x, TITLE_BASELINE), piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, piece[1], INK * tint)
		x += _title_font.get_string_size(piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, piece[1]).x


## Text centered on (`center_x`, `center_y`), halfway between its ascender and descender.
func _draw_centered(canvas: CanvasItem, font: Font, text: String, center_x: float, center_y: float, size: int,
		color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center_y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	canvas.draw_string(font, Vector2(center_x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Greedy word wrap into the text box, shrinking the font until it fits in BODY_LINES lines.
func _wrap_description(text: String) -> void:
	_body_size = BODY_SIZE
	while true:
		_body_lines = _wrap(text, _body_size)
		if _body_lines.size() <= BODY_LINES or _body_size <= 24:
			return
		_body_size -= 2


func _wrap(text: String, size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if line.is_empty() or _body_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= BODY_WIDTH:
			line = candidate
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines
