extends VBoxContainer

## skamcoin.oc — SkamCoin exchange: live SKAM/USD candles and spot buying and selling.
## The market itself lives in the `SkamMarket` autoload and keeps moving while this page is closed.

const ORDER_ROW = preload("res://scenes/web/skamcoin_order_row.tscn")
const ORDER_ROWS := 6
const UP := Color("#16c784")
const DOWN := Color("#ea3943")
const NEUTRAL := Color("#dfe5ec")
## Selling within this many SKAM of the whole balance sells everything (the field rounds to 4 decimals).
const SELL_ALL_SLACK := 0.0001

## Candle size in game seconds.
var timeframe := 60
var _previous_price := 0.0
var _hovered: Dictionary = {}
var _notice_fade: Tween

@onready var chart: Control = %Chart
@onready var buy_amount: SpinBox = %BuyAmount
@onready var sell_amount: SpinBox = %SellAmount
@onready var notice: Label = %Notice

func _ready() -> void:
	_previous_price = SkamMarket.price
	SkamMarket.ticked.connect(_tick.unbind(1))
	SkamMarket.portfolio_changed.connect(_refresh_portfolio)
	Wallet.changed.connect(_refresh_portfolio.unbind(1))
	chart.hovered.connect(_show_readout)
	chart.resized.connect(_redraw_chart)
	_tick()
	_refresh_portfolio()

func set_timeframe(value: int) -> void:
	timeframe = value
	chart.show_seconds = timeframe < 60
	_redraw_chart()

func _tick() -> void:
	var price := SkamMarket.price
	var price_label: Label = %Price
	price_label.text = SkamMarket.format_price(price)
	if price != _previous_price:
		price_label.add_theme_color_override("font_color", UP if price > _previous_price else DOWN)
	_previous_price = price
	var change := SkamMarket.hour_change()
	var change_label: Label = %Change
	change_label.text = "%s%s%%  1h" % ["+" if change >= 0.0 else "−", SkamMarket.format_number(absf(change), 2)]
	change_label.add_theme_color_override("font_color", UP if change >= 0.0 else DOWN)
	var stats := SkamMarket.hour_stats()
	%DayHigh.text = SkamMarket.format_price(stats.high)
	%DayLow.text = SkamMarket.format_price(stats.low)
	%DayVolume.text = SkamMarket.format_compact(stats.volume) + " SKAM"
	_refresh_alert()
	_redraw_chart()
	_refresh_trade()
	_refresh_holdings_value()

func _redraw_chart() -> void:
	if chart == null:
		return
	chart.show_candles(SkamMarket.candles_for(timeframe, chart.capacity()), SkamMarket.price)
	if _hovered.is_empty():
		_show_readout({})

## Open / high / low / close of the hovered candle, or of the newest one.
func _show_readout(candle: Dictionary) -> void:
	_hovered = candle
	if candle.is_empty() and not chart.candles.is_empty():
		candle = chart.candles[-1]
	if candle.is_empty():
		%Readout.text = ""
		return
	var change: float = (candle.c / candle.o - 1.0) * 100.0 if candle.o > 0.0 else 0.0
	%Readout.text = "%s   O %s   H %s   L %s   C %s   %s%s%%" % [
		GameClock.format_time(candle.t, chart.show_seconds), _short(candle.o), _short(candle.h), _short(candle.l), _short(candle.c),
		"+" if change >= 0.0 else "−", SkamMarket.format_number(absf(change), 2),
	]

func _short(value: float) -> String:
	return SkamMarket.format_price(value).trim_prefix("$ ")

func _refresh_alert() -> void:
	var running := SkamMarket.is_swan_running()
	%Alert.visible = running
	if running:
		var pump := SkamMarket.swan_factor > 1.0
		%AlertText.text = "EXTREME VOLATILITY — SKAM is %s right now!" % ("pumping to the moon" if pump else "crashing hard")
		%AlertText.add_theme_color_override("font_color", UP if pump else DOWN)

func _refresh_portfolio() -> void:
	%Holdings.text = SkamMarket.format_coins(SkamMarket.holdings) + " SKAM"
	%HeaderUsd.text = Wallet.format_money(Wallet.balance)
	%HeaderSkam.text = SkamMarket.format_coins(SkamMarket.holdings)
	%AveragePrice.text = SkamMarket.format_price(SkamMarket.average_price()) if SkamMarket.holdings > 0.0 else "—"
	_refresh_holdings_value()
	_refresh_trade()
	var rows: VBoxContainer = %OrderRows
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for trade: Dictionary in SkamMarket.trades.slice(0, ORDER_ROWS):
		var buying: bool = trade.get("side", "") == "buy"
		var row: Control = ORDER_ROW.instantiate()
		rows.add_child(row)
		var side: Label = row.get_node("Side")
		side.text = "BUY" if buying else "SELL"
		side.add_theme_color_override("font_color", UP if buying else DOWN)
		row.get_node("Text/Amount").text = SkamMarket.format_coins(trade.get("coins", 0.0)) + " SKAM"
		row.get_node("Text/Time").text = "@ %s   ·   %s" % [SkamMarket.format_price(trade.get("price", 0.0)), str(trade.get("time", "")).get_slice("  ", 1)]
		row.get_node("Usd").text = ("−" if buying else "+") + Wallet.format_money(int(trade.get("usd", 0)))
	%OrdersEmpty.visible = rows.get_child_count() == 0

