extends VBoxContainer

## casino.oc — the Casino OC lobby: promo banner, game catalogue, a live feed of other
## players' wins and the player's own recent bets (all in tokens).

const Slots = preload("res://scripts/web/slots.gd")
const FEED_ROW = preload("res://scenes/web/casino_feed_row.tscn")
const LIVE_ROW = preload("res://scenes/web/casino_live_row.tscn")
const FEED_ROWS := 6
const LIVE_ROWS := 7
const GAME_PREFIXES := ["Slots OS", "Blackjack"]
const WIN := Color("#1fc86a")
const LOSS := Color("#e8414f")
const PLAYERS := ["lucky_otter", "N1ghtOwl", "mx_volkov", "spinqueen", "dr4ke", "KittyCash",
	"ace_of_bytes", "Gr1mBot", "moonwalker7", "tilt_master", "zara.k", "BigSal", "pixelpete",
	"h0dler", "neon_fox", "Ms_Fortune", "bob_the_dealer", "quietstorm", "vex", "jackpotjoe"]

var _rng := RandomNumberGenerator.new()
var _feed_filled := false

@onready var max_win: Label = %MaxWin
@onready var feed: VBoxContainer = %Feed
@onready var feed_empty: Label = %FeedEmpty
@onready var live_feed: VBoxContainer = %LiveFeed

func _ready() -> void:
	_rng.randomize()
	var top_win: int = Slots.BETS.max() * Slots.PAYOUTS["$"] * Slots.LINES.size()
	max_win.text = Wallet.group_digits(top_win)
	%Note.text = "≈ " + Wallet.format_money(top_win * Wallet.TOKEN_SELL_PRICE) + " at cash-out"
	%Rate.text = "1 token = %s  ·  cash out at %s per token" % [
		Wallet.format_money(Wallet.TOKEN_PRICE), Wallet.format_money(Wallet.TOKEN_SELL_PRICE)]
	Wallet.tokens_changed.connect(_refresh_feed.unbind(1))
	_refresh_feed()
	for i in LIVE_ROWS:
		_add_live_win()
	_feed_filled = true
	var pulse := create_tween().set_loops()
	pulse.tween_property(max_win, "modulate", Color(1.3, 1.2, 0.85), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(max_win, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
	var blink := create_tween().set_loops()
	blink.tween_property(%Dot, "modulate:a", 0.25, 0.6)
	blink.tween_property(%Dot, "modulate:a", 1.0, 0.6)

## Adds one made-up win by another player at the top of the live feed.
func _add_live_win() -> void:
	var slots := _rng.randf() < 0.65
	var bet: int = Slots.BETS[_rng.randi_range(0, Slots.BETS.size() - 1)] if slots else _rng.randi_range(1, 60) * 5
	var multiplier := 2.0
	if slots:
		multiplier = [2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 16.0, 24.0, 50.0][mini(floori(pow(_rng.randf(), 2.2) * 9), 8)]
	var row: Control = LIVE_ROW.instantiate()
	row.get_node("Game").text = "Slots OS" if slots else "Blackjack"
	row.get_node("Player").text = PLAYERS[_rng.randi_range(0, PLAYERS.size() - 1)]
	row.get_node("Multiplier").text = "×%s" % String.num(multiplier, 0)
	row.get_node("Payout").text = Wallet.group_digits(roundi(bet * multiplier))
	live_feed.add_child(row)
	live_feed.move_child(row, 0)
	while live_feed.get_child_count() > LIVE_ROWS:
		var oldest := live_feed.get_child(live_feed.get_child_count() - 1)
		live_feed.remove_child(oldest)
		oldest.queue_free()
	%Online.text = "%s playing" % Wallet.group_digits(_rng.randi_range(1180, 1460))
	if _feed_filled:
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.35)

func _refresh_feed() -> void:
	for row in feed.get_children():
		feed.remove_child(row)
		row.queue_free()
	for entry: Dictionary in Wallet.token_history:
		if feed.get_child_count() >= FEED_ROWS:
			break
		var title: String = entry.get("title", "")
		if not GAME_PREFIXES.any(func(prefix: String) -> bool: return title.begins_with(prefix)):
			continue
		var amount: int = entry.get("amount", 0)
		var row: Control = FEED_ROW.instantiate()
		feed.add_child(row)
		row.get_node("Title").text = title
		row.get_node("Time").text = entry.get("time", "").get_slice("  ", 1)
		var amount_label: Label = row.get_node("Amount")
		amount_label.text = ("+" if amount > 0 else "") + Wallet.group_digits(amount)
		amount_label.add_theme_color_override("font_color", WIN if amount > 0 else LOSS)
	feed_empty.visible = feed.get_child_count() == 0
