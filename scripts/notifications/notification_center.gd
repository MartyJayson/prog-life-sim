extends VBoxContainer

## Stack of desktop notifications above the taskbar clock. Newest notifications appear on top.

signal activated(data: NotificationData)

const TOAST = preload("res://scenes/notification_toast.tscn")

func push(data: NotificationData) -> Control:
	var toast: Control = (data.toast if data.toast else TOAST).instantiate()
	add_child(toast)
	move_child(toast, 0)
	toast.setup(data)
	toast.activated.connect(_activate.bind(toast, data))
	toast.dismissed.connect(toast.close)
	if data.lifetime > 0.0:
		get_tree().create_timer(data.lifetime).timeout.connect(func() -> void:
			if is_instance_valid(toast):
				toast.close())
	return toast

func _activate(toast: Control, data: NotificationData) -> void:
	toast.close()
	activated.emit(data)
