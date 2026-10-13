class_name CardData
extends Resource
## A card: what it costs, how it is aimed (`targeting`), and what it does where it lands
## (`effects`), plus anything it does when thrown away with Discard (`discard_effects`). New cards
## are put together in the inspector from these parts; no card needs its own script.
## CardPlayController owns the rules around a play: it checks mana before a card is selected or
## played, and only when `play` succeeds does it remove the card from the hand, discard it, and
## spend its cost.

@export var id: StringName
@export var title := ""
@export var art: Texture2D
@export var cost := 2
@export var targeting: CardTargeting
@export var effects: Array[CardEffect] = []
## Done once when the card is thrown away with Discard instead of played.
@export var discard_effects: Array[CardEffect] = []


## False when the card has nothing it could be played on right now (Repair at full health); it is
## then refused when picked up, without spending anything.
func can_play(world: Battlefield) -> bool:
	return targeting.has_any_target(world, self)


func begin_targeting(world: Battlefield) -> void:
	targeting.begin(world, self)


## Moves the aiming preview. `over_field` is false while the pointer is over the hand.
func update_targeting(world: Battlefield, global_pos: Vector2, over_field: bool) -> void:
	targeting.update(world, self, global_pos, over_field)


func end_targeting(world: Battlefield) -> void:
	targeting.end(world)


## What playing the card at a canvas position would act on, or null if it can't be played there.
func target_at(world: Battlefield, global_pos: Vector2) -> CardTarget:
	var target := targeting.resolve(world, self, global_pos)
	return target if target and can_play_on(world, target) else null


## True when every effect can act on `target`.
func can_play_on(world: Battlefield, target: CardTarget) -> bool:
	return effects.all(func(effect: CardEffect) -> bool: return effect.can_apply(world, target))


## Options the player must pick between before the card is played on `target` (which upgrade a
## tower gets), or empty.
func choices(world: Battlefield, target: CardTarget) -> PackedStringArray:
	for effect in effects:
		var options := effect.choices(world, target)
		if not options.is_empty():
			return options
	return PackedStringArray()


## Applies every effect to `target`, with `choice` picked from `choices`. Returns false, changing
## nothing, if any effect can't act there.
func play(world: Battlefield, target: CardTarget, choice := 0) -> bool:
	if target == null or not can_play_on(world, target):
		return false
	for effect in effects:
		effect.apply(world, target, choice)
	return true


## Called once when the card is thrown away with Discard (not when played).
func discard(world: Battlefield) -> void:
	for effect in discard_effects:
		effect.apply(world, null, 0)


## The Damage.Type the card deals when played, for the badge on the card, or Damage.NONE.
func damage_type() -> int:
	for effect in effects:
		if effect.damage_type() != Damage.NONE:
			return effect.damage_type()
	return Damage.NONE


## The first effect that is an instance of `type` (a class), or null.
func find_effect(type: Variant) -> CardEffect:
	for effect in effects:
		if is_instance_of(effect, type):
			return effect
	return null
