extends Node

## Shared player wallet, registered as the `Wallet` autoload.
## Lives only in memory: every game launch starts with a fresh account and empty history.

signal changed(balance: int)

const GAME_CLOCK = preload("res://scripts/game_clock.gd")
const START_BALANCE := 1000
const HISTORY_LIMIT := 40
const RENT_AMOUNT := 500

var balance := START_BALANCE
var history: Array[Dictionary] = []
var rent_paid := false

func _ready() -> void:
	history.assign([{"title": "Account opened", "amount": START_BALANCE, "time": _now()}])

func can_afford(amount: int) -> bool:
	return amount > 0 and amount <= balance

func withdraw(amount: int, title: String) -> bool:
	if not can_afford(amount):
		return false
	_apply(-amount, title)
	return true

func deposit(amount: int, title: String) -> void:
	if amount > 0:
		_apply(amount, title)

func pay_rent() -> bool:
	if rent_paid or not can_afford(RENT_AMOUNT):
		return false
	rent_paid = true
	_apply(-RENT_AMOUNT, "Rent payment")
	return true

static func format_money(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = " " + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("−" if value < 0 else "") + "$ " + digits + grouped

func _apply(amount: int, title: String) -> void:
	balance += amount
	history.push_front({"title": title, "amount": amount, "time": _now()})
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)
	changed.emit(balance)

func _now() -> String:
	var time := Time.get_time_dict_from_system()
	return "%s  %02d:%02d" % [GAME_CLOCK.DATE, time.hour, time.minute]
