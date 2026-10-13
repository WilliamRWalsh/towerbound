class_name WaveConfig
extends Resource
## One wave: groups of enemies sent one after another.

@export var groups: Array[WaveGroup] = []
## Banner shown as the wave's preparation begins; "%d" becomes the wave number. Leave empty for
## the default "Wave N Incoming".
@export var announcement := ""


func enemy_count() -> int:
	var count := 0
	for group in groups:
		count += group.enemies.size()
	return count


func announcement_for(number: int) -> String:
	var text := announcement if announcement != "" else "Wave %d Incoming"
	return text % number if text.contains("%d") else text
