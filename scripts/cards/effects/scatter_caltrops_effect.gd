class_name ScatterCaltropsEffect
extends CardEffect
## Scatters caltrops on the road just short of the castle gate: the next `hits` enemies to cross
## each take pierce damage. Used as a discard effect, so it needs no target.

@export var hits := 8
@export var damage := 1.0


func apply(world: Battlefield, _target: CardTarget, _choice: int) -> void:
	Caltrops.scatter(world, hits, damage)


func damage_type() -> int:
	return Damage.Type.PIERCE


func describe(values: Dictionary) -> void:
	values["caltrop_hits"] = str(hits)
	values["caltrop_damage"] = decimal(damage)
