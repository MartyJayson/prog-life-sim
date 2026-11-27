extends SceneTree

# Run with: godot --headless --path . --script res://tests/login_test.gd
const TEST_PROFILES := "user://test_profiles.cfg"
const TEST_SETTINGS := "user://test_settings.cfg"
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
	var profiles = root.get_node("Profiles")
	var settings = root.get_node("GameSettings")
	profiles.path = TEST_PROFILES
	settings.path = TEST_SETTINGS
	root.get_node("SaveGame").directory = "user://test_login_saves"
	profiles.reset()

	var login = load("res://scenes/login.tscn").instantiate()
	root.add_child(login)
	await process_frame
	check(login.tiles.is_empty() and login.new_user.visible, "no users yet: only the New user tile")
	check(login.prompt.text.contains("New user"), "prompt points at New user when there are no users")

	login.new_user.pressed.emit()
	check(login.form.visible and not login.new_user.visible, "New user opens the name form")
	login._create()
	check(login.error.visible and profiles.users.is_empty(), "an empty name is rejected")

	profiles.create("Alex")
	await process_frame
	check(login.tiles.size() == 1 and login.tiles[0].text == "Alex", "a created user gets a tile")
	check(login.new_user.get_index() > login.tiles[0].get_index(), "user tiles sit above New user")
	check(profiles.name_error("alex") != "", "names are unique regardless of case")

	profiles.load_users()
	await process_frame
	check(profiles.users.size() == 1 and profiles.users[0].name == "Alex", "users persist in the profile file")

	var logged := []
	login.logged_in.connect(func(user_name: String) -> void: logged.append(user_name))
	login._open_form()
	login.name_edit.text = "  Sam  "
	login._create()
	check(profiles.users.size() == 2 and profiles.current == "Sam", "creating a user logs straight in as them")
	await create_timer(login.WELCOME_TIME + 0.2).timeout
	check(logged == ["Sam"], "login emits logged_in after the welcome screen")

	login._open_settings()
	var dialog = login.settings_dialog
	check(login.modal.visible and dialog.screen.item_count == settings.SCREEN_SIZES.size(), "settings list every screen size")
	dialog.volume.value = 40
	check(is_equal_approx(settings.volume, 0.4) and dialog.volume_value.text == "40 %", "the volume slider updates the setting")
	dialog.get_node("%Reset").pressed.emit()
	check(dialog.confirm.visible, "reset asks for confirmation first")
	dialog._reset()
	await process_frame
	check(profiles.users.is_empty() and login.tiles.is_empty(), "reset deletes every user")
	check(not FileAccess.file_exists(TEST_PROFILES), "reset removes the profile file")
	dialog._close()
	check(not login.modal.visible, "OK closes the settings")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_login_saves"))
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
