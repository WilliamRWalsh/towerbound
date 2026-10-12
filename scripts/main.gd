extends Node
## Battle screen prototype: the woodland map, its build grid, and a hand of tower cards.
## Owns placement state; cards, hand, and grid only report input and display previews.

## Test hand until the deck arrives: two of each tower card.
const HAND: Array[PackedScene] = [
	preload("res://scenes/card.tscn"), preload("res://scenes/card.tscn"),
	preload("res://scenes/cannon_card.tscn"), preload("res://scenes/cannon_card.tscn"),
]
const STARTING_MANA := 8
const MAX_MANA := 10
const MANA_BAR_HEIGHT := 470.0
const CASTLE_HEALTH := 20
## Seconds from the start of the battle until the first wave marches.
const PREPARE_TIME := 10.0
const FIRST_WAVE: WaveConfig = preload("res://data/waves/wave_1.tres")

const RESTART_BUTTON_SIZE := Vector2(130, 56)

enum Phase { PREPARING, COMBAT, CLEARED }

@onready var _grid: BuildGrid = $Battlefield/BuildGrid
@onready var _hand: Hand = $HandLayer/Hand
@onready var _mana_bar: ManaBar = $HandLayer/ManaBar
@onready var _spawner: EnemySpawner = $Battlefield/Spawner
@onready var _banner: Banner = $MessageLayer/Banner

var _castle_health := CASTLE_HEALTH
var _phase := Phase.PREPARING
var _wave_number := 1
## Enemies of the current wave still walking (spawned, not yet killed or at the castle).
var _active_enemies := 0
var _prepare_timer: Timer
var _restart_button: Button

var _active_card: TowerCard = null
## Fractional, since kills grant a tenth of a mana.
var _mana := 0.0:
	set(value):
		_mana = snappedf(clampf(value, 0.0, MAX_MANA), 0.01)
		_mana_bar.value = _mana
		for card in _hand.get_cards():
			card.affordable = _has_mana(card.cost)


func _ready() -> void:
	for card_scene in HAND:
		var card: TowerCard = card_scene.instantiate()
		card.tapped.connect(_on_card_tapped)
		card.drag_started.connect(_on_card_drag_started)
		card.drag_moved.connect(_on_card_drag_moved)
		card.drag_released.connect(_on_card_drag_released)
		_hand.add_card(card)
	_mana_bar.max_value = MAX_MANA
	_mana = STARTING_MANA
	_mana_bar.reset(_mana)
	_add_restart_button()
	get_viewport().size_changed.connect(_fit_hand_to_safe_area)
	_fit_hand_to_safe_area()
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_spawner.finished.connect(_check_wave_end)
	_prepare_timer = Timer.new()
	_prepare_timer.one_shot = true
	_prepare_timer.timeout.connect(_start_wave)
	add_child(_prepare_timer)
	_start_preparation()


func _start_preparation() -> void:
	_phase = Phase.PREPARING
	_banner.show_message("Enemies Gathering")
	_banner.show_message("Prepare for Battle")
	_prepare_timer.start(PREPARE_TIME)


func _start_wave() -> void:
	_phase = Phase.COMBAT
	_banner.show_message("Enemies Attacking!", Banner.Style.DANGER)
	_spawner.start(FIRST_WAVE)


## The wave is over once everything has been sent and nothing is left walking.
func _check_wave_end() -> void:
	if _phase != Phase.COMBAT or not _spawner.done or _active_enemies > 0:
		return
	_phase = Phase.CLEARED
	_banner.show_message("Wave %d Defeated" % _wave_number, Banner.Style.VICTORY)


