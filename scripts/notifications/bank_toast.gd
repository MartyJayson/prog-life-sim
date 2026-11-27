extends PanelContainer

## Compact OS Bank notification for money coming in or going out. Unlike the letter cards it has
## no title bar: a coloured stripe on the left (green for income, red for a payment), the amount
## and what it was for. It fades in quickly and hides by itself (NotificationData.lifetime).

signal activated
signal dismissed

var closing := false

func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)

## [param data].title is the amount ("+ $ 100"), message what it was for, accent the colour.
func setup(data: NotificationData) -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	style.border_color = data.accent
	style.bg_color = Color.WHITE.lerp(data.accent, 0.08)
	add_theme_stylebox_override("panel", style)
	%Amount.text = data.title
	%Amount.add_theme_color_override("font_color", data.accent)
	%Title.text = data.message
	%Time.text = GameClock.time_text()

func close() -> void:
	if closing:
		return
	closing = true
	mouse_filter = MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)

func _gui_input(event: InputEvent) -> void:
	if closing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		activated.emit()

func _dismiss() -> void:
	dismissed.emit()
