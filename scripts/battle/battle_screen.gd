class_name BattleScreen
extends Node
## The battle screen for one level. Starts the Battle and keeps the display in step with it: the
## wave panel and countdown, the coming wave's preview, banners for each phase and the result,
## the castle health and mana bars, and mana wisps from kills. The Battle owns the rules and
## state, the CardPlayController turns input into card plays, and the HudLayout places the HUD.

@export var level: LevelConfig

@onready var _field: Battlefield = $Battlefield
@onready var _battle: Battle = $Battle
@onready var _cards: CardPlayController = $CardPlay
@onready var _mana_bar: ManaBar = $HandLayer/ManaBar
@onready var _health_bar: HealthBar = $HandLayer/HealthBar
@onready var _hud: WaveHud = $HandLayer/WaveHud
@onready var _preview: WavePreview = $HandLayer/WavePreview
@onready var _banner: Banner = $MessageLayer/Banner


func _ready() -> void:
	var castle := _field.castle
	castle.health_changed.connect(func(health: float, max_health: int) -> void: _health_bar.set_health(health, max_health))
	_battle.mana.changed.connect(func(value: float) -> void: _mana_bar.value = value)
	_battle.setup(level)
	_health_bar.set_health(castle.health, castle.max_health, false)
	_mana_bar.max_value = int(level.max_mana)
	_mana_bar.reset(_battle.mana.value)
	_cards.aiming_changed.connect(func(aiming: bool) -> void: _preview.dimmed = aiming)
	_cards.card_rejected.connect(_on_card_rejected)
	_battle.preparation_started.connect(_on_preparation_started)
	_battle.combat_started.connect(_on_combat_started)
	_battle.wave_cleared.connect(_on_wave_cleared)
	_battle.ended.connect(_on_battle_ended)
	_battle.kill_rewarded.connect(_on_kill_rewarded)
	_battle.start()


func _process(_delta: float) -> void:
	match _battle.state:
		Battle.State.VICTORY:
			_hud.set_status("Victory")
		Battle.State.DEFEAT:
			_hud.set_status("Defeat")
		Battle.State.PREPARING:
			_hud.set_status("Battle in %d" % ceili(_battle.prepare_time_left()))
		_:
			_hud.set_status("Fighting")


func _on_preparation_started(number: int, wave: WaveConfig) -> void:
	_hud.set_wave(number, _battle.wave_count())
	var final := number == _battle.wave_count()
	_banner.show_message(wave.announcement_for(number), Banner.Style.DANGER if final else Banner.Style.NOTICE)
	_banner.show_message("Prepare for Battle")
	_preview.show_wave(wave)


func _on_combat_started(_number: int) -> void:
	_preview.hide_wave()
	_banner.show_message("Enemies Attacking!", Banner.Style.DANGER)


func _on_wave_cleared(number: int) -> void:
	_banner.show_message("Wave %d Defeated" % number, Banner.Style.VICTORY)


## The Battle has already stopped spawning, timers, enemies, and card play.
func _on_battle_ended(result: Battle.State) -> void:
	_preview.hide_wave()
	if result == Battle.State.VICTORY:
		_banner.show_message("Victory!", Banner.Style.VICTORY)
	else:
		_banner.clear()
		_banner.show_message("Defeat", Banner.Style.DANGER)
		_banner.show_message("The Castle Has Fallen", Banner.Style.DANGER)


## The Battle grants the mana right after this; the wisp only animates it into the bar.
func _on_kill_rewarded(enemy: Enemy, amount: float) -> void:
	_mana_bar.send_wisp(enemy.aim_point(), amount)


func _on_card_rejected(_card: CardView, reason: CardPlayController.Rejection) -> void:
	if reason == CardPlayController.Rejection.NO_MANA:
		_mana_bar.flash_insufficient()
