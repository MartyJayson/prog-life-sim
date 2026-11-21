extends SceneTree

# Run with: godot --headless --path . --script res://tests/terminal_test.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func run() -> void:
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	await process_frame
	check(desktop.get_node("Shortcuts").has_node("terminal") and desktop.menu.has_node("List/terminal"), "terminal has a desktop shortcut and a menu entry")
	desktop.get_node("Shortcuts/terminal").launched.emit()
	var window = desktop.manager.windows["terminal"]
	var term = window.content
	await process_frame
	check(term.buffer.begins_with("OS [") and term.prompt.text == "C:\\Users\\User>", "terminal opens with a header and a prompt")
	check(term.input.has_focus(), "input is focused when the window is active")
	var palette: Array = term.PALETTE

	term.submit("color 0a")
	check(term.foreground == 10 and term.background == 0, "color 0A selects light green on black")
	check(term.output.get_theme_color("font_color") == palette[10][1] and term.input.get_theme_color("font_color") == palette[10][1], "text and input use the new font colour")
	check(term.buffer.ends_with("C:\\Users\\User>color 0a\n\n"), "command is echoed like cmd")
	term.submit("COLOR 1E")
	check(term.background == 1 and term.foreground == 14 and term._panel_style.bg_color == palette[1][1], "two digits set background and text")
	term.submit("color c")
	check(term.background == 0 and term.foreground == 12, "one digit sets the text colour on black")
	term.submit("color 44")
	check(term.foreground == 12 and term.buffer.contains("must not be the same"), "equal colours are rejected")
	term.submit("color zz")
	check(term.foreground == 12 and term.buffer.contains("COLOR [attr]"), "invalid attribute prints COLOR help")
	term.submit("color")
	check(term.background == 0 and term.foreground == 7, "COLOR without arguments restores defaults")
	term.submit("dir")
	check(term.buffer.contains("'dir' is not recognized as an internal or external"), "unknown command reports an error")
	term.submit("help")
	check(term.buffer.contains("COLOR") and term.buffer.contains("CLS"), "HELP lists commands")
	term.submit("cls")
	check(term.buffer.is_empty() and not term.output.visible, "CLS clears the screen")

	term.submit("color 2f")
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	term._input_key(key)
	check(term.input.text == "color 2f", "up arrow recalls the previous command")

	var other = load("res://scenes/apps/terminal.tscn").instantiate()
	root.add_child(other)
	await process_frame
	check(other._panel_style.bg_color == palette[0][1], "colours of one terminal do not leak into another")
	other.queue_free()

	term.submit("exit")
	await process_frame
	check(not desktop.manager.windows.has("terminal"), "EXIT closes the terminal window")

	if "--capture" in OS.get_cmdline_user_args():
		desktop._open("terminal")
		term = desktop.manager.windows["terminal"].content
		await process_frame
		for line in ["help", "color /?", "color 0a", "dir"]:
			term.submit(line)
		term.input.text = "color 1"
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/claude/cap/terminal.png")

	desktop.queue_free()
	await process_frame
	print("Terminal checks finished; failures: ", failures)
	quit(1 if failures else 0)
