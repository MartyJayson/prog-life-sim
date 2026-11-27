extends Node

## SkamCoin (SKAM) market and the player's SKAM wallet, registered as the `SkamMarket` autoload.
##
## The price moves once every real second (GameClock.second_passed), whether skamcoin.oc is
## open or not. Each move of the log price is the sum of:
## - a market mood (bull, bear or sideways) that lasts a few minutes and then switches;
## - momentum: part of the previous move carries on, so runs and dips form;
## - mean reversion towards a slowly wandering "fair value", so the price swings around a level
##   instead of drifting away forever;
## - noise whose size follows GARCH-style volatility clustering: calm stretches and nervous
##   stretches, never one flat speed;
## - rare whale orders: a sudden 1–4 % jolt either way;
## - black swans: every second there is a PUMP_CHANCE chance of a x5 / x10 pump and the same
##   chance of a x5 / x10 crash. A black swan plays out over several seconds and moves the fair
##   value along with it, keeping most of the new level.
##
## Prices are grouped into 30-game-second candles; longer timeframes are built from them.
## Only the last game hour is kept (HISTORY_SECONDS), so memory, saves and per-second
## chart updates stay small however long the game runs.
## Saved per user by the `SaveGame` autoload.

## The price moved (every second).
signal ticked(price: float)
## A black swan started: factor is 5 / 10 for a pump and 0.2 / 0.1 for a crash.
signal black_swan(factor: float)
## Holdings or trade history changed; worth saving.
signal portfolio_changed

const START_PRICE := 101.44
const MIN_PRICE := 0.0001
## Share of every trade the exchange keeps.
const FEE := 0.005
## Chance per second of a pump; a crash has the same chance.
const PUMP_CHANCE := 0.0001
const CRASH_CHANCE := 0.0001
## Of the black swans, this share is x10 (or /10); the rest are x5 (or /5).
const BIG_SWAN_SHARE := 1.0 / 3.0
## Share of a black swan's move that the fair value keeps (the rest retraces).
const SWAN_STICKINESS := 0.85
const WHALE_CHANCE := 0.004
## Base per-second volatility of the log price, and its GARCH(1,1) weights.
const BASE_SIGMA := 0.0016
const GARCH_ALPHA := 0.08
const GARCH_BETA := 0.9
const MOMENTUM := 0.18
const REVERSION := 0.0015
const MOOD_DRIFT := {"bull": 0.00022, "bear": -0.00022, "sideways": 0.0}
## A base candle covers this many game seconds.
const CANDLE_SECONDS := 30
## Price history kept, in game seconds: one game hour. Older candles are dropped.
const HISTORY_SECONDS := 3600
const CANDLE_LIMIT := HISTORY_SECONDS / CANDLE_SECONDS
const TRADE_LIMIT := 40

var price := START_PRICE
## Oldest first. Each: {"t": game unix time of the open, "o", "h", "l", "c", "v"}.
var candles: Array[Dictionary] = []
## SKAM the player owns.
var holdings := 0.0
## Dollars paid for the SKAM still held (shrinks proportionally on every sale).
var cost_basis := 0.0
## Newest first. Each: {"side": "buy"/"sell", "coins", "price", "usd", "time"}.
var trades: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
var _anchor := START_PRICE
var _variance := BASE_SIGMA * BASE_SIGMA
var _last_return := 0.0
var _mood := "sideways"
var _mood_left := 0
## Running black swan: log move still to apply per second and seconds left.
var _swan_step := 0.0
var _swan_left := 0
## Size of the latest black swan (see `black_swan`).
var swan_factor := 1.0

func _ready() -> void:
	rng.randomize()
	GameClock.second_passed.connect(step)
	reset_state()

## A fresh market at START_PRICE with a generated day of history and an empty SKAM wallet.
func reset_state() -> void:
	holdings = 0.0
	cost_basis = 0.0
	trades.clear()
	_anchor = START_PRICE
	_variance = BASE_SIGMA * BASE_SIGMA
	_last_return = 0.0
	_mood_left = 0
	_swan_step = 0.0
	_swan_left = 0
	_generate_history()
	ticked.emit(price)
	portfolio_changed.emit()

