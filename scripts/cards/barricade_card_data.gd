class_name BarricadeCardData
extends CardData
## Puts a barricade across the road. Enemies stop to break it before walking on.

@export var health := 5.0


func begin_targeting(field: Battlefield) -> void:
	field.barricades.begin_preview()


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.barricades.update_preview(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	return field.barricades.place(global_pos, health)
