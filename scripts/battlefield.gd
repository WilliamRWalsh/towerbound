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


## Canvas position of the nearest point on the road to `global_pos`, or Vector2.INF when that is
## more than `max_distance` map pixels away or under the Badlands gate (the notch).
func road_point(global_pos: Vector2, max_distance: float) -> Vector2:
	var path := barricades.path
	var local := path.to_local(global_pos)
	var offset := path.curve.get_closest_offset(local)
	var point := path.curve.sample_baked(offset)
	if local.distance_to(point) > max_distance or offset < BarricadeLayer.MIN_PROGRESS:
		return Vector2.INF
	return path.to_global(point)


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
