extends Control

signal launch_requested(id: String)
signal window_interacted
signal window_closed(id: String)

const WindowScene = preload("res://scenes/app_window.tscn")
const AppWindow = preload("res://scripts/app_window.gd")
const TaskButton = preload("res://scenes/task_button.tscn")

var tasks: HBoxContainer
var windows: Dictionary = {}
var task_buttons: Dictionary = {}
var active: AppWindow

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_layout_windows)

func open(id: String, caption: String, icon: Texture2D, app_scene: PackedScene, preferred_size: Vector2) -> void:
	if windows.has(id):
		windows[id].show()
		focus_window(windows[id])
		return
	var window: AppWindow = WindowScene.instantiate()
	var app: Control = app_scene.instantiate()
	if app.has_signal("launch_requested"):
		app.launch_requested.connect(launch_requested.emit)
	if app.has_signal("close_requested"):
		app.close_requested.connect(close_app.bind(id), CONNECT_DEFERRED)
	window.close_requested.connect(close_app.bind(id))
	window.minimize_requested.connect(_minimize.bind(window))
	window.maximize_requested.connect(_maximize.bind(window))
	window.drag_requested.connect(_drag.bind(window))
	add_child(window)
	window.mount(caption, icon, app)
	window.size = size.min(preferred_size)
	window.position = ((size - window.size) * 0.5 + Vector2.ONE * 24 * windows.size()).round()
	_drag(window.position, window)
	windows[id] = window
	var task: Button = TaskButton.instantiate()
	task.text = caption
	task.icon = icon
	task.pressed.connect(_toggle_task.bind(window))
	tasks.add_child(task)
	task_buttons[id] = task
	focus_window(window)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local_mouse := get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse):
			return
		# Use GUI ancestry so menus and shortcuts above the window layer retain priority.
		var hovered := get_viewport().gui_get_hovered_control()
		while hovered:
			if hovered is AppWindow and hovered.get_parent() == self:
				window_interacted.emit()
				focus_window(hovered, false)
				return
			hovered = hovered.get_parent_control()

func focus_window(window: AppWindow, clear_control_focus: bool = true) -> void:
	if active != window and clear_control_focus:
		get_viewport().gui_release_focus()
	active = window
	if window:
		move_child(window, -1)
	for id: String in windows:
		windows[id].set_active(windows[id] == active)
		task_buttons[id].set_pressed_no_signal(windows[id] == active)

func _fallback_focus() -> void:
	for index in range(get_child_count() - 1, -1, -1):
		var window := get_child(index) as AppWindow
		if window and window.visible:
			focus_window(window)
			return
	focus_window(null)

func close_app(id: String) -> void:
	var window: AppWindow = windows[id]
	window.hide()
	window.queue_free()
	task_buttons[id].queue_free()
	windows.erase(id)
	task_buttons.erase(id)
	if active == window:
		_fallback_focus()
	window_closed.emit(id)

func _minimize(window: AppWindow) -> void:
	window.hide()
	if active == window:
		_fallback_focus()

func _toggle_task(window: AppWindow) -> void:
	if window == active:
		_minimize(window)
	else:
		window.show()
		focus_window(window)

func _maximize(window: AppWindow) -> void:
	window.maximized = not window.maximized
	if window.maximized:
		window.restore_rect = Rect2(window.position, window.size)
		window.position = Vector2.ZERO
		window.size = size
	else:
		window.size = window.restore_rect.size.min(size)
		_drag(window.restore_rect.position, window)
	window.maximize_button.text = "❐" if window.maximized else "□"

func _drag(target: Vector2, window: AppWindow) -> void:
	var max_position := (size - window.size).max(Vector2.ZERO)
	window.position = target.clamp(Vector2.ZERO, max_position)

func _layout_windows() -> void:
	for window: AppWindow in windows.values():
		if window.maximized:
			window.size = size
		else:
			window.size = window.size.min(size)
			_drag(window.position, window)
