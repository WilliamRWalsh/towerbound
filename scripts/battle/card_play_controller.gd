class_name CardPlayController
extends Node
## Turns the player's taps and drags into card plays. Keeps the hand drawn to size each
## preparation phase, selects and aims cards, plays them on release or drop, asks for a choice
## when a card needs one (which upgrade), and runs discard mode. A card is spent, its mana paid
## and the card discarded, exactly once and only on a successful play; a cancel or an invalid
## target spends nothing. The Battle decides whether cards can be played at all.

## The player tried a card that can't be played right now.
signal card_rejected(card: CardView, reason: Rejection)
## A card was selected for aiming (true) or put back (false).
signal aiming_changed(aiming: bool)

enum Rejection { NO_MANA, NO_TARGET }

const CARD_SCENE := preload("res://scenes/card_view.tscn")
## Discards allowed per wave, refilled at the start of each preparation phase.
const DISCARDS_PER_WAVE := 1

@export var battle: Battle
@export var field: Battlefield
@export var hand: Hand
## Pops up over a tower when a card needs a choice; the selected card waits, unspent, for the pick.
@export var chooser: UpgradeChooser
## Arms discard mode: the next card tapped is thrown away without being played.
@export var discard_button: Button

var _active_card: CardView = null:
	set(card):
		var was_aiming := _active_card != null
		_active_card = card
		if was_aiming != (card != null):
			aiming_changed.emit(card != null)
## Where the selected card waits to be played while the chooser is open.
var _choice_target: CardTarget
var _discarding := false
var _discards_left := DISCARDS_PER_WAVE


func _ready() -> void:
	battle.preparation_started.connect(_on_preparation_started)
	battle.ended.connect(_on_battle_ended)
	battle.mana.changed.connect(_on_mana_changed)
	chooser.chosen.connect(_on_choice)
	discard_button.pressed.connect(func() -> void: _set_discarding(not _discarding))


func _process(_delta: float) -> void:
	_update_discard_button()


## True while a card is selected and being aimed.
func is_aiming() -> bool:
	return _active_card != null


func is_discarding() -> bool:
	return _discarding


func _on_preparation_started(_number: int, _wave: WaveConfig) -> void:
	_discards_left = DISCARDS_PER_WAVE
	_refill_hand()


## The Battle has already stopped everything else; card play stops too.
func _on_battle_ended(_result: Battle.State) -> void:
	_cancel()
	_set_discarding(false)


func _on_mana_changed(_value: float) -> void:
	for card in hand.get_cards():
		card.affordable = _has_mana(card.data.cost)


## Draws until the hand is full; unplayed cards stay. Stops quietly if the deck runs dry.
func _refill_hand() -> void:
	while hand.get_cards().size() < battle.level.hand_size:
		var data := battle.deck.draw()
		if data == null:
			return
		var card: CardView = CARD_SCENE.instantiate()
		card.data = data
		card.text_context = {"castle_max": str(battle.level.castle_health)}
		card.tapped.connect(_on_card_tapped)
		card.drag_started.connect(_on_card_drag_started)
		card.drag_moved.connect(_on_card_drag_moved)
		card.drag_released.connect(_on_card_drag_released)
		hand.add_card(card)
		card.affordable = _has_mana(data.cost)
		card.discard_target = _discarding


