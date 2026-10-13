class_name EnemySpawner
extends Node
## Sends a wave's enemies down the path group by group, on a timer. Reports each spawn and when
## the last enemy of the wave has been sent.

signal enemy_spawned(enemy: Enemy)
signal finished

@export var world: Battlefield
## Sideways jitter in map pixels so a group doesn't walk in single file.
@export var spread := 20.0

## False from `start` until the wave's last enemy has been sent.
var done := true

## Remaining spawns as [delay before it, scene].
var _queue: Array = []
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_spawn_next)
	add_child(_timer)


func start(wave: WaveConfig) -> void:
	_queue.clear()
	for group in wave.groups:
		for i in group.enemies.size():
			_queue.append([group.pause_before if i == 0 else group.spacing, group.enemies[i]])
	done = _queue.is_empty()
	if done:
		finished.emit()
	else:
		_timer.start(maxf(0.01, _queue[0][0]))


func stop() -> void:
	_timer.stop()
	_queue.clear()
	done = true


func _spawn_next() -> void:
	var scene: PackedScene = _queue.pop_front()[1]
	var enemy := world.spawn_enemy(scene, randf_range(-spread, spread))
	enemy_spawned.emit(enemy)
	if _queue.is_empty():
		done = true
		finished.emit()
	else:
		_timer.start(maxf(0.01, _queue[0][0]))
