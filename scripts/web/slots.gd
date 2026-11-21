extends VBoxContainer

## casino.oc/slots — a 3×3 slot machine paid from the shared Wallet.
## Every row, column and diagonal is a payline and each paying line is counted separately:
##   three equal symbols pay bet × PAYOUTS, 💩 pays nothing and only blocks lines;
##   two $ on one line pay bet × 2; a $ anywhere without such a line returns the bet once.
## Reels spin until the player stops them one column at a time, left to right, with the
## main button (or the auto-stop kicks in).

const POOP := "💩"
const PAYOUTS := {"10": 3, "J": 4, "Q": 8, "K": 10, "$": 50}
const DOLLAR_PAIR := 2
const DOLLAR_REFUND := 1
const BETS := [10, 25, 50, 100, 250, 500]
# Reel strips tuned for ~94.9% return to player (exact enumeration of all 32 768 stops).
const REELS := [
	["$", "💩", "J", "💩", "J", "10", "J", "Q", "Q", "K", "J", "J", "💩", "10", "J", "💩",
		"10", "J", "J", "K", "10", "Q", "J", "💩", "J", "10", "J", "10", "10", "Q", "💩", "10"],
	["Q", "K", "💩", "J", "10", "💩", "💩", "Q", "J", "K", "Q", "10", "K", "Q", "K", "Q",
		"J", "💩", "Q", "Q", "10", "K", "K", "J", "Q", "💩", "K", "Q", "K", "$", "💩", "Q"],
	["10", "10", "10", "K", "J", "10", "10", "$", "10", "J", "K", "💩", "💩", "10", "J", "Q",
		"💩", "Q", "J", "10", "💩", "K", "💩", "J", "10", "Q", "10", "Q", "J", "10", "J", "💩"]
]
# Cells are Vector2i(column, row).
const LINES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
	[Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0)]
]
const AUTO_STOP_DELAY := 6.0
const AUTO_STOP_STEP := 0.45
const Reel = preload("res://scripts/web/slot_reel.gd")
const Overlay = preload("res://scripts/web/slot_overlay.gd")

var bet_index := 0
var spinning := false
var pending_win := 0
var _stops: Array[int] = []
var _wins: Array[Dictionary] = []
var _bet := 0
var _effects: Array[Tween] = []

@onready var reels: Array[Control] = [%Reel0, %Reel1, %Reel2]
@onready var board: Control = %Board
@onready var overlay: Overlay = %Overlay
@onready var flash: ColorRect = %Flash
@onready var coins: CPUParticles2D = %Coins
@onready var banner: Label = %Banner
@onready var win_label: Label = %WinLabel
@onready var breakdown: Label = %Breakdown
@onready var message: Label = %Message
@onready var bet_label: Label = %Bet
@onready var spin_button: Button = %Spin
@onready var less_button: Button = %Less
@onready var more_button: Button = %More
@onready var auto_stop: Timer = %AutoStop

func _ready() -> void:
	for column in reels.size():
		reels[column].setup(REELS[column], randi() % REELS[column].size())
		reels[column].stopped.connect(_on_reel_stopped)
	overlay.reels = reels
	_refresh_controls()

func _exit_tree() -> void:
	# Leaving the page mid-spin must not swallow a win that was already decided.
	if pending_win > 0:
		Wallet.deposit(pending_win, "Slots OS — win")
		pending_win = 0

static func build_grid(stops: Array) -> Array:
	var grid := []
	for row in 3:
		var line := []
		for column in 3:
			var strip: Array = REELS[column]
			line.append(strip[(stops[column] + row) % strip.size()])
		grid.append(line)
	return grid

static func evaluate(grid: Array, bet: int) -> Array[Dictionary]:
	var wins: Array[Dictionary] = []
	var dollar_line := false
	for index in LINES.size():
		var cells: Array = LINES[index]
		var symbols := []
		for cell: Vector2i in cells:
			symbols.append(grid[cell.y][cell.x])
		var first: String = symbols[0]
		if first != POOP and symbols.count(first) == 3:
			wins.append(_win("%s-%s-%s" % [first, first, first], first, PAYOUTS[first], bet, index, cells))
			dollar_line = dollar_line or first == "$"
		elif symbols.count("$") == 2:
			var pair := []
			for i in 3:
				if symbols[i] == "$":
					pair.append(cells[i])
			wins.append(_win("$-$", "$", DOLLAR_PAIR, bet, index, pair))
			dollar_line = true
	if not dollar_line:
		var dollars := []
		for row in 3:
			for column in 3:
				if grid[row][column] == "$":
					dollars.append(Vector2i(column, row))
		if not dollars.is_empty():
			wins.append(_win("$", "$", DOLLAR_REFUND, bet, -1, dollars))
	return wins

static func _win(combo: String, symbol: String, multiplier: int, bet: int, line: int, cells: Array) -> Dictionary:
	return {"combo": combo, "symbol": symbol, "multiplier": multiplier, "payout": bet * multiplier, "line": line, "cells": cells}

static func total_payout(wins: Array[Dictionary]) -> int:
	var total := 0
	for win in wins:
		total += win.payout
	return total

func _change_bet(delta: int) -> void:
	bet_index = clampi(bet_index + delta, 0, BETS.size() - 1)
	_refresh_controls()

