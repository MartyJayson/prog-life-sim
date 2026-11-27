extends SceneTree

# Run with: godot --headless --path . --script res://tests/skamcoin_test.gd
# Pass `-- --screenshot` to also save res://.godot/skamcoin.png (needs a window, not --headless).
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
	var clock: Node = root.get_node("GameClock")
	var market: Node = root.get_node("SkamMarket")
	var wallet: Node = root.get_node("Wallet")
	clock.running = false

	# Game time: one day lasts two real hours.
	clock.reset_state()
	check(clock.stamp() == "01.09.2028  08:30", "a new game starts on 01.09.2028 at 08:30")
	clock.advance(5.0)
	check(clock.time_text() == "08:31", "five real seconds are one game minute")
	clock.advance(7200.0 - 5.0)
	check(clock.stamp() == "02.09.2028  08:30", "two real hours are one game day")
	var seconds := [0]
	var count_second := func() -> void: seconds[0] += 1
	clock.second_passed.connect(count_second)
	clock.advance(3.5)
	check(seconds[0] == 3, "the clock ticks once per real second")
	clock.second_passed.disconnect(count_second)
	clock.reset_state()

	# Market: a fresh game starts at the fixed price with a day of candles behind it.
	market.reset_state()
	check(is_equal_approx(market.price, 101.44), "SkamCoin starts at $ 101.44")
	check(market.candles.size() == market.CANDLE_LIMIT and market.CANDLE_LIMIT * market.CANDLE_SECONDS == 3600, "an hour of 30-second candles is generated")
	check(is_equal_approx(market.candles[-1].c, 101.44), "the generated history ends at the start price")
	check(market.candles.all(func(c: Dictionary) -> bool: return c.h >= maxf(c.o, c.c) and c.l <= minf(c.o, c.c)), "every candle's wicks cover its body")
	check(market.format_price(1234.5) == "$ 1 234.50" and market.format_price(0.012345) == "$ 0.0123", "prices are grouped and keep enough decimals")

	# The price moves every second, even with no page open.
	var start_price: float = market.price
	clock.advance(1.0)
	check(market.price != start_price, "the price changes after one second")
	for i in 600:
		clock.advance(1.0)
	check(market.price > 0.0 and market.candles[-1].t == clock.unix() - posmod(clock.unix(), 30), "the newest candle is the current 30 game seconds")
	check(market.candles.size() == market.CANDLE_LIMIT and market.candles[-1].t - market.candles[0].t < 3600, "no more than one game hour of prices is kept")
	var five: Array = market.candles_for(300, 10)
	check(five.size() == 10 and five[-1].t % 300 == 0, "five-minute candles are built from one-minute candles")

	# Black swans: x10 and /5 play out over several seconds and keep most of the move.
	var before: float = market.price
	market.trigger_black_swan(10.0)
	for i in 20:
		clock.advance(1.0)
	check(market.price > before * 4.0, "a x10 pump multiplies the price (%.2f -> %.2f)" % [before, market.price])
	before = market.price
	market.trigger_black_swan(0.2)
	for i in 20:
		clock.advance(1.0)
	check(market.price < before * 0.4, "a x5 crash divides the price (%.2f -> %.2f)" % [before, market.price])

	# Long run: the price wanders but stays alive; black swans are rare.
	market.reset_state()
	var swans := [0]
	var count_swan := func(_factor: float) -> void: swans[0] += 1
	market.black_swan.connect(count_swan)
	var low := INF
	var high := 0.0
	for i in 7200:
		market.step()
		low = minf(low, market.price)
		high = maxf(high, market.price)
	market.black_swan.disconnect(count_swan)
	print("Two hours of market: low %.2f, high %.2f, black swans %d" % [low, high, swans[0]])
	check(high > low * 1.02, "the price moves both ways over a game day")
	check(swans[0] <= 6, "black swans stay rare")

	# Trading.
	wallet.reset_state()
	market.reset_state()
	check(market.buy(wallet.balance + 1) == 0.0 and market.holdings == 0.0, "cannot buy for more than the bank balance")
	var coins: float = market.buy(500)
	check(is_equal_approx(coins, 500 * 0.995 / 101.44) and wallet.balance == wallet.START_BALANCE - 500, "buying for $500 takes the fee and charges the bank")
	check(is_equal_approx(market.average_price(), 500.0 / coins), "the average buy price includes the fee")
	check(market.sell(coins * 2.0) == 0 and is_equal_approx(market.holdings, coins), "cannot sell more SKAM than owned")
	var paid: int = market.sell(coins / 2.0)
	check(paid == floori(coins / 2.0 * market.price * 0.995) and wallet.balance == wallet.START_BALANCE - 500 + paid, "selling pays dollars to the bank")
	check(is_equal_approx(market.cost_basis, 250.0), "selling half keeps half of the cost basis")
	check(market.trades.size() == 2 and market.trades[0].side == "sell", "orders are logged newest first")
	var saved: Dictionary = market.save_state()
	market.sell(market.holdings)
	check(market.holdings == 0.0 and market.cost_basis == 0.0, "selling everything empties the SKAM wallet")
	market.load_state(saved)
	check(is_equal_approx(market.holdings, coins / 2.0) and market.candles.size() == saved.candles.size() / 6, "holdings and candles are saved and restored")

	# The site.
	var browser = load("res://scenes/apps/browser.tscn").instantiate()
	browser.custom_minimum_size = Vector2(1080, 880)
	root.add_child(browser)
	await process_frame
	check(browser.directory.has("skamcoin.oc"), "SkamCoin is listed in the web directory")
	browser.open_url("skamcoin.oc")
	await process_frame
	await process_frame
	var page = browser.page
	check(page != null and page.name == "SkamCoin", "skamcoin.oc opens the exchange")
	check(page.get_node("%Price").text == market.format_price(market.price), "the page shows the live price")
	check(page.chart.candles.size() > 50, "the chart is full of candles (%d)" % page.chart.candles.size())
	clock.advance(1.0)
	check(page.get_node("%Price").text == market.format_price(market.price), "the page follows every tick")
	page.set_timeframe(300)
	check(page.chart.candles.size() >= 12 and page.chart.candles[-1].t % 300 == 0, "the 5m timeframe shows five-minute candles")
	page.set_timeframe(30)
	check(page.chart.show_seconds and page.chart.candles.size() > 60, "the 30s timeframe shows the whole hour with seconds")
	page.set_timeframe(60)
	page.get_node("%BuyAmount").value = 100
	var before_balance: int = wallet.balance
	page._buy()
	check(wallet.balance == before_balance - 100, "the Buy button spends dollars")
	check(page.get_node("%HeaderUsd").text == wallet.format_money(wallet.balance) and page.get_node("%HeaderSkam").text == market.format_coins(market.holdings), "the header shows dollar and SKAM balances")
	page._sell_share(1.0)
	page._sell()
	check(market.holdings == 0.0, "MAX then Sell sells every coin")
	check(page.get_node("%OrderRows").get_child_count() == mini(market.trades.size(), page.ORDER_ROWS), "orders appear in the list")

	if "--screenshot" in OS.get_cmdline_user_args():
		market.buy(300)
		for i in 300:
			clock.advance(1.0)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skamcoin.png")
		browser.get_node("%Scroller").scroll_vertical = 100000
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skamcoin_bottom.png")

	browser.queue_free()
	await process_frame
	print("SkamCoin checks finished; failures: ", failures)
	quit(1 if failures else 0)
