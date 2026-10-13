class_name CardTarget
extends RefCounted
## Where a card is being played, as its targeting resolved it: a canvas position, plus whichever
## of these the targeting picked out: a build cell, a tower, a distance along the road, an area's
## radius. Effects read the parts they need.

## Canvas position of the target (a cell's or tower's center, a snapped road point, the tap).
var position := Vector2.ZERO
var cell := BuildGrid.NO_CELL
var tower: Tower = null
## Distance along the enemy path, in map pixels; -1 when not on the road.
var road_offset := -1.0
## Radius of the area covered, in map pixels; 0 for a single point.
var radius := 0.0


func _init(at: Vector2) -> void:
	position = at
