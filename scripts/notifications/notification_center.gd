extends VBoxContainer

## Stack of desktop notifications above the taskbar clock. Newest notifications appear on top.

signal activated(data: NotificationData)

const TOAST = preload("res://scenes/notification_toast.tscn")

## Notifications delivered automatically after start-up, each after its own `delay`.
@export var scheduled: Array[NotificationData] = []

func _ready() -> void:
	for data in scheduled:
		get_tree().create_timer(data.delay).timeout.connect(push.bind(data))

func push(data: NotificationData) -> Control:
	var toast: Control = TOAST.instantiate()
	add_child(toast)
	move_child(toast, 0)
	toast.setup(data)
	toast.activated.connect(_activate.bind(toast, data))
	toast.dismissed.connect(toast.close)
	return toast

func _activate(toast: Control, data: NotificationData) -> void:
	toast.close()
	activated.emit(data)
