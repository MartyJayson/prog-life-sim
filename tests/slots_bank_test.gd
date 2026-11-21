extends SceneTree

# Run with: godot --headless --path . --script res://tests/slots_bank_test.gd
# Loaded at runtime: the page script uses the Wallet autoload, which is registered after this script compiles.
var Slots: GDScript

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func filled(symbol: String) -> Array:
	return [[symbol, symbol, symbol], [symbol, symbol, symbol], [symbol, symbol, symbol]]

func run() -> void:
	Slots = load("res://scripts/web/slots.gd")
	var wallet: Node = root.get_node("Wallet")
	check(wallet.format_money(1234567) == "$ 1 234 567", "money is grouped by thousands")
	check(wallet.balance == wallet.START_BALANCE and wallet.history.size() == 1, "every launch starts with a fresh account")

	# Payout rules.
	check(Slots.total_payout(Slots.evaluate(filled("$"), 10)) == 8 * 50 * 10, "full $ grid pays all 8 lines at x50")
	check(Slots.total_payout(Slots.evaluate(filled("10"), 10)) == 8 * 3 * 10, "full 10 grid pays all 8 lines at x3")
	var grid := [["K", "J", "Q"], ["K", "Q", "J"], ["Q", "10", "10"]]
	var wins: Array = Slots.evaluate(grid, 20)
	check(wins.size() == 1 and wins[0].symbol == "Q" and wins[0].payout == 160, "anti-diagonal Q-Q-Q pays bet x8")
	grid = [["J", "J", "J"], ["J", "K", "10"], ["J", "Q", "K"]]
	wins = Slots.evaluate(grid, 10)
	check(wins.size() == 2 and Slots.total_payout(wins) == 80, "row and column of J are paid separately and summed")
	check(Slots.evaluate([["10", "J", "Q"], ["K", "💩", "10"], ["J", "Q", "K"]], 10).is_empty(), "no line, no payout")
	check(Slots.evaluate(filled("💩"), 10).is_empty(), "poop lines pay nothing")
	check(Slots.evaluate([["Q", "Q", "💩"], ["K", "J", "10"], ["J", "10", "K"]], 10).is_empty(), "poop breaks a line")
	wins = Slots.evaluate([["10", "J", "Q"], ["K", "$", "10"], ["J", "Q", "K"]], 10)
	check(wins.size() == 1 and wins[0].payout == 10 and wins[0].line == -1, "a single $ returns the bet once")
	wins = Slots.evaluate([["$", "J", "Q"], ["K", "10", "J"], ["J", "Q", "$"]], 10)
	check(wins.size() == 1 and wins[0].combo == "$-$" and wins[0].payout == 20, "two $ on a diagonal pay x2 without the refund")
	wins = Slots.evaluate([["$", "$", "K"], ["$", "J", "10"], ["Q", "10", "J"]], 10)
	check(wins.size() == 2 and Slots.total_payout(wins) == 40, "two $-$ lines are paid separately")
	wins = Slots.evaluate([["$", "J", "Q"], ["K", "10", "J"], ["Q", "Q", "Q"]], 10)
	check(Slots.total_payout(wins) == 90, "Q line and a lone $ refund add up")

	# Exact return to player over every combination of reel stops.
	var paid := 0
	var spins := 0
	var hits := 0
	for a in Slots.REELS[0].size():
		for b in Slots.REELS[1].size():
			for c in Slots.REELS[2].size():
				var total: int = Slots.total_payout(Slots.evaluate(Slots.build_grid([a, b, c]), 1))
				paid += total
				hits += int(total > 0)
				spins += 1
	var rtp := float(paid) / spins
	print("RTP %.4f, hit rate %.3f" % [rtp, float(hits) / spins])
	check(rtp > 0.9 and rtp < 1.0, "machine keeps a small house edge")

	# Desktop shortcuts open the sites in the browser.
	var desktop = load("res://scenes/desktop.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	await process_frame
	var clock: Label = desktop.get_node("%Clock")
	var date: Label = desktop.get_node("%Date")
	check(date.text == "01.09.2028" and date.position.y >= clock.position.y + clock.size.y, "the game date appears below the clock")
	var shortcuts = desktop.get_node("Shortcuts")
	check(shortcuts.has_node("slots") and shortcuts.has_node("bank"), "desktop has Slots OS and OS Bank shortcuts")
	shortcuts.get_node("bank").launched.emit()
	var browser = desktop.manager.windows["browser"].content
	await process_frame
	check(browser.address.text == "bank.oc", "bank shortcut opens bank.oc")
	check(browser.page.get_node("%Balance").text == wallet.format_money(wallet.balance), "bank shows the wallet balance")
	shortcuts.get_node("slots").launched.emit()
	await process_frame
	check(browser.address.text == "casino.oc" and desktop.manager.windows.size() == 1, "slots shortcut reuses the browser window")

	browser.page.get_node("%Slots").pressed.emit()

	# A real spin moves money through the wallet and matches the reels on screen.
	wallet.deposit(1000, "Test")
	var slots = browser.page
	var start: int = wallet.balance
	slots.bet_index = 1
	slots._spin()
	check(slots.spinning and wallet.balance == start - 25, "spin withdraws the bet immediately")
	var expected: int = slots.pending_win
	for i in 40:
		await process_frame
	check(slots.reels.all(func(r): return r.spinning), "reels keep spinning until stopped")
	slots._spin()
	check(slots.reels[0].stopping and not slots.reels[1].stopping, "spin button stops only the next reel")
	while slots.reels[0].spinning:
		await process_frame
	check(slots.spinning and slots.reels[1].spinning and slots.reels[2].spinning and wallet.balance == start - 25, "no payout while reels still spin")
	slots._spin()
	check(slots.reels[1].stopping and not slots.reels[2].stopping, "reels stop left to right, one per press")
	slots._spin()
	while slots.spinning:
		await process_frame
	var grid_on_screen := []
	for row in 3:
		grid_on_screen.append([slots.reels[0].symbol_at(row), slots.reels[1].symbol_at(row), slots.reels[2].symbol_at(row)])
	var shown: int = Slots.total_payout(Slots.evaluate(grid_on_screen, 25))
	check(shown == expected and wallet.balance == start - 25 + expected, "paid amount matches the visible reels")

	# Leaving mid-spin still settles a decided win.
	var paid_before: int = wallet.balance
	slots.auto_stop.wait_time = 0.2
	slots._spin()
	slots.auto_stop.start(0.2)
	while slots.spinning:
		await process_frame
	check(true, "auto-stop finishes an untouched spin")
	paid_before = wallet.balance
	slots._spin()
	slots.pending_win = 77
	browser.open_url("bank.oc")
	await process_frame
	check(wallet.balance == paid_before - 25 + 77, "leaving the page mid-spin pays the pending win")
	check(browser.page.get_node("%Rows").get_child_count() > 0, "bank lists recent operations")

	# Not enough money: no spin, no withdrawal.
	browser.open_url("casino.oc/slots")
	await process_frame
	slots = browser.page
	wallet.withdraw(wallet.balance, "Test")
	slots._spin()
	check(not slots.spinning and wallet.balance == 0 and slots.message.text != "", "empty wallet blocks the spin with a message")

	# Rent uses the same wallet and stays paid when navigating between bank pages.
	browser.open_url("bank.oc")
	browser.page.get_node("TopBar/Row/Payments").pressed.emit()
	check(browser.address.text == "bank.oc/payments", "the bank payments tab opens its own page")
	var payments = browser.page
	check(payments.get_node("%Date").text == date.text and payments.get_node("%RentAmount").text == "$ 500", "today's payments show the game date and rent amount")
	var pay: Button = payments.get_node("%Pay")
	var history_size: int = wallet.history.size()
	pay.pressed.emit()
	check(wallet.balance == 0 and wallet.history.size() == history_size and pay.is_visible_in_tree() and payments.get_node("%PaymentError").visible, "insufficient funds keep rent pending without a debit")
	wallet.deposit(1000, "Test")
	check(not payments.get_node("%PaymentError").visible, "adding funds clears the rent payment error")
	history_size = wallet.history.size()
	pay.pressed.emit()
	pay.pressed.emit()
	check(wallet.balance == 500 and wallet.history.size() == history_size + 1, "paying rent debits $500 exactly once")
	check(payments.get_node("%Balance").text == "$ 500" and not pay.is_visible_in_tree() and payments.get_node("%Empty").visible, "a successful payment updates the balance and clears pending rent")
	check(wallet.history[0].amount == -500 and wallet.history[0].time.begins_with(date.text), "rent is recorded as a debit on the game date")
	payments.get_node("TopBar/Row/Accounts").pressed.emit()
	var latest_operation: Control = browser.page.get_node("%Rows").get_child(0)
	check(browser.address.text == "bank.oc" and latest_operation.get_node("Row/Text/Title").text == "Rent payment" and latest_operation.get_node("Row/Amount").text == "−$ 500", "the accounts page shows the rent debit in card history")
	browser.back.pressed.emit()
	check(browser.address.text == "bank.oc/payments" and browser.page.get_node("%Empty").visible, "reopening the payments page keeps rent paid")

	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
		browser.open_url("casino.oc/slots")
		await process_frame
		slots = browser.page
		slots._show_result([{"line": 6, "symbol": "$", "multiplier": 50, "payout": 500}, {"line": 1, "symbol": "Q", "multiplier": 8, "payout": 80}], 10)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/slots-win.png")
		browser.open_url("bank.oc")
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/bank.png")

	for i in wallet.HISTORY_LIMIT:
		wallet.deposit(1, "Test")
	check(not wallet.pay_rent() and wallet.history.all(func(entry): return entry.title != "Rent payment"), "rent stays paid when its receipt ages out of the history")

	desktop.queue_free()
	await process_frame
	print("Slots and bank checks finished; failures: ", failures)
	quit(1 if failures else 0)
