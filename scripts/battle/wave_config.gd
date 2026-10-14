class_name WaveConfig
extends Resource
## One wave: groups of enemies sent one after another.

@export var groups: Array[WaveGroup] = []
## Banner shown as the wave's preparation begins; "%d" becomes the wave number. Leave empty for
## the default "Wave N Incoming".
@export var announcement := ""
## Mana paid in total for killing every enemy of the wave. Each kill pays a share in proportion
## to its `EnemyStats.reward_weight`.
@export var mana_reward := 0.0

var _reward_weight := -1.0


func enemy_count() -> int:
	var count := 0
	for group in groups:
		count += group.enemies.size()
	return count


## How many of each enemy the wave sends, as [scene, count] pairs in order of first appearance.
func enemy_counts() -> Array:
	var counts: Array = []
	var index: Dictionary[PackedScene, int] = {}
	for group in groups:
		for scene in group.enemies:
			if not index.has(scene):
				index[scene] = counts.size()
				counts.append([scene, 0])
			counts[index[scene]][1] += 1
	return counts


## The sum of every enemy's `EnemyStats.reward_weight`, so a kill's share is its weight over this.
func reward_weight() -> float:
	if _reward_weight < 0.0:
		_reward_weight = 0.0
		for entry in enemy_counts():
			var enemy: Enemy = (entry[0] as PackedScene).instantiate()
			_reward_weight += enemy.stats.reward_weight * entry[1]
			enemy.free()
	return _reward_weight


func announcement_for(number: int) -> String:
	var text := announcement if announcement != "" else "Wave %d Incoming"
	return text % number if text.contains("%d") else text
