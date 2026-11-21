extends Control

const GAME_CLOCK = preload("res://scripts/game_clock.gd")
const HACK_SCENE = preload("res://scenes/apps/operation_hack.tscn")
const HACK_ID := "operation_hack"

const APPS := {
	"operations": [preload("res://scenes/apps/operations.tscn"), Vector2(1090, 690)],
	"browser": [preload("res://scenes/apps/browser.tscn"), Vector2(960, 650)],
	"snake": [preload("res://scenes/apps/snake.tscn"), Vector2(580, 610)],
	"notepad": [preload("res://scenes/apps/notepad.tscn"), Vector2(720, 500)],
	"calculator": [preload("res://scenes/apps/calculator.tscn"), Vector2(380, 475)],
	"about": [preload("res://scenes/apps/about_os.tscn"), Vector2(520, 320)],
	"terminal": [preload("res://scenes/apps/terminal.tscn"), Vector2(860, 500)]
}
const SITE_WINDOW_SIZE := Vector2(1120, 930)

@onready var manager = $WindowManager
@onready var menu: PanelContainer = %Menu
@onready var clock: Label = %Clock
@onready var start: Button = %Start

func _ready() -> void:
	Input.set_custom_mouse_cursor(preload("res://assets/generated/cursor.svg"), Input.CURSOR_ARROW, Vector2(2, 1))
	manager.tasks = %Tasks
	%Date.text = GAME_CLOCK.DATE
	_update_clock()

func _open(id: String) -> void:
	_hide_menu()
	if APPS.has(id):
		var shortcut: Button = $Shortcuts.get_node(id)
		var already_open: bool = manager.windows.has(id)
		manager.open(id, shortcut.text, shortcut.icon, APPS[id][0], APPS[id][1])
		if id == "operations" and not already_open:
			var app: Control = manager.windows[id].content
			app.hack_requested.connect(_open_hack.bind(app))
			app.operation_reset.connect(_close_operation_hack)

func _open_site(address: String) -> void:
	var fresh: bool = not manager.windows.has("browser")
	_open("browser")
	var window: Control = manager.windows["browser"]
	if fresh:
		window.size = manager.size.min(SITE_WINDOW_SIZE)
		window.position = ((manager.size - window.size) * 0.5).round()
	window.content.open_url(address)

## Routes a clicked notification to whatever it should open.
func _notification_activated(data: NotificationData) -> void:
	match data.action:
		NotificationData.Action.APP:
			_open(data.target)
		NotificationData.Action.SITE:
			_open_site(data.target)

func _toggle_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		manager.focus_window(null)

func _hide_menu() -> void:
	menu.hide()

func _desktop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_menu()
		var first_shortcut: Button = $Shortcuts.get_child(0)
		var selected := first_shortcut.button_group.get_pressed_button()
		if selected:
			selected.set_pressed_no_signal(false)
		manager.focus_window(null)

func _update_clock() -> void:
	var time := Time.get_time_dict_from_system()
	clock.text = "%02d:%02d" % [time.hour, time.minute]

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func _open_hack(device: Node2D, app: Control) -> void:
	var exists: bool = manager.windows.has(HACK_ID)
	manager.open(HACK_ID, "Hack", $Shortcuts/operations.icon, HACK_SCENE, Vector2(490, 330))
	var window: Control = manager.windows[HACK_ID]
	var hack: Control = window.content
	if not exists:
		var map_window: Control = manager.windows["operations"]
		var map_position := map_window.position
		if manager.size.x >= map_window.size.x + window.size.x + 24.0 and not map_window.maximized:
			var total_width: float = map_window.size.x + window.size.x + 24.0
			map_position.x = (manager.size.x - total_width) * 0.5
			map_window.position = map_position
		window.position = Vector2(map_position.x + map_window.size.x + 24.0, map_position.y).clamp(
			Vector2.ZERO, (manager.size - window.size).max(Vector2.ZERO)
		)
	if not hack.owns_attempt():
		hack.configure(app.mission, device)

func _window_closed(id: String) -> void:
	if id == "operations":
		_close_operation_hack()

func _close_operation_hack() -> void:
	if manager.windows.has(HACK_ID):
		manager.close_app(HACK_ID)
