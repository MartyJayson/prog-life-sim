extends PanelContainer

## One used flash drive for sale on DeadDrive.oc.

signal buy_requested(id: int)

var listing_id := -1

func show_listing(listing: Dictionary, affordable: bool) -> void:
	listing_id = listing.id
	var drive: Dictionary = listing.drive
	%Picture.self_modulate = drive.color
	%Name.text = drive.name
	%Note.text = "“%s”" % listing.note
	%Seller.text = "seller: %s" % listing.seller
	%Price.text = "$%d" % listing.price
	%Stamp.visible = listing.sold
	%Buy.text = "Sold" if listing.sold else "Buy"
	%Buy.disabled = listing.sold or not affordable
	%Buy.tooltip_text = "" if listing.sold or affordable else "Not enough money in your OS Bank account."
	modulate.a = 0.55 if listing.sold else 1.0

func _buy() -> void:
	buy_requested.emit(listing_id)
