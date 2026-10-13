class_name Barricade
extends Node2D
## A spiked wooden barricade across the road, in map pixels. Enemies that walk into it stop and
## strike it instead of the castle until it breaks; then they walk on. `progress` is where it
## stands along the enemy path. Stops counting as standing the moment it breaks.

signal broken(barricade: Barricade)

## Half the barricade's width across the road, in map pixels.
const HALF_WIDTH := 72.0
const STAKE_COUNT := 4
const STAKE_HEIGHT := 56.0
const BREAK_TIME := 0.6

const WOOD_DARK := Color(0.25, 0.15, 0.08)
const WOOD := Color(0.52, 0.34, 0.18)
const WOOD_LIGHT := Color(0.72, 0.52, 0.31)
const POINT := Color(0.87, 0.75, 0.55)
const ROPE := Color(0.81, 0.71, 0.47)

## Distance along the enemy path, in map pixels.
var progress := 0.0
var max_health := 5.0
var health := 5.0
## Ghost shown while the card is aimed; tinted green or red, never blocks.
var preview := false
var _standing := false
var preview_valid := true:
	set(value):
		preview_valid = value
		queue_redraw()

## Unit vector across the road.
var _across := Vector2.RIGHT
var _flash := 0.0
var _hit := false
## 0 standing, 1 fully collapsed.
var _break := 0.0


## Stands the barricade at `offset` along the path's curve, turned across the road.
func place_on(curve: Curve2D, offset: float) -> void:
	progress = offset
	position = curve.sample_baked(offset)
	var ahead := curve.sample_baked(minf(offset + 8.0, curve.get_baked_length()))
	var behind := curve.sample_baked(maxf(offset - 8.0, 0.0))
	_across = (ahead - behind).normalized().orthogonal()
	if _across.x < 0.0:
		_across = -_across
	queue_redraw()


func activate(starting_health: float) -> void:
	max_health = starting_health
	health = starting_health
	_standing = true


func is_standing() -> bool:
	return _standing


func take_damage(amount: float) -> void:
	if not is_standing():
		return
	health -= amount
	_hit = true
	_flash = 1.0
	if health <= 0.001:
		_standing = false
		broken.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "_break", 1.0, BREAK_TIME).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, BREAK_TIME).set_delay(BREAK_TIME * 0.5)
		tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 5.0)
	if _flash > 0.0 or _break > 0.0:
		queue_redraw()


func _draw() -> void:
	var tint := Color.WHITE
	if preview:
		tint = Color(0.6, 1.0, 0.6, 0.7) if preview_valid else Color(1.0, 0.45, 0.4, 0.7)
		var ring := Color(0.4, 1.0, 0.45, 0.35) if preview_valid else Color(1.0, 0.3, 0.25, 0.35)
		draw_set_transform(Vector2(0, -6), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, HALF_WIDTH + 18.0, ring)
		draw_set_transform(Vector2.ZERO)
	else:
		tint = Color.WHITE.lerp(Color(1.8, 1.6, 1.5), _flash)
		# Contact shadow along the road.
		draw_set_transform(Vector2(0, 4), Vector2(_across.x, _across.y * 0.5).angle(), Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, HALF_WIDTH + 8.0, Color(0, 0, 0, 0.28 * (1.0 - _break)))
		draw_set_transform(Vector2.ZERO)

	# The rail's ends, foreshortened: the road runs into the screen, so "across" squashes vertically.
	var left := Vector2(-_across.x, -_across.y * 0.5) * HALF_WIDTH
	var right := -left
	var drop := Vector2(0, 26.0 * _break)
	# Crossed, sharpened stakes along the rail; when broken they topple outward.
	for i in STAKE_COUNT:
		var t := (i + 0.5) / STAKE_COUNT
		var foot := left.lerp(right, t) + drop
		var lean := 0.42 + 1.1 * _break * (1.0 if t > 0.5 else -1.0)
		_draw_stake(foot + Vector2(-14, 0), lean, tint)
		_draw_stake(foot + Vector2(14, 0), -lean, tint)
	if _break < 0.5:
		_draw_log(left + Vector2(0, -18) + drop, right + Vector2(0, -18) + drop, 10.0, tint)
		for i in STAKE_COUNT:
			var knot := left.lerp(right, (i + 0.5) / STAKE_COUNT) + Vector2(0, -18) + drop
			draw_line(knot + Vector2(-5, -6), knot + Vector2(5, 6), ROPE * tint, 3.0)
	else:
		# Split rail: two halves sag apart.
		var mid := (left + right) * 0.5 + Vector2(0, -18) + drop
		_draw_log(left + Vector2(0, -6) + drop, mid + Vector2(-8, 4), 10.0, tint)
		_draw_log(mid + Vector2(8, 4), right + Vector2(0, -6) + drop, 10.0, tint)

	if _hit and not preview and is_standing():
		var bar := Rect2(Vector2(-34, -STAKE_HEIGHT - 26), Vector2(68, 9))
		draw_rect(bar.grow(2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health / max_health, 0, 1), bar.size.y)), Color(0.95, 0.72, 0.25))


## One sharpened stake from `foot`, leaning `lean` radians off vertical.
func _draw_stake(foot: Vector2, lean: float, tint: Color) -> void:
	var tip := foot + Vector2(sin(lean), -cos(lean)) * STAKE_HEIGHT
	_draw_log(foot, tip, 9.0, tint, true)


## A log from a to b with a dark outline and a lit edge; `sharp` carves b into a pale point.
func _draw_log(a: Vector2, b: Vector2, width: float, tint: Color, sharp := false) -> void:
	var along := (b - a).normalized()
	var side := along.orthogonal() * width * 0.5
	var shaft_end := b - along * width * 1.1 if sharp else b
	draw_line(a, shaft_end, WOOD_DARK * tint, width + 4.0)
	draw_line(a, shaft_end, WOOD * tint, width)
	draw_line(a + side * 0.4, shaft_end + side * 0.4, WOOD_LIGHT * tint, 2.5)
	if sharp:
		draw_colored_polygon(PackedVector2Array([b + along * 2.0, shaft_end + side * 1.35, shaft_end - side * 1.35]), WOOD_DARK * tint)
		draw_colored_polygon(PackedVector2Array([b, shaft_end + side, shaft_end - side]), POINT * tint)
