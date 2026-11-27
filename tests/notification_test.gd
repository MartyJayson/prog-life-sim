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
	var mailbox = root.get_node("Mailbox")
	mailbox.reset_state()
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	var intro = desktop.get_node("IntroMail")
	intro.first_delay = 0.5
	intro.interval = 0.5
	root.add_child(desktop)
	await process_frame
	var center: Control = desktop.get_node("%Notifications")
	check(center.get_child_count() == 0 and mailbox.inbox.is_empty(), "no letters or notifications at start-up")

	await create_timer(0.6).timeout
	check(mailbox.inbox.size() == 1 and mailbox.inbox[0].sender_address == "no-reply@mail.oc", "the OS Mail welcome letter arrives first")
	check(live_toasts(center).size() == 1, "the letter shows a desktop notification")
	var toast: Control = center.get_child(0)
	check(toast.get_node("%Title").text.begins_with("Mail") and toast.get_node("%Message").text.containsn("Welcome"), "the notification names the letter")

	await create_timer(0.5).timeout
	check(mailbox.inbox.size() == 2 and mailbox.inbox[0].sender_name.containsn("Landlord"), "the landlord's rent letter comes second")
	check(mailbox.inbox[0].body.contains("bank.oc/payments"), "the rent letter links to OS Bank payments")

	await create_timer(0.5).timeout
	check(mailbox.inbox.size() == 3 and mailbox.inbox[0].sender_name == "Max Turner", "the friend's letter comes third")
	check(mailbox.inbox[0].body.contains("stupidjob.oc"), "the friend points to stupidjob.oc")
	check(live_toasts(center).size() == 3 and center.get_child(0).get_node("%Message").text.contains("Max Turner"), "newest notification is shown on top")
	check(center.get_global_rect().end.y <= desktop.get_node("Taskbar").get_global_rect().position.y, "stack sits above the taskbar")

	await create_timer(1.0).timeout
	check(mailbox.inbox.size() == 3, "the story letters are sent only once")

	var welcome_toast: Control = center.get_child(2)
	await click(welcome_toast.get_node("Layout/Header/Row/Close").get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(live_toasts(center).size() == 2 and not is_instance_valid(welcome_toast), "close button dismisses only that notification")
	check(desktop.manager.windows.is_empty(), "dismissing opens nothing")

	var rent_toast: Control = center.get_child(1)
	await click(rent_toast.get_node("%Message").get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(not is_instance_valid(rent_toast), "clicked notification disappears")
	check(desktop.manager.windows.has("mail"), "clicking a mail notification opens Mail")
	if desktop.manager.windows.has("mail"):
		var mail = desktop.manager.windows["mail"].content
		check(mail.selected == mailbox.inbox[1] and mail.selected.read, "Mail shows the letter from the notification")
		check(mail.get_node("%Subject").text.containsn("rent"), "the reading pane shows the rent letter")

	var app_event := NotificationData.new()
	app_event.action = NotificationData.Action.APP
	app_event.target = "calculator"
	desktop._notification_activated(app_event)
	check(desktop.manager.windows.has("calculator"), "APP action launches an app")

	# Taskbar tray.
	var clock_stack: Control = desktop.get_node("%Clock").get_parent()
	var wifi: Control = desktop.get_node("%Wifi")
	var battery: Control = desktop.get_node("%Battery")
	check(wifi.visible and battery.visible and wifi.texture != null and battery.texture != null, "the tray shows Wi-Fi and battery icons")
	check(battery.get_global_rect().end.x <= clock_stack.get_global_rect().position.x and wifi.get_global_rect().end.x <= battery.get_global_rect().position.x, "tray icons sit left of the clock, Wi-Fi first")
	check(not wifi.tooltip_text.is_empty() and battery.tooltip_text.contains("%"), "tray icons explain themselves on hover")

	# Bank notifications: green for money in, red for a payment; they hide by themselves.
	for old_toast in center.get_children():
		old_toast.queue_free()
	await process_frame
	var wallet = root.get_node("Wallet")
	wallet.deposit(250, "TinySoft — QA task 1041")
	wallet.withdraw(40, "DeadDrive — FlashMole 8 GB")
	await process_frame
	var bank_toasts := live_toasts(center)
	check(bank_toasts.size() == 2 and bank_toasts.all(func(t): return t.has_node("Row/Text/Amount")), "every bank transaction shows a bank notification")
	var income: Control = bank_toasts[1]
	var payment: Control = bank_toasts[0]
	check(income.get_node("%Amount").text == "+ $ 250" and income.get_node("%Title").text.begins_with("TinySoft"), "income shows the amount and its source")
	check(payment.get_node("%Amount").text == "− $ 40", "a payment shows a minus amount")
	var green: Color = income.get_theme_stylebox("panel").border_color
	var red: Color = payment.get_theme_stylebox("panel").border_color
	check(green.g > green.r and red.r > red.g and income.get_node("%Amount").get_theme_color("font_color") == green, "income is green and a payment is red")
	check(not income.has_node("Layout/Header"), "bank notifications look different from mail cards")
	if "--screenshot" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/bank_toasts.png")
	await create_timer(desktop.BANK_TOAST_LIFETIME + 0.4).timeout
	check(live_toasts(center).is_empty(), "bank notifications disappear after a few seconds")
	wallet.deposit(5, "Test")
	await process_frame
	await click(center.get_child(0).get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(desktop.manager.windows.has("browser") and desktop.manager.windows["browser"].content.address.text == "bank.oc", "clicking a bank notification opens bank.oc")

	desktop.queue_free()
	await process_frame
	print("FAILURES: ", failures)
	quit(failures)
