extends VBoxContainer

## casino.oc — the Casino OC lobby: hero banner, game catalogue and the player's recent games.

const Slots = preload("res://scripts/web/slots.gd")
const FEED_ROW = preload("res://scenes/web/casino_feed_row.tscn")
const FEED_ROWS := 6
const GAME_PREFIXES := ["Slots OS", "Blackjack"]
const WIN := Color("#4be38a")
const LOSS := Color("#ff6b78")

@onready var max_win: Label = %MaxWin
@onready var feed: VBoxContainer = %Feed
@onready var feed_empty: Label = %FeedEmpty

func _ready() -> void:
	var top_bet: int = Slots.BETS.max()
	max_win.text = Wallet.format_money(top_bet * Slots.PAYOUTS["$"] * Slots.LINES.size())
	Wallet.changed.connect(_refresh_feed.unbind(1))
	_refresh_feed()
	var pulse := create_tween().set_loops()
	pulse.tween_property(max_win, "modulate", Color(1.25, 1.15, 0.8), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(max_win, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)

func _refresh_feed() -> void:
	for row in feed.get_children():
		feed.remove_child(row)
		row.queue_free()
	for entry: Dictionary in Wallet.history:
		if feed.get_child_count() >= FEED_ROWS:
			break
		var title: String = entry.get("title", "")
		if not GAME_PREFIXES.any(func(prefix: String) -> bool: return title.begins_with(prefix)):
			continue
		var amount: int = entry.get("amount", 0)
		var row: Control = FEED_ROW.instantiate()
		feed.add_child(row)
		row.get_node("Title").text = title
		row.get_node("Time").text = entry.get("time", "")
		var amount_label: Label = row.get_node("Amount")
		amount_label.text = ("+ " if amount > 0 else "") + Wallet.format_money(amount)
		amount_label.add_theme_color_override("font_color", WIN if amount > 0 else LOSS)
	feed_empty.visible = feed.get_child_count() == 0
