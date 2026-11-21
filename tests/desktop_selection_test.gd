extends SceneTree

# Run with: godot --headless --path . --script res://tests/desktop_selection_test.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)

func click(point: Vector2, double_click := false) -> void:
	move_mouse(point)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.double_click = double_click and down
		root.push_input(event, true)
	await process_frame

func selected_count(shortcuts: GridContainer) -> int:
	var count := 0
	for icon in shortcuts.get_children():
		count += int(icon.button_pressed)
	return count

func run() -> void:
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	await process_frame
	var shortcuts = desktop.get_node("Shortcuts")
	check(selected_count(shortcuts) == 0, "desktop opens without selected icons")
	for icon in shortcuts.get_children():
		await click(icon.get_global_rect().get_center())
		check(selected_count(shortcuts) == 1 and icon.button_pressed, "click selects only " + str(icon.name))
	check(desktop.manager.windows.is_empty(), "single clicks do not launch apps")
	var browser = shortcuts.get_node("browser")
	var snake = shortcuts.get_node("snake")
	await click(browser.get_global_rect().get_center())
	await click(snake.get_global_rect().get_center())
	check(not browser.button_pressed and snake.button_pressed and selected_count(shortcuts) == 1, "selecting second icon clears first selection")
	await click(snake.get_global_rect().get_center())
	check(snake.button_pressed and selected_count(shortcuts) == 1, "clicking selected icon keeps it selected")
	move_mouse(browser.get_global_rect().get_center())
	await process_frame
	check(not browser.button_pressed and snake.button_pressed, "hover does not change selection")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/desktop-selection.png")
	await click(Vector2(800, 600))
	check(selected_count(shortcuts) == 0, "clicking empty desktop clears selection")
	await click(browser.get_global_rect().get_center(), true)
	check(desktop.manager.windows.has("browser") and selected_count(shortcuts) == 1, "double-click still opens the selected app")
	var bank: Button = shortcuts.get_node("bank")
	var slots: Button = shortcuts.get_node("slots")
	check(bank.icon == browser.icon and slots.icon == browser.icon, "website shortcuts use the Internet icon")
	var badge: Control = bank.get_node("ShortcutBadge")
	await click(badge.get_global_rect().get_center(), true)
	check(desktop.manager.windows["browser"].content.address.text == "bank.oc" and bank.button_pressed, "double-clicking the shortcut badge opens the site")
	desktop.queue_free()
	await process_frame
	print("Desktop selection checks finished; failures: ", failures)
	quit(1 if failures else 0)
