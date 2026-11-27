extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	load("res://scripts/apps/browser.gd").instant_loading = true
	var wallet = root.get_node("Wallet")
	var browser = load("res://scenes/apps/browser.tscn").instantiate()
	root.add_child(browser)
	browser.open_url("casino.oc")
	browser.page.get_node("%Blackjack").pressed.emit()
	var game = browser.page
	var bet: SpinBox = game.get_node("%Bet")
	assert(bet.min_value == 5 and bet.max_value == 500)
	bet.value = 500
	await process_frame
	game.get_node("%Deal").pressed.emit()
	assert(wallet.tokens == wallet.WELCOME_BONUS and wallet.balance == 1000 and game.stake == 0)
	wallet.win_tokens(100000, "Test")
	bet.value = 50
	await process_frame
	for round_index in 60:
		var before: int = wallet.tokens
		game.get_node("%Deal").pressed.emit()
		assert(game.player.size() == 2 and game.dealer.size() == 2 and game.deck.size() == 48)
		if game.stake > 0:
			assert(wallet.tokens == before - 50)
			assert(game.get_node("%Dealer").get_child(1).get_node("Face").text == "◆")
			if round_index % 2 == 0:
				game.get_node("%Hit").pressed.emit()
			game.get_node("%Stand").pressed.emit()
		var player_score: int = game.score(game.player)
		var dealer_score: int = game.score(game.dealer)
		var expected := before
		if player_score > 21 or (dealer_score <= 21 and dealer_score > player_score):
			expected -= 50
		elif dealer_score != player_score:
			expected += 50
		assert(wallet.tokens == expected and wallet.balance == 1000 and game.stake == 0)
		await process_frame
	while game.stake == 0:
		game.get_node("%Deal").pressed.emit()
	browser.open_url("casino.oc")
	assert(game.stake == 0)
	print("Blackjack rounds, stakes, payouts and navigation passed")
	quit()
