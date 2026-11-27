extends Node

## Shared player wallet, registered as the `Wallet` autoload.
## Saved per user by the `SaveGame` autoload; a new user starts with a fresh account.

signal changed(balance: int)
## Casino OC token account: tokens are bought with dollars and sold back at a lower rate.
signal tokens_changed(tokens: int)

const START_BALANCE := 1000
const HISTORY_LIMIT := 40
const RENT_AMOUNT := 500
const TOKEN_PRICE := 5
const TOKEN_SELL_PRICE := 4
const WELCOME_BONUS := 100

var balance := START_BALANCE
var history: Array[Dictionary] = []
var rent_paid := false
var tokens := 0
var token_history: Array[Dictionary] = []
var welcome_bonus_claimed := false
## Slots play record that drives the machine's luck (see slots.gd `luck`):
## spins played, losing spins in a row and net tokens won (payouts minus bets).
var slots_spins := 0
var slots_loss_streak := 0
var slots_net := 0

func _ready() -> void:
	reset_state()

## Fresh account, as for a new user.
func reset_state() -> void:
	balance = START_BALANCE
	rent_paid = false
	history.assign([{"title": "Account opened", "amount": START_BALANCE, "time": _now()}])
	tokens = 0
	token_history.clear()
	welcome_bonus_claimed = false
	slots_spins = 0
	slots_loss_streak = 0
	slots_net = 0
	changed.emit(balance)
	tokens_changed.emit(tokens)

func save_state() -> Dictionary:
	return {"balance": balance, "history": history.duplicate(true), "rent_paid": rent_paid,
		"tokens": tokens, "token_history": token_history.duplicate(true),
		"welcome_bonus_claimed": welcome_bonus_claimed, "slots_spins": slots_spins,
		"slots_loss_streak": slots_loss_streak, "slots_net": slots_net}

func load_state(data: Dictionary) -> void:
	balance = int(data.get("balance", START_BALANCE))
	rent_paid = bool(data.get("rent_paid", false))
	history.clear()
	for entry in data.get("history", []):
		if entry is Dictionary:
			history.append(entry)
	tokens = maxi(int(data.get("tokens", 0)), 0)
	welcome_bonus_claimed = bool(data.get("welcome_bonus_claimed", false))
	slots_spins = int(data.get("slots_spins", 0))
	slots_loss_streak = int(data.get("slots_loss_streak", 0))
	slots_net = int(data.get("slots_net", 0))
	token_history.clear()
	for entry in data.get("token_history", []):
		if entry is Dictionary:
			token_history.append(entry)
	changed.emit(balance)
	tokens_changed.emit(tokens)

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

## Buys tokens with dollars from the bank account at TOKEN_PRICE each.
func buy_tokens(count: int) -> bool:
	if count <= 0 or not withdraw(count * TOKEN_PRICE, "Casino OC — %s tokens bought" % group_digits(count)):
		return false
	_apply_tokens(count, "Deposit")
	return true

## Credits the one-time sign-up bonus on the first casino visit; returns true when it was paid now.
func claim_welcome_bonus() -> bool:
	if welcome_bonus_claimed:
		return false
	welcome_bonus_claimed = true
	_apply_tokens(WELCOME_BONUS, "Welcome bonus")
	return true

## Remembers how a slots spin went; a spin that pays less than the bet counts as a loss.
func record_slots_spin(bet: int, payout: int) -> void:
	slots_spins += 1
	slots_net += payout - bet
	slots_loss_streak = slots_loss_streak + 1 if payout < bet else 0

## Sells tokens back to the casino at TOKEN_SELL_PRICE each; dollars go to the bank account.
func sell_tokens(count: int) -> bool:
	if count <= 0 or count > tokens:
		return false
	_apply_tokens(-count, "Withdrawal")
	deposit(count * TOKEN_SELL_PRICE, "Casino OC — %s tokens sold" % group_digits(count))
	return true

func can_bet(amount: int) -> bool:
	return amount > 0 and amount <= tokens

## Takes a bet in tokens; returns false when the token balance is too low.
func bet_tokens(amount: int, title: String) -> bool:
	if not can_bet(amount):
		return false
	_apply_tokens(-amount, title)
	return true

func win_tokens(amount: int, title: String) -> void:
	if amount > 0:
		_apply_tokens(amount, title)

static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = " " + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("−" if value < 0 else "") + digits + grouped

static func format_money(value: int) -> String:
	return ("−" if value < 0 else "") + "$ " + group_digits(absi(value))

static func format_tokens(value: int) -> String:
	return group_digits(value) + (" token" if absi(value) == 1 else " tokens")

func _apply(amount: int, title: String) -> void:
	balance += amount
	history.push_front({"title": title, "amount": amount, "time": _now()})
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)
	changed.emit(balance)

func _apply_tokens(amount: int, title: String) -> void:
	tokens += amount
	token_history.push_front({"title": title, "amount": amount, "time": _now()})
	if token_history.size() > HISTORY_LIMIT:
		token_history.resize(HISTORY_LIMIT)
	tokens_changed.emit(tokens)

func _now() -> String:
	return GameClock.stamp()
