extends PanelContainer

## A single clickable notification card. Clicking the body activates it, the × button dismisses it.

signal activated
signal dismissed

@export var normal_style: StyleBox
@export var hover_style: StyleBox

var closing := false

func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func setup(data: NotificationData) -> void:
	%Title.text = data.title
	%Message.text = data.message
	%Icon.texture = data.icon
	%HeaderIcon.texture = data.icon
	%Icon.visible = data.icon != null
	%HeaderIcon.visible = data.icon != null
	%Accent.color = data.accent
	%Hint.visible = data.action != NotificationData.Action.NONE

func close() -> void:
	if closing:
		return
	closing = true
	mouse_filter = MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _gui_input(event: InputEvent) -> void:
	if closing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		activated.emit()

func _hover(entered: bool) -> void:
	add_theme_stylebox_override("panel", hover_style if entered else normal_style)

func _dismiss() -> void:
	dismissed.emit()
