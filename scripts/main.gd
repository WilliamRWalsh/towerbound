extends Control

## Main entry point for Towerbound. Replace this placeholder screen as gameplay takes shape.
func _ready() -> void:
	# Keep the interface usable across phone aspect ratios while the project is in portrait mode.
	get_viewport().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
