extends SceneTree

# Run with: godot --headless --path . --script res://tests/notification_test.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func live_toasts(center: Control) -> Array:
	return center.get_children().filter(func(toast): return not toast.closing)

func run() -> void:
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var center: Control = desktop.get_node("%Notifications")
	check(center.get_child_count() == 0, "no notifications at start-up")
	await create_timer(4.5).timeout
	check(center.get_child_count() == 0, "payment notification waits 5 seconds")
	await create_timer(0.7).timeout
	check(center.get_child_count() == 1, "payment notification arrives after 5 seconds")
	var payment: Control = center.get_child(0)
	check(payment.get_node("%Title").text.contains("OS Bank"), "payment notification has bank title")

	var extra := NotificationData.new()
	extra.title = "Test"
	extra.action = NotificationData.Action.APP
	extra.target = "calculator"
	var newer: Control = center.push(extra)
	await create_timer(0.3).timeout
	check(center.get_child(0) == newer, "newer notification is shown above older one")
	check(center.get_global_rect().end.y <= desktop.get_node("Taskbar").get_global_rect().position.y, "stack sits above the taskbar")

	await click(newer.get_node("Layout/Header/Row/Close").get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(live_toasts(center).size() == 1 and live_toasts(center)[0] == payment, "close button dismisses only that notification")
	check(desktop.manager.windows.is_empty(), "dismissing opens nothing")

	await click(payment.get_node("%Message").get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(live_toasts(center).is_empty(), "clicked notification disappears")
	check(desktop.manager.windows.has("browser"), "clicking payment notification opens the browser")
	if desktop.manager.windows.has("browser"):
		check(desktop.manager.windows["browser"].content.address.text == "bank.oc/payments", "browser shows the payments page")

	var app_event := NotificationData.new()
	app_event.action = NotificationData.Action.APP
	app_event.target = "calculator"
	desktop._notification_activated(app_event)
	check(desktop.manager.windows.has("calculator"), "APP action launches an app")

	desktop.queue_free()
	await process_frame
	print("FAILURES: ", failures)
	quit(failures)
