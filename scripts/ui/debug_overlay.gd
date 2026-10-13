class_name DebugOverlay
extends CanvasLayer
## Debug-only controls over the battle: a Restart button in the top-right corner, below the notch,
## that reloads the battle scene for a completely fresh run. Delete this node from main.tscn to
## ship without it.

const MARGIN := 14.0

@onready var _restart: Button = $Restart


func _ready() -> void:
	_restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	_restart.position = Vector2(view.x - _restart.size.x - MARGIN, SafeArea.insets(get_viewport()).x + MARGIN)
