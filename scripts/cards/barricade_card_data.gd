class_name BarricadeCardData
extends CardData
## Puts a barricade across the road. Enemies stop to break it before walking on. Thrown away
## with Discard, it scatters caltrops on the road in front of the castle instead.

@export var health := 5.0
## Caltrops left when discarded: how many enemies they hurt, and the pierce damage each takes.
@export var caltrop_hits := 8
@export var caltrop_damage := 1.0


func begin_targeting(field: Battlefield) -> void:
	field.barricades.begin_preview()


func update_targeting(field: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	field.barricades.update_preview(global_pos, over_field)


func play(field: Battlefield, global_pos: Vector2) -> bool:
	return field.barricades.place(global_pos, health)


func on_discard(field: Battlefield) -> void:
	Caltrops.scatter(field.ground, field.barricades.path, caltrop_hits, caltrop_damage)
