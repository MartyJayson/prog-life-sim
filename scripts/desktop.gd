extends Control

const HACK_SCENE = preload("res://scenes/apps/operation_hack.tscn")
const HACK_ID := "operation_hack"
const DEBUG_SCENE = preload("res://scenes/apps/qa_debug.tscn")
const DEBUG_ICON = preload("res://assets/generated/debug.svg")
const DEBUG_ID := "qa_debug"
const DEBUG_SIZE := Vector2(480, 700)
const MAIL_ICON = preload("res://assets/generated/mail.svg")

const APPS := {
	"operations": [preload("res://scenes/apps/operations.tscn"), Vector2(1090, 690)],
	"browser": [preload("res://scenes/apps/browser.tscn"), Vector2(960, 650)],
	"mail": [preload("res://scenes/apps/mail.tscn"), Vector2(1180, 700)],
	"notepad": [preload("res://scenes/apps/notepad.tscn"), Vector2(720, 500)],
	"calculator": [preload("res://scenes/apps/calculator.tscn"), Vector2(380, 475)],
	"computer": [preload("res://scenes/apps/my_computer.tscn"), Vector2(1160, 680)],
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
	_update_clock()
	GameClock.minute_changed.connect(_update_clock)
	Mailbox.delivered.connect(_mail_delivered)

func _open(id: String) -> void:
	_hide_menu()
	if id == DEBUG_ID:
		_open_debug()
	elif APPS.has(id):
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
		NotificationData.Action.MAIL:
			_open("mail")
			manager.windows["mail"].content.open_message(data.letter)

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
	clock.text = GameClock.time_text()
	%Date.text = GameClock.date_text()

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func _open_hack(device: Node2D, app: Control) -> void:
	var exists: bool = manager.windows.has(HACK_ID)
	manager.open(HACK_ID, "Hack", $Shortcuts/operations.icon, HACK_SCENE, Vector2(490, 330))
	var window: Control = manager.windows[HACK_ID]
	var hack: Control = window.content
	if not exists:
		_place_beside(manager.windows["operations"], window)
	if not hack.owns_attempt():
		hack.configure(app.mission, device)

func _window_closed(id: String) -> void:
	if id == "operations":
		_close_operation_hack()

func _close_operation_hack() -> void:
	if manager.windows.has(HACK_ID):
		manager.close_app(HACK_ID)

## Opens the TinySoft DEBUG report window to the right of the browser showing the test build.
func _open_debug() -> void:
	var exists: bool = manager.windows.has(DEBUG_ID)
	manager.open(DEBUG_ID, "DEBUG", DEBUG_ICON, DEBUG_SCENE, DEBUG_SIZE)
	if not exists and manager.windows.has("browser"):
		_place_beside(manager.windows["browser"], manager.windows[DEBUG_ID])

## Centres `anchor` and `window` side by side when they fit, with `window` on the right.
func _place_beside(anchor: Control, window: Control) -> void:
	var anchor_position := anchor.position
	var total_width: float = anchor.size.x + window.size.x + 24.0
	if manager.size.x >= total_width and not anchor.maximized:
		anchor_position.x = (manager.size.x - total_width) * 0.5
		anchor.position = anchor_position
	window.position = Vector2(anchor_position.x + anchor.size.x + 24.0, anchor_position.y).clamp(
		Vector2.ZERO, (manager.size - window.size).max(Vector2.ZERO)
	)

## Every new letter shows a desktop notification; clicking it opens the letter in Mail.
func _mail_delivered(message: MailMessage) -> void:
	var data := NotificationData.new()
	data.title = "Mail — new letter"
	data.message = "%s: %s" % [message.sender_name, message.subject]
	data.icon = MAIL_ICON
	data.accent = Color("#2973d9")
	data.action = NotificationData.Action.MAIL
	data.letter = message
	%Notifications.push(data)
