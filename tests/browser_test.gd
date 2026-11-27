extends SceneTree

# Run with: godot --headless --path . --script res://tests/browser_test.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	var browser = load("res://scenes/apps/browser.tscn").instantiate()
	browser.load_time = Vector2(0.5, 2.0)
	root.add_child(browser)
	await process_frame
	check(browser.loading and browser.page == null, "the home page is not shown instantly")
	check(browser.address.text == "home.oc" and browser.get_node("%Status").visible, "the address and a loading status appear at once")
	check(browser.get_node("%LoadBar").modulate.a > 0.0, "the progress bar is visible while loading")
	await wait(0.4)
	check(browser.loading, "a page takes at least half a second")
	await wait(1.7)
	check(not browser.loading and browser.page != null and browser.page.name == "Home", "a page arrives within two seconds")
	check(not browser.get_node("%Status").visible, "the loading status hides when the page arrives")
	check(browser.directory.has("bank.oc"), "search directory is filled from the home page")

	var old_page: Node = browser.page
	browser.reload()
	check(browser.loading and browser.page == null, "refresh drops the page and loads it again")
	await wait(2.1)
	check(browser.page != null and browser.page != old_page and browser.address.text == "home.oc", "refresh shows a fresh copy of the same page")

	# A newer navigation wins over a page that is still loading.
	browser.load_time = Vector2(0.3, 0.3)
	browser.open_url("news.oc")
	await wait(0.1)
	browser.open_url("about.oc")
	await wait(0.25)
	check(browser.loading and browser.page == null, "the cancelled page never appears")
	await wait(0.15)
	check(browser.page != null and browser.page.name == "About" and browser.address.text == "about.oc", "only the latest address is shown")

	browser._step(-1)
	check(browser.address.text == "news.oc" and browser.loading, "going back loads the page again")
	await wait(0.4)
	check(browser.page != null and browser.page.name == "News", "the previous page arrives after loading")

	browser.queue_free()
	await process_frame
	print("FAILURES: ", failures)
	quit(failures)
