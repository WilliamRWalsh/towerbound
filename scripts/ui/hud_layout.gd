class_name HudLayout
extends CanvasLayer
## Lays out the battle HUD around the safe area whenever the screen changes size: the hand lifted
## above the home indicator, the wave panel and preview below the notch, the castle health bar on
## the left edge and the mana bar on the right between the top row and the hand, and the Discard
## button in the bottom-left corner just above the tucked cards.

## Tallest the health and mana bars get; they shrink on shorter screens to fit.
const BAR_MAX_HEIGHT := 470.0
const MARGIN := 14.0
## Space between the top row, the bars, the Discard button, and the hand.
const GAP := 24.0

@export var hand: Hand
@export var wave_hud: WaveHud
@export var wave_preview: WavePreview
@export var health_bar: HealthBar
@export var mana_bar: ManaBar
@export var discard_button: Button


func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()


func fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var insets := SafeArea.insets(get_viewport())
	hand.bottom_inset = insets.y
	# The top row is the wave panel (the debug Restart button beside it is shorter).
	var bars_top := insets.x + MARGIN + WaveHud.PANEL_SIZE.y + GAP
	var discard_y := view.y - insets.y - Hand.CARD_SIZE.y * 0.5 - discard_button.size.y - GAP
	discard_button.position = Vector2(MARGIN, discard_y)
	var bars_bottom := discard_y - GAP
	var bar_height := minf(BAR_MAX_HEIGHT, bars_bottom - bars_top)
	var bar_y := (bars_top + bars_bottom - bar_height) * 0.5
	health_bar.size = Vector2(Gauge.CAP_SIZE, bar_height)
	health_bar.position = Vector2(2.0, bar_y)
	mana_bar.size = Vector2(Gauge.CAP_SIZE, bar_height)
	mana_bar.position = Vector2(view.x - Gauge.CAP_SIZE - 2.0, bar_y)
	wave_hud.position = Vector2(MARGIN, insets.x + MARGIN)
	wave_preview.position = Vector2(MARGIN, bars_top - MARGIN)
	wave_preview.size = Vector2(view.x - MARGIN * 2.0, WavePreview.HEIGHT)
