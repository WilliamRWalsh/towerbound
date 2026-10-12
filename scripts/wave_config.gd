class_name WaveConfig
extends Resource
## One wave: groups of enemies sent one after another.

@export var groups: Array[WaveGroup] = []


func enemy_count() -> int:
	var count := 0
	for group in groups:
		count += group.enemies.size()
	return count
