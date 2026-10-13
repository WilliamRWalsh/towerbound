class_name Battlefield
extends Node2D
## Woodland battlefield. Scales the map (and everything on it) to fill the screen. The map art is
## shaped like a modern phone, so on those screens it fits exactly; on other shapes the overflow
## is cropped. Also the context everything in the battle works through: the build grid, the castle,
## the road and its barricades, the effect layers, the enemies in play, the damage ledger, and
## shared tower targeting. Towers, enemies, projectiles, spells, and cards get it passed in rather
## than reaching for global state, so nothing outlives the battle.

## Share of any vertical overflow cropped from the top (the rest comes off the bottom).
const TOP_CROP_SHARE := 0.35

## The rules running this battle; towers follow its waves. Set by the battle screen's scene.
@export var battle: Battle

@onready var grid: BuildGrid = $BuildGrid
## What the grid shows while a card is aimed at it.
@onready var placement: PlacementPreview = $BuildGrid/PlacementPreview
@onready var castle: Castle = $Castle
@onready var barricades: BarricadeLayer = $BuildGrid/Barricades
## Projectiles and spell effects, in map pixels.
@onready var effects: Node2D = $Projectiles
## Ground effects that draw under enemies and towers (burning Fireball patches), in map pixels.
@onready var ground: Node2D = $Ground
@onready var overlay: TargetOverlay = $TargetOverlay
@onready var path: EnemyPath = $BuildGrid/EnemyPath
@onready var spawner: EnemySpawner = $Spawner
@onready var _map: Sprite2D = $Map

var enemies := EnemyRegistry.new(self)
var ledger := DamageLedger.new()
var targeting: TargetPlanner


func _ready() -> void:
	targeting = TargetPlanner.new(enemies, ledger, ground)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


## Puts a new enemy at the start of the road, `h_offset` map pixels to the side.
func spawn_enemy(scene: PackedScene, h_offset := 0.0) -> Enemy:
	var enemy: Enemy = scene.instantiate()
	enemy.world = self
	enemy.h_offset = h_offset
	path.add_child(enemy)
	enemies.add(enemy)
	return enemy


## Canvas position of the nearest point on the road to `global_pos`, or Vector2.INF when that is
## more than `max_distance` map pixels away or under the Badlands gate (the notch).
func road_point(global_pos: Vector2, max_distance: float) -> Vector2:
	var local := path.to_local(global_pos)
	var offset := path.curve.get_closest_offset(local)
	var point := path.curve.sample_baked(offset)
	if local.distance_to(point) > max_distance or offset < BarricadeLayer.MIN_PROGRESS:
		return Vector2.INF
	return path.to_global(point)


## Canvas position of the road `offset` map pixels from the Badlands gate.
func road_point_at(offset: float) -> Vector2:
	return path.to_global(path.curve.sample_baked(offset))


func _fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	var map_size := _map.texture.get_size()
	var map_scale := maxf(view.x / map_size.x, view.y / map_size.y)
	var overflow := map_size * map_scale - view
	scale = Vector2(map_scale, map_scale)
	position = -Vector2(overflow.x * 0.5, overflow.y * TOP_CROP_SHARE)
