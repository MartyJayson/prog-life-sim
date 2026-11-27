extends VBoxContainer

## casino.oc/blackjack — classic 21 against the dealer, played with Casino OC tokens.

const Lights = preload("res://scripts/web/marquee_lights.gd")
const CARD = preload("res://scenes/web/playing_card.tscn")
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["♠", "♥", "♦", "♣"]

var deck: Array[int] = []
var player: Array[int] = []
var dealer: Array[int] = []
var stake := 0
var _leaving := false
var _dealer_concealed := false
var _effects: Array[Tween] = []

@onready var table_lights: Control = %TableLights
@onready var flash: ColorRect = %Flash
@onready var coins: CPUParticles2D = %Coins
@onready var banner: Label = %Banner

func _ready() -> void:
	Wallet.tokens_changed.connect(_balance_changed)
	_balance_changed(Wallet.tokens)
	_render()

func _balance_changed(balance: int) -> void:
	%Balance.text = "Balance: " + Wallet.format_tokens(balance)

static func score(hand: Array[int]) -> int:
	var total := 0
	var ace := false
	for card in hand:
		var rank := card % 13 + 1
		total += mini(rank, 10)
		ace = ace or rank == 1
	if ace and total <= 11:
		total += 10
	return total

func _deal() -> void:
	if stake > 0:
		return
	%Bet.apply()
	var amount := int(%Bet.value)
	if not Wallet.bet_tokens(amount, "Blackjack — bet"):
		%Status.text = "Not enough tokens for this bet. Top up at the Cashier."
		return
	stake = amount
	_clear_effects()
	for row: Container in [%Player, %Dealer]:
		for previous in row.get_children():
			row.remove_child(previous)
			previous.queue_free()
	deck.assign(range(52))
	deck.shuffle()
	player.assign([deck.pop_back(), deck.pop_back()])
	dealer.assign([deck.pop_back(), deck.pop_back()])
	if score(player) == 21 or score(dealer) == 21:
		_settle()
	else:
		%Status.text = "Your move. Hit or stand?"
	_render()

func _hit() -> void:
	if stake == 0:
		return
	player.append(deck.pop_back())
	if score(player) >= 21:
		_stand()
	else:
		_render()

func _stand() -> void:
	if stake == 0:
		return
	_finish_dealer_turn()
	_render()

func _finish_dealer_turn() -> void:
	if score(player) <= 21:
		while score(dealer) < 17:
			dealer.append(deck.pop_back())
	_settle()

func _settle() -> void:
	var bet := stake
	stake = 0
	var yours := score(player)
	var theirs := score(dealer)
	if yours > 21 or (theirs <= 21 and theirs > yours):
		%Status.text = "Dealer wins. You lost " + Wallet.format_tokens(bet)
		_announce("BUST!" if yours > 21 else "DEALER WINS", Color("#ff6b78"), false)
	elif yours == theirs:
		Wallet.win_tokens(bet, "Blackjack — bet refund")
		%Status.text = "Push. Your bet is returned."
		_announce("PUSH", Color("#d9c8f5"), false)
	else:
		Wallet.win_tokens(bet * 2, "Blackjack — win")
		%Status.text = "You win! Payout " + Wallet.format_tokens(bet * 2)
		var natural := yours == 21 and player.size() == 2
		_announce("BLACKJACK!" if natural else ("DEALER BUSTS!" if theirs > 21 else "YOU WIN!"), Color("#ffd23f"), true)

func _render() -> void:
	var playing := stake > 0
	%Deal.disabled = playing
	%Bet.editable = not playing
	%Hit.disabled = not playing
	%Stand.disabled = not playing
	_show_hand(%Player, player, false)
	_show_hand(%Dealer, dealer, playing)
	_dealer_concealed = playing
	if not player.is_empty():
		%PlayerTitle.text = "You · %d" % score(player)
		%DealerTitle.text = "Dealer" if playing else "Dealer · %d" % score(dealer)

func _show_hand(row: Container, hand: Array[int], conceal: bool) -> void:
	var shown := row.get_child_count()
	var revealing := row == %Dealer and _dealer_concealed and not conceal
	for previous in row.get_children():
		row.remove_child(previous)
		previous.queue_free()
	for i in hand.size():
		var card := CARD.instantiate()
		row.add_child(card)
		var suit := floori(hand[i] / 13.0)
		if conceal and i == 1:
			card.show_back()
		else:
			card.show_face(RANKS[hand[i] % 13], SUITS[suit], suit in [1, 2])
		if i >= shown:
			card.deal_in((i - shown) * 0.14 + (0.07 if row == %Dealer else 0.0))
		elif revealing and i == 1:
			card.flip_in()

func _set_bet(amount: int) -> void:
	if stake == 0:
		%Bet.value = clampi(amount, int(%Bet.min_value), int(%Bet.max_value))

func _bet_max() -> void:
	_set_bet(mini(Wallet.tokens, int(%Bet.max_value)))

func _announce(text: String, color: Color, win: bool) -> void:
	if _leaving:
		return
	_clear_effects()
	%Status.add_theme_color_override("font_color", color)
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.show()
	banner.modulate = Color.WHITE
	banner.reset_size()
	banner.pivot_offset = banner.get_combined_minimum_size() * 0.5
	banner.scale = Vector2.ONE * 0.3
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(1.4)
	pop.tween_property(banner, "modulate:a", 0.0, 0.4)
	pop.tween_callback(banner.hide)
	_effects.append(pop)
	if win:
		table_lights.mode = Lights.Mode.BLINK
		coins.position = coins.get_parent().size * Vector2(0.5, 0.7)
		coins.restart()
		var glow := create_tween()
		glow.tween_property(flash, "modulate:a", 0.35, 0.07)
		glow.tween_property(flash, "modulate:a", 0.0, 0.35)
		glow.tween_interval(1.6)
		glow.tween_callback(func(): table_lights.mode = Lights.Mode.IDLE)
		_effects.append(glow)

func _clear_effects() -> void:
	for tween in _effects:
		tween.kill()
	_effects.clear()
	banner.hide()
	flash.modulate.a = 0.0
	table_lights.mode = Lights.Mode.IDLE
	%Status.remove_theme_color_override("font_color")

func _exit_tree() -> void:
	_leaving = true
	if stake > 0:
		# Leaving the table counts as standing.
		_finish_dealer_turn()
