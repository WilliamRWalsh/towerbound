class_name SpillOilEffect
extends CardEffect
## Spills a slick of oil over the targeted stretch of road. Enemies wading through get `slow`;
## fire touching it ignites it into a blaze.

## The status enemies wading through it get.
@export var slow: StatusEffect
@export var duration := 25.0
## How the slick burns once ignited.
@export var blaze: BurnSpec


func apply(world: Battlefield, target: CardTarget, _choice: int) -> void:
	OilSlick.spill(world, target.position, target.radius, slow, duration, blaze)
