class_name Battlefield
extends Node2D
## Woodland battlefield. Scales the map (and everything on it) to fill the screen. The map art is
## shaped like a modern phone, so on those screens it fits exactly; on other shapes the overflow
## is cropped. Also the context cards act on: the build grid, the castle, the barricades, the effects
## layer, and the targeting overlay.

## Share of any vertical overflow cropped from the top (the rest comes off the bottom).
const TOP_CROP_SHARE := 0.35

@onready var grid: BuildGrid = $BuildGrid
@onready var castle: Castle = $Castle
@onready var barricades: BarricadeLayer = $BuildGrid/Barricades
## Projectiles and spell effects, in map pixels.
@onready var effects: Node2D = $Projectiles
## Ground effects that draw under enemies and towers (burning Fireball patches), in map pixels.
@onready var ground: Node2D = $Ground
@onready var overlay: TargetOverlay = $TargetOverlay
@onready var _map: Sprite2D = $Map


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


## Clears every targeting preview a card may have turned on.
func clear_targeting() -> void:
	grid.end_placement()
	overlay.hide_circle()
	barricades.end_preview()
	castle.highlighted = false


func _fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	var map_size := _map.texture.get_size()
	var map_scale := maxf(view.x / map_size.x, view.y / map_size.y)
	var overflow := map_size * map_scale - view
	scale = Vector2(map_scale, map_scale)
	position = -Vector2(overflow.x * 0.5, overflow.y * TOP_CROP_SHARE)
