extends VBoxContainer

## stupidjob.oc — job board. Shows every `JobListing` as a card; the search field filters them.

const CARD = preload("res://scenes/web/work_job_card.tscn")

@export var listings: Array[JobListing] = []

@onready var cards: VBoxContainer = %Listings
@onready var query: LineEdit = %Query

func _ready() -> void:
	for listing in listings:
		var card: Control = CARD.instantiate()
		cards.add_child(card)
		card.show_listing(listing)
	_filter()

func _filter(_text := "") -> void:
	var needle := query.text.strip_edges()
	var shown := 0
	for card in cards.get_children():
		var listing: JobListing = card.listing
		var haystack := " ".join([listing.title, listing.company, listing.location, listing.summary, " ".join(listing.tags)])
		card.visible = needle.is_empty() or haystack.containsn(needle)
		if card.visible:
			shown += 1
	%Count.text = "%d job%s found" % [shown, "" if shown == 1 else "s"]
	%Empty.visible = shown == 0
	%Empty.text = "No jobs match “%s”. Try a different keyword." % needle