func save_state() -> Dictionary:
	var flat := PackedFloat64Array()
	for candle in candles:
		flat.append_array([candle.t, candle.o, candle.h, candle.l, candle.c, candle.v])
	return {
		"price": price, "candles": flat, "holdings": holdings, "cost_basis": cost_basis,
		"trades": trades.duplicate(true), "anchor": _anchor, "variance": _variance,
		"last_return": _last_return, "mood": _mood, "mood_left": _mood_left,
		"swan_step": _swan_step, "swan_left": _swan_left,
	}

func load_state(data: Dictionary) -> void:
	var flat: Variant = data.get("candles", PackedFloat64Array())
	if flat is PackedFloat64Array and flat.size() >= 6:
		candles.clear()
		for i in range(0, flat.size() - 5, 6):
			candles.append({"t": int(flat[i]), "o": flat[i + 1], "h": flat[i + 2], "l": flat[i + 3], "c": flat[i + 4], "v": flat[i + 5]})
		if candles.size() > CANDLE_LIMIT:
			candles = candles.slice(candles.size() - CANDLE_LIMIT)
		price = maxf(float(data.get("price", candles[-1].c)), MIN_PRICE)
	holdings = maxf(float(data.get("holdings", 0.0)), 0.0)
	cost_basis = maxf(float(data.get("cost_basis", 0.0)), 0.0)
	trades.clear()
	for entry in data.get("trades", []):
		if entry is Dictionary:
			trades.append(entry)
	_anchor = maxf(float(data.get("anchor", price)), MIN_PRICE)
	_variance = clampf(float(data.get("variance", _variance)), 0.0, 0.01)
	_last_return = float(data.get("last_return", 0.0))
	_mood = str(data.get("mood", "sideways")) if MOOD_DRIFT.has(data.get("mood")) else "sideways"
	_mood_left = int(data.get("mood_left", 0))
	_swan_step = float(data.get("swan_step", 0.0))
	_swan_left = int(data.get("swan_left", 0))
	swan_factor = exp(_swan_step * _swan_left) if _swan_left > 0 else 1.0
	ticked.emit(price)
	portfolio_changed.emit()

## One second of trading at the current game time.
func step() -> void:
	_move(true)
	_record(GameClock.unix(), _volume())
	ticked.emit(price)

## Starts a black swan by hand (debug and tests): [param factor] 5 or 10 pumps, 0.2 or 0.1 crashes.
func trigger_black_swan(factor: float) -> void:
	_swan_left = rng.randi_range(6, 14)
	_swan_step = log(factor) / _swan_left
	swan_factor = factor
	_anchor *= pow(factor, SWAN_STICKINESS)
	black_swan.emit(factor)

## Moves the price by one second of market action.
func _move(allow_swans: bool) -> void:
	_mood_left -= 1
	if _mood_left <= 0:
		_pick_mood()
	if allow_swans and _swan_left <= 0:
		var roll := rng.randf()
		var big := rng.randf() < BIG_SWAN_SHARE
		if roll < PUMP_CHANCE:
			trigger_black_swan(10.0 if big else 5.0)
		elif roll < PUMP_CHANCE + CRASH_CHANCE:
			trigger_black_swan(0.1 if big else 0.2)
	_anchor *= exp(rng.randfn(0.00001, 0.0004))
	var sigma := sqrt(_variance)
	var move: float = MOOD_DRIFT[_mood] + MOMENTUM * _last_return + REVERSION * log(_anchor / price) + rng.randfn(0.0, sigma)
	if rng.randf() < WHALE_CHANCE:
		move += rng.randf_range(0.01, 0.04) * (1.0 if rng.randf() < 0.5 else -1.0)
	var noise := move
	if _swan_left > 0:
		_swan_left -= 1
		# A black swan is not a straight line: some seconds run harder than others.
		move += _swan_step * rng.randf_range(0.4, 1.6)
	price = maxf(price * exp(move), MIN_PRICE)
	_last_return = clampf(noise, -0.05, 0.05)
	var shock := minf(_last_return * _last_return, 0.0004)
	_variance = BASE_SIGMA * BASE_SIGMA * (1.0 - GARCH_ALPHA - GARCH_BETA) + GARCH_ALPHA * shock + GARCH_BETA * _variance

