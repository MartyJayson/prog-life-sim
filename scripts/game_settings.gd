extends Node

## Player options (sound volume and screen size), registered as the `GameSettings` autoload.
## Stored in `user://settings.cfg` and applied on launch.

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 0.8
## Index 0 is fullscreen; the rest are windowed sizes.
const SCREEN_SIZES: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]

var path := DEFAULT_PATH
## Master volume, 0..1.
var volume := DEFAULT_VOLUME
var screen := 0

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		volume = clampf(config.get_value("audio", "volume", DEFAULT_VOLUME), 0.0, 1.0)
		screen = clampi(config.get_value("display", "screen", 0), 0, SCREEN_SIZES.size() - 1)
	_apply_volume()
	if screen != 0:
		_apply_screen()

static func screen_label(index: int) -> String:
	var size := SCREEN_SIZES[index]
	return "Fullscreen" if size == Vector2i.ZERO else "Window %d × %d" % [size.x, size.y]

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()

func set_screen(index: int) -> void:
	screen = clampi(index, 0, SCREEN_SIZES.size() - 1)
	_apply_screen()
	_save()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	AudioServer.set_bus_mute(0, volume <= 0.0)

func _apply_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var size := SCREEN_SIZES[screen]
	if size == Vector2i.ZERO:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	size = size.min(usable.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("display", "screen", screen)
	config.save(path)
