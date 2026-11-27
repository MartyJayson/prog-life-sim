extends Control

## Login screen shown after boot: pick an existing user to load their game, create a new user
## to start a new game, open the settings or turn the computer off (quit).

signal logged_in(user_name: String)
signal power_off_requested

const USER_TILE = preload("res://scenes/user_tile.tscn")
const CURSOR = preload("res://assets/generated/cursor.svg")
const WELCOME_TIME := 1.4

@onready var users: VBoxContainer = %Users
@onready var new_user: Button = %NewUser
@onready var form: HBoxContainer = %NewUserForm
@onready var name_edit: LineEdit = %NameEdit
@onready var error: Label = %Error
@onready var prompt: Label = %Prompt
@onready var modal: Panel = %Modal
@onready var settings_dialog: PanelContainer = %SettingsDialog

var tiles: Array[Button] = []
var _busy := false

func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR, Input.CURSOR_ARROW, Vector2(2, 1))
	name_edit.max_length = Profiles.MAX_NAME_LENGTH
	Profiles.changed.connect(_rebuild)
	_rebuild()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal.visible:
			_close_settings()
		elif form.visible:
			_close_form()
		else:
			return
		get_viewport().set_input_as_handled()

## One tile per saved user, listed above the "New user" tile.
func _rebuild() -> void:
	for tile in tiles:
		users.remove_child(tile)
		tile.queue_free()
	tiles.clear()
	for entry in Profiles.users:
		var tile: Button = USER_TILE.instantiate()
		tile.text = entry.name
		tile.icon = Profiles.avatar(entry)
		tile.pressed.connect(_log_in.bind(entry.name))
		users.add_child(tile)
		users.move_child(tile, new_user.get_index())
		tiles.append(tile)
	prompt.text = "To begin, click New user" if tiles.is_empty() else "To begin, click your user name"
	_close_form()

func _open_form() -> void:
	new_user.hide()
	form.show()
	error.hide()
	name_edit.clear()
	name_edit.grab_focus()

func _close_form() -> void:
	form.hide()
	new_user.show()

func _create() -> void:
	var user_name := name_edit.text.strip_edges()
	var problem := Profiles.name_error(user_name)
	if not problem.is_empty():
		error.text = problem
		error.show()
		name_edit.grab_focus()
		return
	Profiles.create(user_name)
	_log_in(user_name)

func _log_in(user_name: String) -> void:
	if _busy:
		return
	_busy = true
	Profiles.log_in(user_name)
	for tile in tiles:
		tile.disabled = tile.text != user_name
	%Settings.disabled = true
	%Brand.hide()
	prompt.hide()
	%Welcome.show()
	%Loading.show()
	var fade := create_tween()
	fade.tween_property(%Scroll, "modulate:a", 0.0, 0.4).set_delay(0.3)
	await get_tree().create_timer(WELCOME_TIME).timeout
	logged_in.emit(user_name)

func _open_settings() -> void:
	settings_dialog.refresh()
	modal.show()

func _close_settings() -> void:
	modal.hide()

func _power_off() -> void:
	if _busy:
		return
	_busy = true
	power_off_requested.emit()
