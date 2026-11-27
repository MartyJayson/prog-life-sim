extends PanelContainer

## Game settings card: master volume, screen size and resetting every save.

signal closed

@onready var volume: HSlider = %Volume
@onready var volume_value: Label = %VolumeValue
@onready var screen: OptionButton = %Screen
@onready var reset_button: Button = %Reset
@onready var confirm: HBoxContainer = %Confirm

func _ready() -> void:
	for index in GameSettings.SCREEN_SIZES.size():
		screen.add_item(GameSettings.screen_label(index), index)
	refresh()

## Shows the current values and hides a pending reset question.
func refresh() -> void:
	volume.set_value_no_signal(roundf(GameSettings.volume * 100.0))
	volume_value.text = "%d %%" % volume.value
	screen.select(GameSettings.screen)
	_cancel_reset()

func _volume_changed(value: float) -> void:
	volume_value.text = "%d %%" % value
	GameSettings.set_volume(value / 100.0)

func _screen_selected(index: int) -> void:
	GameSettings.set_screen(index)

func _ask_reset() -> void:
	reset_button.hide()
	confirm.show()

func _cancel_reset() -> void:
	confirm.hide()
	reset_button.show()

func _reset() -> void:
	Profiles.reset()
	_cancel_reset()

func _close() -> void:
	closed.emit()