func _refresh_holdings_value() -> void:
	%HoldingsValue.text = "Worth " + SkamMarket.format_price(SkamMarket.holdings_value())
	var profit_label: Label = %Profit
	if SkamMarket.holdings <= 0.0:
		profit_label.text = "—"
		profit_label.add_theme_color_override("font_color", NEUTRAL)
		return
	var profit := SkamMarket.profit()
	var percent := profit / SkamMarket.cost_basis * 100.0 if SkamMarket.cost_basis > 0.0 else 0.0
	profit_label.text = "%s%s (%s%s%%)" % ["+" if profit >= 0.0 else "", SkamMarket.format_price(profit).replace("$ −", "−$ "),
		"+" if percent >= 0.0 else "−", SkamMarket.format_number(absf(percent), 2)]
	profit_label.add_theme_color_override("font_color", UP if profit >= 0.0 else DOWN)

## Updates both order forms for the current price and balances.
func _refresh_trade() -> void:
	var price_text := SkamMarket.format_price(SkamMarket.price)
	%BuyAvailable.text = "Available  " + Wallet.format_money(Wallet.balance)
	var usd := int(buy_amount.value)
	%BuyPrice.text = price_text
	%BuyFee.text = "$ " + SkamMarket.format_number(usd * SkamMarket.FEE, 2)
	%BuyGet.text = SkamMarket.format_coins(SkamMarket.coins_for(usd)) + " SKAM"
	%Buy.disabled = not Wallet.can_afford(usd)
	%Buy.text = "Buy for " + Wallet.format_money(usd)

	%SellAvailable.text = "Available  %s SKAM" % SkamMarket.format_coins(SkamMarket.holdings)
	var coins := _sell_coins()
	%SellPrice.text = price_text
	%SellFee.text = "$ " + SkamMarket.format_number(coins * SkamMarket.price * SkamMarket.FEE, 2)
	var receive := SkamMarket.usd_for(coins)
	%SellGet.text = Wallet.format_money(receive)
	%Sell.disabled = coins <= 0.0 or coins > SkamMarket.holdings or receive < 1
	%Sell.text = "Sell for " + Wallet.format_money(receive)

## SKAM in the sell field; a value that rounds to the whole balance means "sell everything".
func _sell_coins() -> float:
	var coins := sell_amount.value
	if SkamMarket.holdings > 0.0 and absf(coins - SkamMarket.holdings) <= SELL_ALL_SLACK:
		return SkamMarket.holdings
	return coins

func _buy_share(share: float) -> void:
	buy_amount.value = maxi(floori(Wallet.balance * share), 1)

func _sell_share(share: float) -> void:
	sell_amount.value = SkamMarket.holdings * share

func _buy() -> void:
	_commit_typed(buy_amount)
	var usd := int(buy_amount.value)
	var coins := SkamMarket.buy(usd)
	if coins > 0.0:
		_notify("Bought %s SKAM for %s." % [SkamMarket.format_coins(coins), Wallet.format_money(usd)], UP)
	else:
		_notify("Order rejected: not enough money in your OS Bank account.", DOWN)

func _sell() -> void:
	_commit_typed(sell_amount)
	var coins := _sell_coins()
	var usd := SkamMarket.sell(coins)
	if usd > 0:
		_notify("Sold %s SKAM for %s." % [SkamMarket.format_coins(coins), Wallet.format_money(usd)], UP)
		if SkamMarket.holdings <= 0.0:
			sell_amount.value = 0.0
	else:
		_notify("Order rejected: you have %s SKAM." % SkamMarket.format_coins(SkamMarket.holdings), DOWN)

## Applies an amount the player is still typing; values set by presets are already current.
func _commit_typed(box: SpinBox) -> void:
	if box.get_line_edit().has_focus():
		box.apply()

func _notify(text: String, color: Color) -> void:
	if _notice_fade:
		_notice_fade.kill()
	notice.text = text
	notice.add_theme_color_override("font_color", color)
	notice.modulate.a = 1.0
	_notice_fade = create_tween()
	_notice_fade.tween_interval(3.0)
	_notice_fade.tween_property(notice, "modulate:a", 0.0, 0.6)
