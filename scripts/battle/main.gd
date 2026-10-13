extends Node
## Battle screen coordinator for one level: the battlefield, the hand drawn from the level's deck,
## and card play. The Battle owns the rules and state (waves, mana, deck, result) and the Castle
## owns castle health; this screen turns player input into card plays and keeps the HUD in step.
## Cards, hand, grid, and HUD only report input and display.

const CARD_SCENE := preload("res://scenes/card.tscn")
## Tallest the health and mana bars get; they shrink on shorter screens to fit.
const BAR_MAX_HEIGHT := 470.0
const HUD_MARGIN := 14.0
const RESTART_BUTTON_SIZE := Vector2(130, 56)
const DISCARD_BUTTON_SIZE := Vector2(140, 54)
## Discards allowed per wave, refilled at the start of each preparation phase.
const DISCARDS_PER_WAVE := 1

@export var level: LevelConfig

@onready var _field: Battlefield = $Battlefield
@onready var _battle: Battle = $Battle
@onready var _hand: Hand = $HandLayer/Hand
@onready var _mana_bar: ManaBar = $HandLayer/ManaBar
@onready var _health_bar: HealthBar = $HandLayer/HealthBar
@onready var _hud: WaveHud = $HandLayer/WaveHud
@onready var _preview: WavePreview = $HandLayer/WavePreview
@onready var _banner: Banner = $MessageLayer/Banner

var _active_card: Card = null
var _restart_button: Button
## Bottom-left, above the hand. Pressing it arms discard mode: the next card tapped is thrown
## away without being played.
var _discard_button: Button
var _discarding := false
var _discards_left := DISCARDS_PER_WAVE
## Pops up over a tower when a card needs a choice (which upgrade); the selected card waits,
## unspent, for the pick at `_choice_pos`.
var _chooser: UpgradeChooser
var _choice_pos := Vector2.ZERO



func _ready() -> void:
	var castle := _field.castle
	castle.health_changed.connect(func(health: float, max_health: int) -> void: _health_bar.set_health(health, max_health))
	_battle.setup(level)
	_health_bar.set_health(castle.health, castle.max_health, false)
	_mana_bar.max_value = int(level.max_mana)
	_mana_bar.reset(_battle.mana.value)
	_battle.mana.changed.connect(_on_mana_changed)
	_add_restart_button()
	_add_discard_button()
	_chooser = UpgradeChooser.new()
	_chooser.chosen.connect(_on_choice)
	$HandLayer.add_child(_chooser)
	get_viewport().size_changed.connect(_fit_hud_to_safe_area)
	_fit_hud_to_safe_area()
	_battle.preparation_started.connect(_on_preparation_started)
	_battle.combat_started.connect(_on_combat_started)
	_battle.wave_cleared.connect(_on_wave_cleared)
	_battle.ended.connect(_on_battle_ended)
	_battle.kill_rewarded.connect(_on_kill_rewarded)
	_battle.start()


func _process(_delta: float) -> void:
	_update_discard_button()
	_preview.dimmed = _active_card != null
	match _battle.state:
		Battle.State.VICTORY:
			_hud.set_status("Victory")
		Battle.State.DEFEAT:
			_hud.set_status("Defeat")
		Battle.State.PREPARING:
			_hud.set_status("Battle in %d" % ceili(_battle.prepare_time_left()))
		_:
			_hud.set_status("Fighting")


func _on_mana_changed(value: float) -> void:
	_mana_bar.value = value
	for card in _hand.get_cards():
		card.affordable = _has_mana(card.data.cost)


func _on_preparation_started(number: int, wave: WaveConfig) -> void:
	_hud.set_wave(number, _battle.wave_count())
	var final := number == _battle.wave_count()
	_banner.show_message(wave.announcement_for(number), Banner.Style.DANGER if final else Banner.Style.NOTICE)
	_banner.show_message("Prepare for Battle")
	_preview.show_wave(wave)
	_discards_left = DISCARDS_PER_WAVE
	_refill_hand()


func _on_combat_started(_number: int) -> void:
	_field.grid.begin_wave()
	_preview.hide_wave()
	_banner.show_message("Enemies Attacking!", Banner.Style.DANGER)


func _on_wave_cleared(number: int) -> void:
	_field.grid.end_wave()
	_banner.show_message("Wave %d Defeated" % number, Banner.Style.VICTORY)


## The Battle has already stopped spawning, timers, and enemies; this stops card play and shows
## the result. Restart starts a fresh run.
func _on_battle_ended(result: Battle.State) -> void:
	_preview.hide_wave()
	_cancel_placement()
	_set_discarding(false)
	if result == Battle.State.VICTORY:
		_banner.show_message("Victory!", Banner.Style.VICTORY)
	else:
		_banner.clear()
		_banner.show_message("Defeat", Banner.Style.DANGER)
		_banner.show_message("The Castle Has Fallen", Banner.Style.DANGER)


