class_name WaveGroup
extends Resource
## A bunch of enemies sent down the path together, in order.

## Seconds to wait before this group's first enemy (after the previous group's last one).
@export var pause_before := 4.0
## Seconds between enemies inside the group.
@export var spacing := 0.7
@export var enemies: Array[PackedScene] = []
