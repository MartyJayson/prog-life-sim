extends PanelContainer

signal close_requested
signal minimize_requested
signal maximize_requested
signal drag_requested(new_position: Vector2)

@export var active_title_style: StyleBox
@export var inactive_title_style: StyleBox

var content: Control
var maximized := false
var restore_rect: Rect2
var dragging := false
var drag_offset: Vector2

@onready var title_bar: PanelContainer = %TitleBar
@onready var maximize_button: Button = %Maximize

func mount(caption: String, icon: Texture2D, app: Control) -> void:
	%Caption.text = caption
	%Picture.texture = icon
	content = app
	%ContentHost.add_child(content)

func set_active(active: bool) -> void:
	title_bar.add_theme_stylebox_override("panel", active_title_style if active else inactive_title_style)
	if content.has_method("set_active"):
		content.set_active(active)

func _request_close() -> void:
	close_requested.emit()

func _request_minimize() -> void:
	minimize_requested.emit()

func _request_maximize() -> void:
	maximize_requested.emit()

func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed and not maximized and not event.double_click
		if event.pressed and event.double_click:
			maximize_requested.emit()
		elif dragging:
			drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and dragging:
		drag_requested.emit(get_global_mouse_position() - drag_offset)
