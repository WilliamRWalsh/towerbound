class_name PlaceBarricadeEffect
extends CardEffect
## Puts a barricade across the road at the targeted point. Enemies stop to break it.

@export var health := 5.0


func can_apply(_world: Battlefield, target: CardTarget) -> bool:
	return target.road_offset >= 0.0


func apply(world: Battlefield, target: CardTarget, _choice: int) -> void:
	world.barricades.place_at(target.road_offset, health)


func describe(values: Dictionary) -> void:
	values["health"] = str(roundi(health))
