class_name Battle
extends Node
## The battle's rules and its one authoritative state: a preparation countdown and combat for each
## wave in turn, then victory or defeat. Owns mana and the deck, sends each wave through the
## spawner, counts the enemies still in play, pays kill rewards, and ends the battle when the
## castle falls or the last wave is cleared. Everything else reads `state` and reacts to the
## signals; the HUD, hand, and cards never advance the battle themselves.

signal preparation_started(number: int, wave: WaveConfig)
signal combat_started(number: int)
signal wave_cleared(number: int)
## The battle is over; `result` is VICTORY or DEFEAT.
signal ended(result: State)
signal enemy_spawned(enemy: Enemy)
## A kill pays `amount` mana. Emitted just before the mana is added, so the mana bar can hold the
## amount back until the wisp carrying it lands.
signal kill_rewarded(enemy: Enemy, amount: float)

enum State { IDLE, PREPARING, COMBAT, VICTORY, DEFEAT }

@export var field: Battlefield

var state := State.IDLE
## 1-based number of the current wave; 0 before the battle starts.
var wave_number := 0
var level: LevelConfig
## The same pool for the whole battle, so listeners can connect before `setup`.
var mana := ManaPool.new()
var deck: Deck

## Enemies of the current wave still in play (spawned and not yet killed for good).
var _active_enemies := 0
var _prepare_timer: Timer


func _ready() -> void:
	_prepare_timer = Timer.new()
	_prepare_timer.one_shot = true
	_prepare_timer.timeout.connect(_start_combat)
	add_child(_prepare_timer)
	field.spawner.enemy_spawned.connect(_on_enemy_spawned)
	field.spawner.finished.connect(_check_wave_end)
	field.castle.destroyed.connect(defeat)


## Sets up a fresh battle for `battle_level`: full castle, starting mana, a shuffled deck. Call
## `start` to begin the first wave once listeners are connected.
func setup(battle_level: LevelConfig) -> void:
	level = battle_level
	mana.reset(level.starting_mana, level.max_mana)
	deck = Deck.new(level.deck)
	field.castle.reset(level.castle_health)
	wave_number = 0
	_active_enemies = 0


func start() -> void:
	_start_next_wave()


func is_over() -> bool:
	return state == State.VICTORY or state == State.DEFEAT


## Cards can be played (and discarded) during preparation and combat, never after the result.
func can_play_cards() -> bool:
	return state == State.PREPARING or state == State.COMBAT


func wave_count() -> int:
	return level.waves.size() if level else 0


## Seconds until the current wave marches, or 0 outside preparation.
func prepare_time_left() -> float:
	return _prepare_timer.time_left if state == State.PREPARING else 0.0


## The castle has fallen. Ends the battle at once, even mid-wave; defeat wins over a victory
## that hasn't been declared yet.
func defeat() -> void:
	_end(State.DEFEAT)


## Stops spawning, timers, and every enemy, and declares the result. Only the first result counts.
func _end(result: State) -> void:
	if is_over():
		return
	state = result
	_prepare_timer.stop()
	field.spawner.stop()
	field.enemies.halt_all()
	ended.emit(result)


func _start_next_wave() -> void:
	wave_number += 1
	state = State.PREPARING
	_prepare_timer.start(level.prepare_time)
	preparation_started.emit(wave_number, level.waves[wave_number - 1])


func _start_combat() -> void:
	if state != State.PREPARING:
		return
	state = State.COMBAT
	combat_started.emit(wave_number)
	field.spawner.start(level.waves[wave_number - 1])


func _on_enemy_spawned(enemy: Enemy) -> void:
	_active_enemies += 1
	enemy.died.connect(_on_enemy_died)
	enemy.attacked_castle.connect(_on_enemy_attacked_castle)
	enemy_spawned.emit(enemy)


## Enemies emit `died` exactly once, so each kill pays out once.
func _on_enemy_died(enemy: Enemy) -> void:
	_active_enemies -= 1
	if is_over():
		return
	var granted := mana.room_for(enemy.stats.mana_reward)
	if granted > 0.0:
		kill_rewarded.emit(enemy, granted)
		mana.add(granted)
	_check_wave_end()


func _on_enemy_attacked_castle(_enemy: Enemy, damage: float) -> void:
	if not is_over():
		field.castle.take_damage(damage)


## The wave is over once everything has been sent and nothing is left alive.
func _check_wave_end() -> void:
	if state != State.COMBAT or not field.spawner.done or _active_enemies > 0:
		return
	wave_cleared.emit(wave_number)
	if state != State.COMBAT:
		return  # a listener ended the battle
	if wave_number >= wave_count():
		_end(State.VICTORY)
	else:
		_start_next_wave()
