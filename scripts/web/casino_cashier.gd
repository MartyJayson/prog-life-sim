extends VBoxContainer

## casino.oc/cashier — buys Casino OC tokens with the bank card and sells them back.
## Tokens cost Wallet.TOKEN_PRICE dollars and are bought back at Wallet.TOKEN_SELL_PRICE.

const FEED_ROW = preload("res://scenes/web/casino_feed_row.tscn")
const HISTORY_ROWS := 6
const CASHIER_TITLES := ["Deposit", "Withdrawal", "Welcome bonus"]
const SUCCESS := Color("#1fc86a")
const ERROR := Color("#ff5866")

var tab := "deposit"
var _notice_fade: Tween

@onready var deposit_amount: SpinBox = %DepositAmount
@onready var withdraw_amount: SpinBox = %WithdrawAmount
@onready var notice: Label = %Notice

func _ready() -> void:
	%DepositRate.text = Wallet.format_money(Wallet.TOKEN_PRICE) + " per token"
	%WithdrawRate.text = Wallet.format_money(Wallet.TOKEN_SELL_PRICE) + " per token"
	%BuyRate.text = Wallet.format_money(Wallet.TOKEN_PRICE)
	%SellRate.text = Wallet.format_money(Wallet.TOKEN_SELL_PRICE)
	Wallet.changed.connect(_refresh.unbind(1))
	Wallet.tokens_changed.connect(_refresh.unbind(1))
	_refresh()

func show_tab(name: String) -> void:
	tab = name
	%DepositPane.visible = tab == "deposit"
	%WithdrawPane.visible = tab == "withdraw"
	%DepositTab.theme_type_variation = &"CasinoTabActive" if tab == "deposit" else &"CasinoTab"
	%WithdrawTab.theme_type_variation = &"CasinoTabActive" if tab == "withdraw" else &"CasinoTab"
	notice.text = ""
	_refresh_summary()

func _set_deposit(count: int) -> void:
	deposit_amount.value = count

func _set_withdraw(count: int) -> void:
	withdraw_amount.value = count

func _withdraw_share(share: float) -> void:
	withdraw_amount.value = maxi(floori(Wallet.tokens * share), 1)

func _deposit() -> void:
	_commit_typed(deposit_amount)
	var count := int(deposit_amount.value)
	if Wallet.buy_tokens(count):
		_notify("+%s credited to your casino balance." % Wallet.format_tokens(count), SUCCESS)
	else:
		_notify("Payment declined: not enough money on your card for %s." % Wallet.format_money(count * Wallet.TOKEN_PRICE), ERROR)

func _withdraw() -> void:
	_commit_typed(withdraw_amount)
	var count := int(withdraw_amount.value)
	if Wallet.sell_tokens(count):
		_notify("%s paid out to your card." % Wallet.format_money(count * Wallet.TOKEN_SELL_PRICE), SUCCESS)
	else:
		_notify("You only have %s to withdraw." % Wallet.format_tokens(Wallet.tokens), ERROR)

## Applies an amount the player is still typing; values set by presets are already current.
func _commit_typed(box: SpinBox) -> void:
	if box.get_line_edit().has_focus():
		box.apply()

func _refresh() -> void:
	%Tokens.text = Wallet.group_digits(Wallet.tokens)
	%Value.text = "Cash-out value " + Wallet.format_money(Wallet.tokens * Wallet.TOKEN_SELL_PRICE)
	%CardBalance.text = "Available " + Wallet.format_money(Wallet.balance)
	_refresh_summary()
	var rows: VBoxContainer = %Rows
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for entry: Dictionary in Wallet.token_history:
		if rows.get_child_count() >= HISTORY_ROWS:
			break
		if not entry.get("title", "") in CASHIER_TITLES:
			continue
		var amount: int = entry.get("amount", 0)
		var row: Control = FEED_ROW.instantiate()
		rows.add_child(row)
		row.get_node("Title").text = entry.title
		row.get_node("Time").text = entry.get("time", "").get_slice("  ", 1)
		var amount_label: Label = row.get_node("Amount")
		amount_label.text = ("+" if amount > 0 else "") + Wallet.group_digits(amount)
		amount_label.add_theme_color_override("font_color", SUCCESS if amount > 0 else ERROR)
	%Empty.visible = rows.get_child_count() == 0

func _refresh_summary() -> void:
	var buying := int(deposit_amount.value)
	var cost := buying * Wallet.TOKEN_PRICE
	%DepositGet.text = Wallet.format_tokens(buying)
	%DepositPay.text = Wallet.format_money(cost)
	%Deposit.text = "Deposit " + Wallet.format_money(cost)
	%Deposit.disabled = cost > Wallet.balance
	var selling := int(withdraw_amount.value)
	%WithdrawFee.text = Wallet.format_money(selling * (Wallet.TOKEN_PRICE - Wallet.TOKEN_SELL_PRICE))
	%WithdrawReceive.text = Wallet.format_money(selling * Wallet.TOKEN_SELL_PRICE)
	%Withdraw.text = "Withdraw " + Wallet.format_money(selling * Wallet.TOKEN_SELL_PRICE)
	%Withdraw.disabled = selling > Wallet.tokens

func _notify(text: String, color: Color) -> void:
	if _notice_fade:
		_notice_fade.kill()
	notice.text = text
	notice.add_theme_color_override("font_color", color)
	notice.modulate.a = 1.0
	_notice_fade = create_tween()
	_notice_fade.tween_interval(3.0)
	_notice_fade.tween_property(notice, "modulate:a", 0.0, 0.6)
