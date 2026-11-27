extends Node
## Plays a short fake power-on sequence (POST text, then the OS logo) over the login screen,
## then reveals it instantly while the power-on sound fades out over the
## looping PC hum.

const MEMORY_KB := 262144
const SILENT_DB := -60.0
const FADE_TIME := 2.5
const LOGIN_FADE_TIME := 0.4
const SHUTDOWN_TIME := 0.8

## Desktop created once a user logs in on the login screen.
@export var desktop_scene: PackedScene

const POST_HEADER: PackedStringArray = [
	"Byteforge Modular BIOS v4.60QX, A Power Saver Partner",
	"Copyright (C) 1984-2001, Byteforge Systems, Inc.",
	"",
	"Version BF4333",
	"",
	"QX-586 MMX CPU at 200MHz",
]
const POST_DEVICES: PackedStringArray = [
	"",
	"Byteforge Plug and Play BIOS Extension  v1.0A",
	"Copyright (C) 2001, Byteforge Systems, Inc.",
	"  Detecting IDE Primary Master  ... OS-DISK 4320MB",
	"  Detecting IDE Primary Slave   ... None",
	"  Detecting IDE Secondary Master... CD-ROM 24X",
	"  Detecting IDE Secondary Slave ... None",
]

@onready var overlay: CanvasLayer = $Overlay
@onready var login: Control = %Login
@onready var post: Control = %Post
@onready var lines: Label = %Lines
@onready var footer: Label = %Footer
@onready var logo: Control = %Logo
@onready var bar: Panel = %Bar
@onready var blocks: Control = %Blocks
@onready var power_on: AudioStreamPlayer = %PowerOn
@onready var hum: AudioStreamPlayer = %Hum

var _skipped := false

func _ready() -> void:
	(hum.stream as AudioStreamMP3).loop = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_run()

func _input(event: InputEvent) -> void:
	if overlay == null or _skipped:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_skipped = true
		get_viewport().set_input_as_handled()

func _run() -> void:
	power_on.play()
	await _wait(0.5)
	await _show_post()
	post.hide()
	await _wait(0.35)
	await _show_logo()
	_finish()

func _show_post() -> void:
	post.show()
	var text := ""
	for line in POST_HEADER:
		text += line + "\n"
		lines.text = text
		await _wait(0.08)
	footer.show()
	var start := Time.get_ticks_msec()
	var memory := 0
	while memory < MEMORY_KB and not _skipped:
		memory = mini(MEMORY_KB, int((Time.get_ticks_msec() - start) / 700.0 * MEMORY_KB) / 1024 * 1024)
		lines.text = text + "Memory Test :  %dK" % memory
		await get_tree().process_frame
	text += "Memory Test :  %dK OK\n" % MEMORY_KB
	lines.text = text
	await _wait(0.3)
	for line in POST_DEVICES:
		text += line + "\n"
		lines.text = text
		await _wait(0.22)
	await _wait(0.5)

func _show_logo() -> void:
	logo.show()
	var travel := create_tween().set_loops()
	travel.tween_property(blocks, "position:x", bar.size.x + 4.0, 1.1).from(-blocks.size.x)
	await _wait(2.4)
	travel.kill()

## Loads the chosen user's desktop under the login screen, then fades the login screen away.
func _logged_in(_user_name: String) -> void:
	var desktop: Control = desktop_scene.instantiate()
	add_child(desktop)
	move_child(desktop, login.get_index())
	var fade := create_tween()
	fade.tween_property(login, "modulate:a", 0.0, LOGIN_FADE_TIME)
	fade.tween_callback(login.queue_free)

## "Turn off computer": fades the screen and the hum to black and silence, then quits the game.
func _power_off() -> void:
	SaveGame.save()
	var fade := create_tween().set_parallel()
	fade.tween_property(login, "modulate", Color.BLACK, SHUTDOWN_TIME)
	fade.tween_property(hum, "volume_db", SILENT_DB, SHUTDOWN_TIME)
	fade.chain().tween_callback(get_tree().quit)

## Shows the login screen at once, then lets the power-on sound fade out over the looping hum.
func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.queue_free()
	overlay = null
	hum.play()
	var fade := create_tween()
	fade.tween_property(power_on, "volume_db", SILENT_DB, FADE_TIME).set_ease(Tween.EASE_IN)
	fade.tween_callback(power_on.stop)

## Waits [param seconds], returning immediately once the player skips the boot.
func _wait(seconds: float) -> void:
	if _skipped:
		return
	var timer := get_tree().create_timer(seconds)
	while timer.time_left > 0.0 and not _skipped:
		await get_tree().process_frame