## Draws until the hand is full; unplayed cards stay. Stops quietly if the deck runs dry.
func _refill_hand() -> void:
	while _hand.get_cards().size() < level.hand_size:
		var data := _battle.deck.draw()
		if data == null:
			return
		var card: Card = CARD_SCENE.instantiate()
		card.data = data
		card.tapped.connect(_on_card_tapped)
		card.drag_started.connect(_on_card_drag_started)
		card.drag_moved.connect(_on_card_drag_moved)
		card.drag_released.connect(_on_card_drag_released)
		_hand.add_card(card)
		card.affordable = _has_mana(data.cost)
		card.discard_target = _discarding


## The Battle grants the mana right after this; the wisp only animates it into the bar.
func _on_kill_rewarded(enemy: Enemy, amount: float) -> void:
	_mana_bar.send_wisp(enemy.aim_point(), amount)


func _unhandled_input(event: InputEvent) -> void:
	if _discarding:
		# Escape or a tap anywhere off the cards backs out of discard mode.
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			_set_discarding(false)
			get_viewport().set_input_as_handled()
		return
	if _active_card == null or _active_card.dragging:
		return
	if _chooser.is_open():
		# Escape or a tap anywhere off the choice buttons backs out without spending anything.
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			_cancel_placement()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_placement()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_active_card.data.update_targeting(_field, event.global_position, true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active_card.data.update_targeting(_field, event.global_position, true)
		# Tap mode: play on release; an invalid target keeps the card selected for another try.
		if not event.pressed and not _try_play(_active_card, event.global_position):
			_check_playable(_active_card)
		get_viewport().set_input_as_handled()


## In discard mode a tapped card is discarded; otherwise it is raised for play, or shakes if it
## can't be played right now.
func _on_card_tapped(card: Card) -> void:
	if _discarding:
		_discard(card)
	elif _active_card == card:
		_cancel_placement()
	elif _can_select(card):
		_select(card)


func _on_card_drag_started(card: Card) -> void:
	if _discarding:
		return
	if _can_select(card):
		_select(card)
	elif card == _active_card:
		_cancel_placement()


func _on_card_drag_moved(card: Card, global_pos: Vector2) -> void:
	if card != _active_card:
		return
	_hand.drag_card_to(card, global_pos)
	card.data.update_targeting(_field, global_pos, not _hand.is_over_hand(global_pos))


func _on_card_drag_released(card: Card, global_pos: Vector2) -> void:
	if card != _active_card:
		_hand.layout()
		return
	# Dropping anywhere invalid returns the card to the hand without spending anything.
	if not _try_play(card, global_pos):
		_cancel_placement()


func _has_mana(cost: int) -> bool:
	return _battle.mana.can_afford(cost)


## Rejects a card that can't be played right now with a shake: not enough mana (the mana bar
## flashes too), no valid target (e.g. Heal at full health), or the battle is over.
func _can_select(card: Card) -> bool:
	return _battle.can_play_cards() and _check_playable(card)


## True when the card could be played now; otherwise shakes it (and flashes the mana bar if
## mana is short).
func _check_playable(card: Card) -> bool:
	if not _has_mana(card.data.cost):
		_hand.shake(card)
		_mana_bar.flash_insufficient()
		return false
	if not card.data.can_play(_field):
		_hand.shake(card)
		return false
	return true


func _select(card: Card) -> void:
	_chooser.close()
	if _active_card:
		_active_card.selected = false
	_field.clear_targeting()
	_active_card = card
	card.selected = true
	card.data.begin_targeting(_field)
	_hand.layout()


func _cancel_placement() -> void:
	_chooser.close()
	if _active_card:
		_active_card.selected = false
	_active_card = null
	_field.clear_targeting()
	_hand.layout()


## Plays the card at a canvas position. On success the card leaves the hand for the discard pile
## and its mana is spent, exactly once. On failure nothing changes. A card that needs a choice
## there (Upgrade on a tower with both upgrades open) opens the chooser and returns true; it is
## played, or not, once the player picks.
func _try_play(card: Card, global_pos: Vector2) -> bool:
	if not _battle.can_play_cards() or _hand.is_over_hand(global_pos) or not _has_mana(card.data.cost):
		return false
	var options := card.data.choices_at(_field, global_pos)
	if not options.is_empty():
		var grid := _field.grid
		_choice_pos = global_pos
		_chooser.open(grid.to_global(grid.cell_center(grid.world_to_cell(global_pos))), options)
		_hand.layout()
		return true
	if not card.data.play(_field, global_pos):
		return false
	_finish_play(card)
	return true


## Plays the selected card with the option picked in the chooser.
func _on_choice(index: int) -> void:
	var card := _active_card
	_chooser.close()
	if card == null or not _battle.can_play_cards() or not _has_mana(card.data.cost) \
			or not card.data.play_choice(_field, _choice_pos, index):
		_cancel_placement()
		return
	_finish_play(card)


## The card was played: it leaves the hand for the discard pile and its mana is spent.
func _finish_play(card: Card) -> void:
	_active_card = null
	_field.clear_targeting()
	_hand.remove_card(card)
	_battle.deck.discard(card.data)
	_battle.mana.spend(card.data.cost)


## Arms or disarms discard mode. Arming drops any selected card back into the hand.
func _set_discarding(on: bool) -> void:
	on = on and _battle.can_play_cards() and _discards_left > 0 and not _hand.get_cards().is_empty()
	if on:
		_cancel_placement()
	_discarding = on
	for card in _hand.get_cards():
		card.discard_target = on
	_update_discard_button()


## Throws a card onto the discard pile without playing it. Costs no mana, but uses up the
## wave's discard. Some cards do something when thrown away (Barricade leaves caltrops).
func _discard(card: Card) -> void:
	if not _discarding or _discards_left <= 0 or not _battle.can_play_cards():
		return
	_discards_left -= 1
	_set_discarding(false)
	_hand.discard_card(card)
	_battle.deck.discard(card.data)
	card.data.on_discard(_field)


func _add_discard_button() -> void:
	_discard_button = Button.new()
	_discard_button.text = "Discard"
	_discard_button.focus_mode = Control.FOCUS_NONE
	_discard_button.size = DISCARD_BUTTON_SIZE
	_discard_button.theme_type_variation = &"DiscardButton"
	_discard_button.pressed.connect(func() -> void: _set_discarding(not _discarding))
	# Behind the hand, so a raised card covers the button rather than the other way round.
	$HandLayer.add_child(_discard_button)
	$HandLayer.move_child(_discard_button, _hand.get_index())


## "Cancel" while armed; greyed out once this wave's discard is used or the battle is over.
func _update_discard_button() -> void:
	_discard_button.text = "Cancel" if _discarding else "Discard"
	_discard_button.disabled = not _discarding and (_discards_left <= 0 or not _battle.can_play_cards())


## Debug only: reloads the battle scene, which starts a completely fresh run.
func _add_restart_button() -> void:
	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.size = RESTART_BUTTON_SIZE
	_restart_button.theme_type_variation = &"DebugButton"
	_restart_button.pressed.connect(func() -> void: get_tree().reload_current_scene())
	$HandLayer.add_child(_restart_button)


## Lifts the hand by the bottom safe-area inset (home indicator) so cards stay reachable, and
## places the health bar on the left edge and the mana bar on the right, between the top HUD and
## the hand. Keeps the HUD and restart button below the notch.
func _fit_hud_to_safe_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var inset_px := maxf(0.0, float(window_size.y - safe.end.y)) if safe.size.y > 0 else 0.0
	var top_inset_px := maxf(0.0, float(safe.position.y)) if safe.size.y > 0 else 0.0
	var view := get_viewport().get_visible_rect().size
	_hand.bottom_inset = inset_px * view.y / maxf(1.0, window_size.y)
	var top_inset := top_inset_px * view.y / maxf(1.0, window_size.y)
	var bars_top := top_inset + HUD_MARGIN + maxf(RESTART_BUTTON_SIZE.y, WaveHud.PANEL_SIZE.y) + 24.0
	var discard_y := view.y - _hand.bottom_inset - Hand.CARD_SIZE.y * 0.5 - DISCARD_BUTTON_SIZE.y - 24.0
	_discard_button.position = Vector2(HUD_MARGIN, discard_y)
	var bars_bottom := discard_y - 24.0
	var bar_height := minf(BAR_MAX_HEIGHT, bars_bottom - bars_top)
	var bar_y := (bars_top + bars_bottom - bar_height) * 0.5
	_health_bar.size = Vector2(Gauge.CAP_SIZE, bar_height)
	_health_bar.position = Vector2(2.0, bar_y)
	_mana_bar.size = Vector2(Gauge.CAP_SIZE, bar_height)
	_mana_bar.position = Vector2(view.x - Gauge.CAP_SIZE - 2.0, bar_y)
	_hud.position = Vector2(HUD_MARGIN, top_inset + HUD_MARGIN)
	_preview.position = Vector2(HUD_MARGIN, bars_top - 14.0)
	_preview.size = Vector2(view.x - HUD_MARGIN * 2.0, WavePreview.HEIGHT)
	_restart_button.position = Vector2(view.x - RESTART_BUTTON_SIZE.x - HUD_MARGIN, top_inset + HUD_MARGIN)