func _pick_mood() -> void:
	var roll := rng.randf()
	_mood = "bull" if roll < 0.36 else ("bear" if roll < 0.72 else "sideways")
	_mood_left = rng.randi_range(90, 600)

## Trading volume for this second in SKAM; nervous and black-swan seconds trade far more.
func _volume() -> float:
	var nerves := absf(_last_return) / BASE_SIGMA
	var amount := rng.randf_range(20.0, 120.0) * (1.0 + nerves)
	if _swan_left > 0:
		amount *= rng.randf_range(8.0, 20.0)
	return amount * 100.0 / maxf(price, 1.0)

## Adds the current price to the base candle that [param unix_time] falls into.
func _record(unix_time: int, volume: float) -> void:
	var open_time := unix_time - posmod(unix_time, CANDLE_SECONDS)
	if candles.is_empty() or candles[-1].t < open_time:
		var open_price: float = candles[-1].c if not candles.is_empty() else price
		candles.append({"t": open_time, "o": open_price, "h": maxf(open_price, price), "l": minf(open_price, price), "c": price, "v": volume})
		if candles.size() > CANDLE_LIMIT:
			candles = candles.slice(candles.size() - CANDLE_LIMIT)
		return
	var candle: Dictionary = candles[-1]
	candle.h = maxf(candle.h, price)
	candle.l = minf(candle.l, price)
	candle.c = price
	candle.v += volume

## Simulates the game hour before now without black swans, then scales the result so the
## last close is exactly START_PRICE.
func _generate_history() -> void:
	candles.clear()
	price = START_PRICE
	var seconds_per_tick := GameClock.SPEED
	var now := GameClock.unix()
	var first := now - posmod(now, CANDLE_SECONDS) - HISTORY_SECONDS
	var ticks := int(HISTORY_SECONDS / seconds_per_tick)
	for i in ticks:
		_move(false)
		_record(first + int(i * seconds_per_tick), _volume())
	var scale := START_PRICE / price
	for candle in candles:
		for key in ["o", "h", "l", "c"]:
			candle[key] *= scale
		candle.v /= scale
	price = START_PRICE
	_anchor = START_PRICE * exp(rng.randfn(0.0, 0.03))

# --- Statistics --------------------------------------------------------------

## Candles of [param seconds] game seconds each (a multiple of CANDLE_SECONDS: 30, 60, 300...),
## newest last, at most [param count].
func candles_for(seconds: int, count: int) -> Array[Dictionary]:
	var span := maxi(seconds, CANDLE_SECONDS)
	var result: Array[Dictionary] = []
	for i in range(candles.size() - 1, -1, -1):
		var base: Dictionary = candles[i]
		var open_time: int = base.t - posmod(base.t, span)
		if result.is_empty() or result[0].t != open_time:
			if result.size() >= count:
				break
			result.push_front(base.duplicate())
			result[0].t = open_time
		else:
			var candle: Dictionary = result[0]
			candle.o = base.o
			candle.h = maxf(candle.h, base.h)
			candle.l = minf(candle.l, base.l)
			candle.v += base.v
	return result

## Open, high, low and volume over the kept hour: {"open", "high", "low", "volume"}.
func hour_stats() -> Dictionary:
	var stats := {"open": price, "high": price, "low": price, "volume": 0.0}
	if candles.is_empty():
		return stats
	stats.open = candles[0].o
	for candle in candles:
		stats.high = maxf(stats.high, candle.h)
		stats.low = minf(stats.low, candle.l)
		stats.volume += candle.v
	return stats