## The big button starts a spin, and while the reels run it stops the next one from the left.
func _spin() -> void:
	if spinning:
		stop_next()
		return
	var bet: int = BETS[bet_index]
	if not Wallet.withdraw(bet, "Slots OS — bet"):
		_notify("Insufficient funds. Lower your bet." if Wallet.balance >= BETS[0] else "Your account is empty — visit OS Bank.")
		return
	_clear_result()
	_bet = bet
	_stops.clear()
	for strip: Array in REELS:
		_stops.append(randi() % strip.size())
	_wins = evaluate(build_grid(_stops), bet)
	pending_win = total_payout(_wins)
	spinning = true
	overlay.mode = Overlay.Mode.SPIN
	win_label.text = "Stop the reels!"
	for reel in reels:
		reel.start_spin()
	auto_stop.start(AUTO_STOP_DELAY)
	_refresh_controls()

func stop_reel(column: int) -> void:
	if spinning and reels[column].stop_at(_stops[column]):
		_refresh_controls()

func stop_next() -> void:
	for column in reels.size():
		if reels[column].spinning and not reels[column].stopping:
			stop_reel(column)
			return

func _on_auto_stop() -> void:
	stop_next()
	for reel in reels:
		if reel.spinning and not reel.stopping:
			auto_stop.start(AUTO_STOP_STEP)
			return

func _on_reel_stopped() -> void:
	_refresh_controls()
	if not spinning:
		return
	for reel in reels:
		if reel.spinning:
			return
	auto_stop.stop()
	_show_result(_wins, _bet)

func _show_result(wins: Array[Dictionary], bet: int) -> void:
	var total := total_payout(wins)
	Wallet.deposit(total, "Slots OS — win" if total > bet else "Slots OS — bet refund")
	pending_win = 0
	spinning = false
	_refresh_controls()
	if wins.is_empty():
		overlay.clear()
		win_label.text = "No match"
		win_label.modulate = Color(1, 1, 1, 0.55)
		return
	win_label.modulate = Color.WHITE
	var lines: Array[Dictionary] = []
	var combo_counts := {}
	var combo_multipliers := {}
	for win in wins:
		for cell: Vector2i in win.cells:
			reels[cell.x].highlight.append(cell.y)
		if win.line >= 0:
			lines.append({"cells": LINES[win.line], "color": Reel.COLORS[win.symbol]})
		combo_counts[win.combo] = combo_counts.get(win.combo, 0) + 1
		combo_multipliers[win.combo] = win.multiplier
	var parts := PackedStringArray()
	for combo: String in combo_counts:
		var count: int = combo_counts[combo]
		var multiplier: int = combo_multipliers[combo]
		var part := "%s ×%d" % [combo, multiplier] if combo != "$" else "$ — bet refund"
		if count > 1:
			part += " × %d %s" % [count, "lines"]
		parts.append(part + " = " + Wallet.format_money(bet * multiplier * count))
	breakdown.text = "   ·   ".join(parts)
	overlay.show_lines(lines)
	var refund_only := total <= bet
	var counter := create_tween()
	counter.tween_method(_show_win_amount.bind(refund_only), 0.0, float(total), clampf(0.45 + total / float(bet) * 0.04, 0.45, 2.2))
	_effects.append(counter)
	_celebrate(total, bet, combo_counts.has("$-$-$"))

func _celebrate(total: int, bet: int, jackpot: bool) -> void:
	coins.position = board.size * Vector2(0.5, 0.6)
	if total <= bet:
		coins.amount = 14
		coins.restart()
		return
	var tier := 2 if jackpot else (1 if total >= bet * 8 else 0)
	coins.amount = [36, 90, 180][tier]
	coins.restart()
	if tier == 0:
		return  # small wins keep the board readable: no banner over the winning line
	banner.text = ["WIN!", "BIG\nWIN!", "JACKPOT!"][tier]
	banner.show()
	banner.modulate = Color.WHITE
	banner.reset_size()
	banner.pivot_offset = banner.get_combined_minimum_size() * 0.5
	banner.scale = Vector2.ONE * 0.2
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(1.1 + tier * 0.5)
	pop.tween_property(banner, "modulate:a", 0.0, 0.4)
	pop.tween_callback(banner.hide)
	_effects.append(pop)
	if tier > 0:
		var glow := create_tween()
		for i in (4 if jackpot else 1):
			glow.tween_property(flash, "modulate:a", 0.7 if jackpot else 0.4, 0.07)
			glow.tween_property(flash, "modulate:a", 0.0, 0.3)
		_effects.append(glow)

func _clear_result() -> void:
	for tween in _effects:
		tween.kill()
	_effects.clear()
	banner.hide()
	flash.modulate.a = 0.0
	breakdown.text = ""
	message.text = ""
	win_label.modulate = Color.WHITE
	overlay.clear()
	for reel in reels:
		reel.highlight.clear()
		reel.queue_redraw()

func _show_win_amount(value: float, refund: bool) -> void:
	win_label.text = ("REFUND: " if refund else "WIN: ") + Wallet.format_money(roundi(value))

func _refresh_controls() -> void:
	bet_label.text = Wallet.format_money(BETS[bet_index])
	less_button.disabled = spinning or bet_index == 0
	more_button.disabled = spinning or bet_index == BETS.size() - 1
	var waiting := false
	for reel in reels:
		waiting = waiting or (spinning and reel.spinning and not reel.stopping)
	spin_button.disabled = spinning and not waiting
	spin_button.text = "STOP" if waiting else ("· · ·" if spinning else "SPIN")

func _notify(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(2.2)
	fade.tween_property(message, "modulate:a", 0.0, 0.5)
