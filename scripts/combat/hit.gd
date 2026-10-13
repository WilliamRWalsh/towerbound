class_name Hit
extends RefCounted
## One packet of damage dealt to an enemy: how much, and of which Damage.Type (or Damage.NONE).
## The enemy scales it by its own weaknesses and resistances.

var amount := 0.0
var type: int = Damage.NONE


func _init(hit_amount: float, hit_type: int = Damage.NONE) -> void:
	amount = hit_amount
	type = hit_type
