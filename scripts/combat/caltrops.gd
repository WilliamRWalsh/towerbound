class_name Caltrops
extends Node2D
## Iron spikes scattered across the road just short of the castle gate crowd, left by a Barricade
## card thrown away with Discard. Each enemy that walks over them takes pierce damage once, until
## the spikes have hurt `hits_left` enemies; then they fade. Scattering more while some are down
## adds to the same patch. Sits on the ground layer, under the enemies. Works in its parent's
## (map-pixel) coordinates.

const GROUP := "caltrops"
## How far before the end of the road the patch lies, in map pixels: just ahead of the gate crowd.
const FROM_END := 270.0
## Length of road the patch covers, in map pixels.
const SPAN := 60.0
const FADE_TIME := 0.5

var hits_left := 0
var _damage := 1.0
var _path: Path2D
## Distance along the path of the patch's center.
var _progress := 0.0
## Enemies already hurt, so each pays once.
var _hurt: Dictionary[Enemy, bool] = {}
## Each spike: [position, angle].
var _spikes: Array = []
var _fade := -1.0


## Scatters spikes that hurt the next `hits` enemies, or adds them to the patch already down.
static func scatter(layer: Node2D, path: Path2D, hits: int, damage: float) -> Caltrops:
	for existing: Caltrops in layer.get_tree().get_nodes_in_group(GROUP):
		existing.hits_left += hits
		existing._add_spikes(hits)
		return existing
	var caltrops := Caltrops.new()
	caltrops._path = path
	caltrops._damage = damage
	caltrops.hits_left = hits
	caltrops._progress = path.curve.get_baked_length() - FROM_END
	caltrops.add_to_group(GROUP)
	layer.add_child(caltrops)
	caltrops.global_position = path.to_global(path.curve.sample_baked(caltrops._progress))
	caltrops._add_spikes(hits)
	return caltrops


func _process(delta: float) -> void:
	if _fade >= 0.0:
		_fade += delta
		modulate.a = 1.0 - _fade / FADE_TIME
		if _fade >= FADE_TIME:
			queue_free()
		return
	var start := _progress - SPAN * 0.5
	var end := _progress + SPAN * 0.5
	for enemy: Enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if hits_left <= 0:
			break
		if enemy.is_alive() and not _hurt.has(enemy) and enemy.progress >= start and enemy.progress <= end:
			_hurt[enemy] = true
			hits_left -= 1
			enemy.take_damage(_damage, Damage.Type.PIERCE)
	if hits_left <= 0:
		remove_from_group(GROUP)
		_fade = 0.0


## Adds spikes along the patch, a couple per hit, scattered across the road.
func _add_spikes(hits: int) -> void:
	var curve := _path.curve
	for i in hits * 2:
		var along := _progress + randf_range(-SPAN * 0.5, SPAN * 0.5)
		var road := curve.sample_baked(along)
		var across := (curve.sample_baked(along + 4.0) - road).normalized().orthogonal()
		var spot := _path.to_global(road + across * randf_range(-55.0, 55.0))
		_spikes.append([to_local(spot), randf() * TAU])
	queue_redraw()


func _draw() -> void:
	for spike in _spikes:
		var c: Vector2 = spike[0]
		var a: float = spike[1]
		# A caltrop: three points showing from above, with a small shadow.
		draw_circle(c + Vector2(2.0, 2.5), 7.0, Color(0, 0, 0, 0.35))
		for k in 3:
			var d := Vector2.from_angle(a + TAU * k / 3.0)
			draw_line(c, c + d * 10.0, Color(0.12, 0.12, 0.14), 4.5)
			draw_line(c, c + d * 8.5, Color(0.6, 0.62, 0.66), 2.4)
		draw_circle(c, 3.0, Color(0.75, 0.77, 0.8))
