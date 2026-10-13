class_name WaveRunner
extends Node
## Runs a level's waves in order: a preparation countdown, then combat while the spawner sends the
## wave, until everything sent has been killed. Then the next wave's preparation, or the end of
## the level. Authoritative for the wave phase; main.gd reacts to its signals.

signal preparation_started(number: int, wave: WaveConfig)
signal combat_started(number: int)
signal wave_cleared(number: int)
signal level_cleared
signal enemy_spawned(enemy: Enemy)

enum Phase { IDLE, PREPARING, COMBAT, STOPPED }

@export var spawner: EnemySpawner

var phase := Phase.IDLE
## 1-based number of the current wave; 0 before the level starts.
var wave_number := 0

var _level: LevelConfig
## Enemies of the current wave still in play (spawned and not yet killed).
var _active_enemies := 0
var _prepare_timer: Timer


func _ready() -> void:
	_prepare_timer = Timer.new()
	_prepare_timer.one_shot = true
	_prepare_timer.timeout.connect(_start_combat)
	add_child(_prepare_timer)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.finished.connect(_check_wave_end)


func start(level: LevelConfig) -> void:
	_level = level
	wave_number = 0
	_active_enemies = 0
	_start_next_wave()


## Ends the level where it stands (victory or defeat): no more spawns, timers, or phase changes.
func stop() -> void:
	phase = Phase.STOPPED
	_prepare_timer.stop()
	spawner.stop()


func wave_count() -> int:
	return _level.waves.size() if _level else 0


## Seconds until the current wave marches, or 0 outside preparation.
func prepare_time_left() -> float:
	return _prepare_timer.time_left if phase == Phase.PREPARING else 0.0


func _start_next_wave() -> void:
	wave_number += 1
	phase = Phase.PREPARING
	_prepare_timer.start(_level.prepare_time)
	preparation_started.emit(wave_number, _level.waves[wave_number - 1])


func _start_combat() -> void:
	if phase != Phase.PREPARING:
		return
	phase = Phase.COMBAT
	combat_started.emit(wave_number)
	spawner.start(_level.waves[wave_number - 1])


func _on_enemy_spawned(enemy: Enemy) -> void:
	_active_enemies += 1
	enemy.died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy)


func _on_enemy_died(_enemy: Enemy) -> void:
	_active_enemies -= 1
	_check_wave_end()


## The wave is over once everything has been sent and nothing is left alive.
func _check_wave_end() -> void:
	if phase != Phase.COMBAT or not spawner.done or _active_enemies > 0:
		return
	wave_cleared.emit(wave_number)
	if phase != Phase.COMBAT:
		return  # a listener ended the battle
	if wave_number >= wave_count():
		phase = Phase.IDLE
		level_cleared.emit()
	else:
		_start_next_wave()