func _unhandled_input(event: InputEvent) -> void:
	if _active_card == null or _active_card.dragging:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_placement()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_grid.update_pointer(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_grid.update_pointer(event.global_position)
		# Tap mode: place on release; an invalid target keeps the card selected for another try.
		if not event.pressed:
			_try_play(_active_card, event.global_position)
		get_viewport().set_input_as_handled()


func _on_card_tapped(card: TowerCard) -> void:
	if _active_card == card:
		_cancel_placement()
	elif _can_afford(card):
		_select(card)


func _on_card_drag_started(card: TowerCard) -> void:
	if _can_afford(card):
		_select(card)


func _on_card_drag_moved(card: TowerCard, global_pos: Vector2) -> void:
	if card != _active_card:
		return
	_hand.drag_card_to(card, global_pos)
	_grid.update_pointer(global_pos, not _hand.is_over_hand(global_pos))


func _on_card_drag_released(card: TowerCard, global_pos: Vector2) -> void:
	if card != _active_card:
		_hand.layout()
		return
	# Dropping anywhere invalid returns the card to the hand without spending anything.
	if not _try_play(card, global_pos):
		_cancel_placement()


func _on_enemy_spawned(enemy: Enemy) -> void:
	_active_enemies += 1
	enemy.died.connect(_on_enemy_died)
	enemy.reached_castle.connect(_on_enemy_reached_castle)


## Enemies emit `died` exactly once, so each kill pays out once. The mana is granted now;
## the wisp only animates it into the bar.
func _on_enemy_died(enemy: Enemy) -> void:
	_active_enemies -= 1
	var granted := minf(enemy.stats.mana_reward, MAX_MANA - _mana)
	if granted > 0.0:
		_mana_bar.send_wisp(enemy.aim_point(), granted)
		_mana += granted
	_check_wave_end()


## No castle HUD or defeat yet; the count is logged for testing.
func _on_enemy_reached_castle(_enemy: Enemy, damage: int) -> void:
	_active_enemies -= 1
	_castle_health -= damage
	print("Castle hit: %d health left" % _castle_health)
	_check_wave_end()


## Tolerates float rounding left over from adding tenths.
func _has_mana(cost: int) -> bool:
	return cost <= _mana + 0.001


## Rejects unaffordable cards with a shake and a flash of the mana bar.
func _can_afford(card: TowerCard) -> bool:
	if _has_mana(card.cost):
		return true
	_hand.shake(card)
	_mana_bar.flash_insufficient()
	return false


func _select(card: TowerCard) -> void:
	if _active_card:
		_active_card.selected = false
	_active_card = card
	card.selected = true
	_grid.begin_placement(card.tower_scene, card.tower_stats)
	_hand.layout()


func _cancel_placement() -> void:
	if _active_card:
		_active_card.selected = false
	_active_card = null
	_grid.end_placement()
	_hand.layout()


## Places the card's tower at a canvas position. On success the card leaves the hand and its
## mana is spent, exactly once.
func _try_play(card: TowerCard, global_pos: Vector2) -> bool:
	if _hand.is_over_hand(global_pos) or not _has_mana(card.cost):
		return false
	if not _grid.place_tower(_grid.world_to_cell(global_pos), card.tower_scene, card.tower_stats):
		return false
	_active_card = null
	_grid.end_placement()
	_hand.remove_card(card)
	_mana -= card.cost
	return true


## Debug only: reloads the battle scene, which starts a completely fresh run.
func _add_restart_button() -> void:
	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.size = RESTART_BUTTON_SIZE
	_restart_button.add_theme_font_size_override("font_size", 24)
	_restart_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.05, 0.07, 0.14, 0.8 if state != "pressed" else 0.95)
		box.border_color = Color(0.86, 0.66, 0.3)
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		_restart_button.add_theme_stylebox_override(state, box)
	_restart_button.pressed.connect(func() -> void: get_tree().reload_current_scene())
	$HandLayer.add_child(_restart_button)


## Lifts the hand by the bottom safe-area inset (home indicator) so cards stay reachable, and
## centers the mana bar vertically on the right edge. Keeps the restart button below the notch.
func _fit_hand_to_safe_area() -> void:
	var window_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var inset_px := maxf(0.0, float(window_size.y - safe.end.y)) if safe.size.y > 0 else 0.0
	var top_inset_px := maxf(0.0, float(safe.position.y)) if safe.size.y > 0 else 0.0
	var view := get_viewport().get_visible_rect().size
	_hand.bottom_inset = inset_px * view.y / maxf(1.0, window_size.y)
	_mana_bar.size = Vector2(ManaBar.GEM_SIZE, MANA_BAR_HEIGHT)
	_mana_bar.position = Vector2(view.x - ManaBar.GEM_SIZE - 2.0, (view.y - MANA_BAR_HEIGHT) * 0.5)
	var top_inset := top_inset_px * view.y / maxf(1.0, window_size.y)
	_restart_button.position = Vector2(view.x - RESTART_BUTTON_SIZE.x - 14.0, top_inset + 14.0)