func _unhandled_input(event: InputEvent) -> void:
	if _discarding:
		# Escape or a tap anywhere off the cards backs out of discard mode.
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			_set_discarding(false)
			get_viewport().set_input_as_handled()
		return
	if _active_card == null or _active_card.dragging:
		return
	if chooser.is_open():
		# Escape or a tap anywhere off the choice buttons backs out without spending anything.
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			_cancel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_active_card.data.update_targeting(field, event.global_position, true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active_card.data.update_targeting(field, event.global_position, true)
		# Tap mode: play on release; an invalid target keeps the card selected for another try.
		if not event.pressed and not _try_play(_active_card, event.global_position):
			_check_playable(_active_card)
		get_viewport().set_input_as_handled()


## In discard mode a tapped card is discarded; otherwise it is raised for play, or shakes if it
## can't be played right now.
func _on_card_tapped(card: CardView) -> void:
	if _discarding:
		_discard(card)
	elif _active_card == card:
		_cancel()
	elif _can_select(card):
		_select(card)


func _on_card_drag_started(card: CardView) -> void:
	if _discarding:
		return
	if _can_select(card):
		_select(card)
	elif card == _active_card:
		_cancel()


func _on_card_drag_moved(card: CardView, global_pos: Vector2) -> void:
	if card != _active_card:
		return
	hand.drag_card_to(card, global_pos)
	card.data.update_targeting(field, global_pos, not hand.is_over_hand(global_pos))


func _on_card_drag_released(card: CardView, global_pos: Vector2) -> void:
	if card != _active_card:
		hand.layout()
		return
	# Dropping anywhere invalid returns the card to the hand without spending anything.
	if not _try_play(card, global_pos):
		_cancel()


func _has_mana(cost: int) -> bool:
	return battle.mana.can_afford(cost)


func _can_select(card: CardView) -> bool:
	return battle.can_play_cards() and _check_playable(card)


## True when the card could be played now. Otherwise shakes it and reports why: not enough mana,
## or no valid target (e.g. Repair at full health).
func _check_playable(card: CardView) -> bool:
	if not _has_mana(card.data.cost):
		hand.shake(card)
		card_rejected.emit(card, Rejection.NO_MANA)
		return false
	if not card.data.can_play(field):
		hand.shake(card)
		card_rejected.emit(card, Rejection.NO_TARGET)
		return false
	return true


func _select(card: CardView) -> void:
	chooser.close()
	if _active_card:
		_active_card.selected = false
		_active_card.data.end_targeting(field)
	_active_card = card
	card.selected = true
	card.data.begin_targeting(field)
	hand.layout()


## Puts the selected card back in the hand, spending nothing.
func _cancel() -> void:
	chooser.close()
	if _active_card:
		_active_card.selected = false
		_active_card.data.end_targeting(field)
	_active_card = null
	hand.layout()


## Plays the card at a canvas position. On success the card leaves the hand for the discard pile
## and its mana is spent, exactly once. On failure nothing changes. A card that needs a choice
## there (Upgrade on a tower with both upgrades open) opens the chooser and returns true; it is
## played, or not, once the player picks.
func _try_play(card: CardView, global_pos: Vector2) -> bool:
	if not battle.can_play_cards() or hand.is_over_hand(global_pos) or not _has_mana(card.data.cost):
		return false
	var target := card.data.target_at(field, global_pos)
	if target == null:
		return false
	var options := card.data.choices(field, target)
	if not options.is_empty():
		_choice_target = target
		chooser.open(target.position, options)
		hand.layout()
		return true
	if not card.data.play(field, target):
		return false
	_finish_play(card)
	return true


## Plays the selected card with the option picked in the chooser.
func _on_choice(index: int) -> void:
	var card := _active_card
	chooser.close()
	if card == null or not battle.can_play_cards() or not _has_mana(card.data.cost) \
			or not card.data.play(field, _choice_target, index):
		_cancel()
		return
	_finish_play(card)


## The card was played: it leaves the hand for the discard pile and its mana is spent.
func _finish_play(card: CardView) -> void:
	_active_card = null
	card.data.end_targeting(field)
	hand.remove_card(card)
	battle.deck.discard(card.data)
	battle.mana.spend(card.data.cost)


## Arms or disarms discard mode. Arming drops any selected card back into the hand.
func _set_discarding(on: bool) -> void:
	on = on and battle.can_play_cards() and _discards_left > 0 and not hand.get_cards().is_empty()
	if on:
		_cancel()
	_discarding = on
	for card in hand.get_cards():
		card.discard_target = on
	_update_discard_button()


## Throws a card onto the discard pile without playing it. Costs no mana, but uses up the
## wave's discard. Some cards do something when thrown away (Barricade leaves caltrops).
func _discard(card: CardView) -> void:
	if not _discarding or _discards_left <= 0 or not battle.can_play_cards():
		return
	_discards_left -= 1
	_set_discarding(false)
	hand.discard_card(card)
	battle.deck.discard(card.data)
	card.data.discard(field)


## "Cancel" while armed; greyed out once this wave's discard is used or the battle is over.
func _update_discard_button() -> void:
	discard_button.text = "Cancel" if _discarding else "Discard"
	discard_button.disabled = not _discarding and (_discards_left <= 0 or not battle.can_play_cards())
