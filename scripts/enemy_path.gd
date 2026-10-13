class_name EnemyPath
extends Path2D
## The road from the Badlands gate to the castle, in map pixels. Builds a smooth curve through
## hand-placed waypoints traced from the painted dirt road.

@export var waypoints := PackedVector2Array([
	Vector2(470, 110), Vector2(468, 250), Vector2(467, 340), Vector2(476, 410),
	Vector2(500, 460), Vector2(545, 505), Vector2(590, 560), Vector2(608, 620),
	Vector2(596, 680), Vector2(560, 720), Vector2(486, 760), Vector2(400, 805),
	Vector2(356, 860), Vector2(357, 930), Vector2(395, 980), Vector2(453, 1030),
	Vector2(510, 1075), Vector2(542, 1135), Vector2(536, 1200), Vector2(520, 1270),
	Vector2(496, 1330), Vector2(477, 1390), Vector2(471, 1450), Vector2(471, 1576),
])
## Draws the curve over the map to check it against the painted road.
@export var debug_draw := false


func _ready() -> void:
	_build_curve()


## Catmull-Rom style handles so the curve passes smoothly through every waypoint.
func _build_curve() -> void:
	var path_curve := Curve2D.new()
	var count := waypoints.size()
	for i in count:
		var before := waypoints[maxi(i - 1, 0)]
		var after := waypoints[mini(i + 1, count - 1)]
		var handle := (after - before) / 6.0
		path_curve.add_point(waypoints[i], -handle, handle)
	curve = path_curve
	queue_redraw()


func _draw() -> void:
	if debug_draw and curve:
		draw_polyline(curve.get_baked_points(), Color(1, 0, 1, 0.8), 4.0)
