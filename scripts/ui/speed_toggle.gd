class_name SpeedToggle
extends Button
## The "x2" button in the top-right corner: runs the whole game at double speed while a wave is
## being fought. It can only be switched on during combat, and drops back to normal speed when the
## wave ends, the battle ends, or the castle takes damage; pressing it again resumes double speed.

const SIZE := Vector2(96, 56)
const FAST_SCALE := 2.0

@export var battle: Battle

var fast := false

var _last_health := 0.0


func _ready() -> void:
	size = SIZE
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	text = "x2"
	toggled.connect(_set_fast)
	battle.combat_started.connect(func(_number: int) -> void: disabled = false)
	battle.wave_cleared.connect(func(_number: int) -> void: _stop())
	battle.ended.connect(func(_result: Battle.State) -> void: _stop())
	battle.field.castle.health_changed.connect(_on_castle_health_changed)
	_last_health = battle.field.castle.health
	disabled = true


func _exit_tree() -> void:
	_set_fast(false)


func _on_castle_health_changed(health: float, _max_health: int) -> void:
	if health < _last_health:
		set_pressed_no_signal(false)
		_set_fast(false)
	_last_health = health


## Back to normal speed and unavailable until the next wave marches.
func _stop() -> void:
	set_pressed_no_signal(false)
	_set_fast(false)
	disabled = true


## Only touches the engine's time scale when the speed actually changes, so it never overrides a
## time scale set by something else (the tests fast-forward this way).
func _set_fast(on: bool) -> void:
	if on == fast:
		return
	fast = on
	Engine.time_scale = FAST_SCALE if on else 1.0
