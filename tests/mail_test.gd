extends SceneTree

# Run with: godot --headless --path . --script res://tests/mail_test.gd
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
	load("res://scripts/apps/browser.gd").instant_loading = true
	var mailbox = root.get_node("Mailbox")
	mailbox.reset_state()
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	var intro = desktop.get_node("IntroMail")
	intro.letters = intro.letters.slice(0, 1)
	intro.first_delay = 0.1
	root.add_child(desktop)
	await create_timer(0.2).timeout
	check(desktop.get_node("Shortcuts").has_node("mail") and desktop.menu.has_node("List/mail"), "mail has a desktop shortcut and a menu entry")
	desktop.get_node("Shortcuts/mail").launched.emit()
	await process_frame
	var mail = desktop.manager.windows["mail"].content
	var rows: Array = mail.rows.get_children().filter(func(row): return row != mail.get_node("%Empty"))
	check(rows.size() == 1, "inbox holds exactly one letter")
	check(mail.unread_count() == 1 and mail.get_node("Panes/Folders/List/Inbox").text.ends_with("1"), "welcome letter starts unread")
	check(rows[0].message.subject.containsn("welcome"), "the letter is the welcome letter")

	rows[0].pressed.emit()
	await process_frame
	check(mail.unread_count() == 0 and mail.get_node("%Letter").visible, "opening the letter marks it read and shows it")
	check(mail.get_node("%Body").get_parsed_text().containsn("registered"), "letter says the mailbox is registered")

	var linked: String = mail.linkify("Visit home.oc, https://news.oc/desk. or [url=bank.oc]OS Bank[/url]; mail no-reply@mail.oc")
	check(linked.contains("[url=home.oc]home.oc[/url]"), "bare .oc address becomes a link")
	check(linked.contains("[url=https://news.oc/desk]https://news.oc/desk[/url]"), "http link is linked without trailing punctuation")
	check(linked.contains("[color=#1c6bcc][url=bank.oc]OS Bank[/url][/color]"), "explicit url tag is kept and coloured")
	check(not linked.contains("[url=mail.oc]"), "email addresses are not turned into site links")

	mail.get_node("%Body").meta_clicked.emit("home.oc")
	await process_frame
	check(desktop.manager.windows.has("browser"), "clicking a link opens the browser")
	check(desktop.manager.windows["browser"].content.address.text == "home.oc", "browser shows the linked site")

	mail.get_node("Panes/Folders/List/Sent").pressed.emit()
	await process_frame
	check(mail.get_node("%Empty").visible and not mail.get_node("%Letter").visible, "other folders are empty")

	desktop.queue_free()
	await process_frame
	quit(failures)
