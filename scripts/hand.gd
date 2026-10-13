class_name Hand
extends Control
## Lays out the cards in hand along the bottom edge: fanned and half tucked below the screen,
## with the selected card raised fully into view. Display only; main.gd owns the rules.

const CARD_SIZE := Vector2(180, 310)
const SPACING := 172.0  # center-to-center; cards overlap slightly
const FAN_DEGREES := 3.0
const RAISED_SCALE := 1.15
const RAISED_MARGIN := 16.0
const TWEEN_TIME := 0.14
const DRAW_TIME := 0.32
const DISCARD_TIME := 0.25

## Bottom safe-area inset (home indicator) in canvas units.
var bottom_inset := 0.0:
	set(value):
		bottom_inset = value
		layout()

var _tweens: Dictionary[Card, Tween] = {}


func _ready() -> void:
	resized.connect(layout)


func get_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for child in get_children():
		if child is Card and not child.is_queued_for_deletion() and not child.leaving:
			cards.append(child)
	return cards


## Adds a card, sliding it up from below the screen like it's being drawn.
func add_card(card: Card) -> void:
	card.size = CARD_SIZE
	card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	card.position = Vector2(size.x * 0.5 + SPACING * 2.0, size.y + 40.0)
	card.rotation = deg_to_rad(12.0)
	add_child(card)
	layout(true, DRAW_TIME)


func remove_card(card: Card) -> void:
	_tweens.erase(card)
	card.queue_free()
	layout()


## Discards a card: it lifts and fades away while the rest of the hand closes the gap.
func discard_card(card: Card) -> void:
	_kill_tween(card)
	card.leaving = true
	card.selected = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position:y", card.position.y - 90.0, DISCARD_TIME)
	tween.tween_property(card, "scale", card.scale * 0.85, DISCARD_TIME)
	tween.tween_property(card, "modulate", Color(0.6, 0.6, 0.6, 0.0), DISCARD_TIME)
	tween.chain().tween_callback(card.queue_free)


## Where the card sits (in hand coordinates) once raised as the selected card.
func raised_rect(card: Card) -> Rect2:
	var cards := get_cards()
	var spread := cards.find(card) - (cards.size() - 1) * 0.5
	var bottom := size.y - RAISED_MARGIN - bottom_inset
	var raised := CARD_SIZE * RAISED_SCALE
	return Rect2(Vector2(size.x * 0.5 + spread * SPACING - raised.x * 0.5, bottom - raised.y), raised)


## True when a canvas position is over the visible strip of the hand.
func is_over_hand(global_pos: Vector2) -> bool:
	return global_pos.y > get_global_rect().end.y - CARD_SIZE.y * 0.5 - bottom_inset


## Moves a dragged card with the pointer. Over the battlefield the card hides so the tower
## preview takes its place.
func drag_card_to(card: Card, global_pos: Vector2) -> void:
	_kill_tween(card)
	card.rotation = 0.0
	card.scale = Vector2.ONE
	card.z_index = 10
	card.global_position = global_pos - card.grab_offset
	card.modulate.a = 1.0 if is_over_hand(global_pos) else 0.0


## Wiggles a card that can't be played right now.
func shake(card: Card) -> void:
	var tween := create_tween()
	var base := card.rotation
	for angle in [0.08, -0.08, 0.05, -0.03]:
		tween.tween_property(card, "rotation", base + angle, 0.05)
	tween.tween_property(card, "rotation", base, 0.05)


func layout(animate := true, time := TWEEN_TIME) -> void:
	var cards := get_cards()
	var count := cards.size()
	for i in count:
		var card := cards[i]
		if card.dragging:
			continue
		var spread := i - (count - 1) * 0.5
		var center_x := size.x * 0.5 + spread * SPACING
		var target_pos: Vector2
		var target_rotation := 0.0
		var target_scale := Vector2.ONE
		if card.selected:
			target_pos = Vector2(center_x - CARD_SIZE.x * 0.5, size.y - RAISED_MARGIN - bottom_inset - CARD_SIZE.y)
			target_scale = Vector2.ONE * RAISED_SCALE
		else:
			# Half the card sits below the screen edge, curving slightly like a held hand.
			var tuck := size.y - CARD_SIZE.y * 0.5 - bottom_inset + spread * spread * 6.0
			target_pos = Vector2(center_x - CARD_SIZE.x * 0.5, tuck)
			target_rotation = deg_to_rad(spread * FAN_DEGREES)
		card.z_index = 10 if card.selected else 0
		card.modulate.a = 1.0
		_kill_tween(card)
		if animate:
			var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", target_pos, time)
			tween.tween_property(card, "rotation", target_rotation, time)
			tween.tween_property(card, "scale", target_scale, time)
			_tweens[card] = tween
		else:
			card.position = target_pos
			card.rotation = target_rotation
			card.scale = target_scale


func _kill_tween(card: Card) -> void:
	if _tweens.has(card):
		_tweens[card].kill()
		_tweens.erase(card)
