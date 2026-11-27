extends VBoxContainer

## DeadDrive.oc — sells the current hour's batch of used flash drives from the `Drives` autoload.

const CARD = preload("res://scenes/web/deaddrive_card.tscn")
const SUCCESS := Color("#1f7a3a")
const ERROR := Color("#c8362b")

var _notice_fade: Tween

@onready var listings: GridContainer = %Listings
@onready var notice: Label = %Notice

func _ready() -> void:
	Drives.changed.connect(_refresh)
	Wallet.changed.connect(_refresh.unbind(1))
	GameClock.minute_changed.connect(_refresh_delivery)
	_refresh()

func _refresh() -> void:
	%Balance.text = "Your bank: " + Wallet.format_money(Wallet.balance)
	for card in listings.get_children():
		listings.remove_child(card)
		card.queue_free()
	for listing in Drives.listings:
		var card: Control = CARD.instantiate()
		listings.add_child(card)
		card.show_listing(listing, Wallet.can_afford(listing.price))
		card.buy_requested.connect(_buy)
	%Empty.visible = Drives.listings.all(func(listing: Dictionary) -> bool: return listing.sold)
	_refresh_delivery()

func _refresh_delivery() -> void:
	var left := Drives.listings.filter(func(listing: Dictionary) -> bool: return not listing.sold).size()
	%Delivery.text = "%d drives in stock  ·  fresh batch every hour  ·  next delivery at %s" % [left, GameClock.format_time(Drives.next_restock())]

func _buy(id: int) -> void:
	var drive := Drives.buy(id)
	if drive.is_empty():
		_notify("Payment declined: not enough money in your OS Bank account.", ERROR)
	else:
		_notify("%s is yours. It is in your drawer: plug it in from My Computer." % drive.name, SUCCESS)

func _notify(text: String, color: Color) -> void:
	if _notice_fade:
		_notice_fade.kill()
	notice.text = text
	notice.add_theme_color_override("font_color", color)
	notice.modulate.a = 1.0
	_notice_fade = create_tween()
	_notice_fade.tween_interval(4.0)
	_notice_fade.tween_property(notice, "modulate:a", 0.0, 0.6)