## Price change over the kept hour, in percent.
func hour_change() -> float:
	var open_price: float = hour_stats().open
	return (price / open_price - 1.0) * 100.0 if open_price > 0.0 else 0.0

func is_swan_running() -> bool:
	return _swan_left > 0

# --- Trading -----------------------------------------------------------------

## SKAM received for [param usd] dollars at the current price, after the fee.
func coins_for(usd: int) -> float:
	return usd * (1.0 - FEE) / price

## Dollars paid out for [param coins] SKAM at the current price, after the fee (rounded down).
func usd_for(coins: float) -> int:
	return floori(coins * price * (1.0 - FEE))

func holdings_value() -> float:
	return holdings * price

## Average price paid per SKAM still held, or 0 when nothing is held.
func average_price() -> float:
	return cost_basis / holdings if holdings > 0.0 else 0.0

## Profit or loss in dollars of the SKAM held, against what was paid for it.
func profit() -> float:
	return holdings_value() - cost_basis

## Buys SKAM for [param usd] dollars from the bank account. Returns the SKAM bought, or 0.
func buy(usd: int) -> float:
	if usd <= 0 or not Wallet.can_afford(usd):
		return 0.0
	var coins := coins_for(usd)
	Wallet.withdraw(usd, "SkamCoin — %s SKAM bought" % format_coins(coins))
	holdings += coins
	cost_basis += usd
	_log_trade("buy", coins, usd)
	return coins

## Sells [param coins] SKAM; dollars go to the bank account. Returns the dollars paid, or 0.
func sell(coins: float) -> int:
	# Selling "all" may differ from holdings by float noise.
	if coins > holdings and coins - holdings < 0.00000001:
		coins = holdings
	if coins <= 0.0 or coins > holdings:
		return 0
	var usd := usd_for(coins)
	if usd < 1:
		return 0
	cost_basis -= cost_basis * coins / holdings
	holdings -= coins
	if holdings < 0.00000001:
		holdings = 0.0
		cost_basis = 0.0
	Wallet.deposit(usd, "SkamCoin — %s SKAM sold" % format_coins(coins))
	_log_trade("sell", coins, usd)
	return usd

func _log_trade(side: String, coins: float, usd: int) -> void:
	trades.push_front({"side": side, "coins": coins, "price": price, "usd": usd, "time": GameClock.stamp()})
	if trades.size() > TRADE_LIMIT:
		trades.resize(TRADE_LIMIT)
	portfolio_changed.emit()

# --- Formatting --------------------------------------------------------------

## "$ 1 234.56", with more decimals for cheap prices.
static func format_price(value: float) -> String:
	var decimals := 2 if absf(value) >= 1.0 else (4 if absf(value) >= 0.01 else 6)
	return "$ " + format_number(value, decimals)

static func format_coins(value: float) -> String:
	return format_number(value, 4)

## Groups thousands with spaces and keeps [param decimals] digits after the point.
static func format_number(value: float, decimals: int) -> String:
	var text := String.num(absf(value), decimals)
	if decimals > 0 and not text.contains("."):
		text += "." + "0".repeat(decimals)
	elif decimals > 0:
		text += "0".repeat(decimals - text.get_slice(".", 1).length())
	var whole := text.get_slice(".", 0)
	var grouped := ""
	while whole.length() > 3:
		grouped = " " + whole.right(3) + grouped
		whole = whole.left(whole.length() - 3)
	var result := whole + grouped + ("." + text.get_slice(".", 1) if decimals > 0 else "")
	return ("−" if value < 0.0 and absf(value) >= 0.5 * pow(10.0, -decimals) else "") + result

## "12.3K", "4.56M" for big volumes.
static func format_compact(value: float) -> String:
	if value >= 1e9:
		return String.num(value / 1e9, 2) + "B"
	if value >= 1e6:
		return String.num(value / 1e6, 2) + "M"
	if value >= 1e3:
		return String.num(value / 1e3, 1) + "K"
	return String.num(value, 0)
