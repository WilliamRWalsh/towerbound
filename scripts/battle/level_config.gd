class_name LevelConfig
extends Resource
## Everything that makes one level: its waves, the deck the player brings, and the starting
## state. A new level is a new resource; the battle code reads all of it from here.

@export var waves: Array[WaveConfig] = []
## Every card in the deck, duplicates listed once per copy.
@export var deck: Array[CardData] = []
@export var hand_size := 4
@export var starting_mana := 8.0
@export var max_mana := 10.0
@export var castle_health := 20
## Seconds of preparation before each wave marches.
@export var prepare_time := 10.0
