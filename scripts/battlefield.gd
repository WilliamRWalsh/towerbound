extends Node2D
## Woodland battlefield. Scales the map (and the build grid with it) to fill the screen. The map
## art is shaped like a modern phone, so on those screens it fits exactly; on other shapes the
## overflow is cropped.

## Share of any vertical overflow cropped from the top (the rest comes off the bottom).
const TOP_CROP_SHARE := 0.35

@onready var _map: Sprite2D = $Map


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	var map_size := _map.texture.get_size()
	var map_scale := maxf(view.x / map_size.x, view.y / map_size.y)
	var overflow := map_size * map_scale - view
	scale = Vector2(map_scale, map_scale)
	position = -Vector2(overflow.x * 0.5, overflow.y * TOP_CROP_SHARE)
