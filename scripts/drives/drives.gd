extends Node

## Used flash drives, registered as the `Drives` autoload.
##
## - DeadDrive.oc sells a fresh batch of used drives every game hour (`listings`). Prices run from
##   $3 to $30; cheap drives are common and expensive ones may not be in stock at all.
## - A bought drive goes to the player's drawer (`owned`) and is plugged in through My Computer.
##   Its files are generated when the drive is listed: a folder tree left by the previous owner,
##   sometimes with a SkamCoin wallet hash hidden somewhere inside.
## - cryptohack.oc takes such a hash (`redeem`) and moves the wallet's dollars into the player's
##   SkamCoin account as SKAM at the current price.
##
## How likely a drive is to hold a wallet and how much is in it depends on its price (TIERS).
## Saved per user by the `SaveGame` autoload.

## Listings, the drawer or redeemed wallets changed; worth saving.
signal changed
## A new batch of drives arrived on DeadDrive.oc.
signal restocked

enum Redeem { OK, BAD_FORMAT, UNKNOWN, EMPTY, USED }

## Price tiers: a drive costing up to `max_price` dollars holds a wallet hash with `chance`;
## the wallet holds between `min` and `max` dollars (log-uniform, so smaller sums are likelier).
const TIERS: Array[Dictionary] = [
	{"max_price": 5, "chance": 0.50, "min": 1000, "max": 3000},
	{"max_price": 9, "chance": 0.58, "min": 2000, "max": 8000},
	{"max_price": 14, "chance": 0.66, "min": 5000, "max": 25000},
	{"max_price": 19, "chance": 0.74, "min": 15000, "max": 80000},
	{"max_price": 24, "chance": 0.82, "min": 50000, "max": 250000},
	{"max_price": 29, "chance": 0.86, "min": 120000, "max": 500000},
	{"max_price": 30, "chance": 0.90, "min": 250000, "max": 1000000},
]
const MIN_PRICE := 3
const MAX_PRICE := 30
## Prices are MIN_PRICE + range * randf()^PRICE_SKEW: the higher the skew, the rarer expensive drives.
const PRICE_SKEW := 2.2
const STOCK_MIN := 6
const STOCK_MAX := 9
## Chance that a drive without a wallet still has an emptied wallet's hash on it.
const DECOY_CHANCE := 0.35
const HASH_LENGTH := 64
## Game seconds between deliveries.
const RESTOCK_SECONDS := 3600

const BRANDS: PackedStringArray = ["FlashMole", "ByteBrick", "Stickr", "Datapig", "NoName USB", "OmniStick", "Thumbly", "KeyChainz"]
const COLORS: Array[Color] = [Color("#3d87e6"), Color("#de5433"), Color("#3da84a"), Color("#f2c230"), Color("#8a5cf6"), Color("#2b2f36"), Color("#d6dbe2"), Color("#ff9926")]
const LABELS: PackedStringArray = ["USB DISK", "NO NAME", "BACKUP", "MY_STUFF", "KINGSTICK", "WORK", "PHOTOS", "TRANSFER", "DONT_TOUCH", "SAVE"]
const SELLERS: PackedStringArray = ["anon_4471", "pawnking", "dumpster_dan", "liquidator_pro", "ghost.seller", "estate_sales_oc", "cheap_bytes", "lost_and_found"]
## Listing notes, from cheap to expensive drives (one list per third of the price range).
const NOTES := [
	["Scratched, works fine.", "Cap missing.", "Found in a taxi.", "Smells a bit like coffee.", "From a box of 200 drives."],
	["From an office clearance.", "Pulled out of a laptop sold for parts.", "Owner moved abroad.", "Never formatted, sold as is."],
	["From a crypto trader's estate.", "Seized at a bankruptcy auction.", "Found in a bank's lost property.", "Previous owner: 'early SkamCoin adopter'."],
]
const OWNERS := ["student", "photographer", "office", "gamer", "trader"]
const WALLET_FILES: PackedStringArray = ["wallet_backup.txt", "skam_seed.txt", "DO_NOT_DELETE.txt", "keys.txt", "recovery.txt", "important!!.txt"]
const DECOY_FILES: PackedStringArray = ["old_wallet.txt", "wallet_2027.txt", "keys_old.txt"]

## Items on DeadDrive.oc. Each: {"id", "price", "sold", "note", "seller", "drive"}.
var listings: Array[Dictionary] = []
## Drives the player bought. Each drive: {"id", "name", "label", "capacity", "color", "plugged",
## "files" (tree), "wallet" ({"hash", "amount"} or empty)}.
var owned: Array[Dictionary] = []
## Wallet hashes already drained through cryptohack.oc.
var redeemed: Dictionary[String, bool] = {}
## Game hour (unix time / RESTOCK_SECONDS) of the current batch.
var stock_hour := -1
var rng := RandomNumberGenerator.new()
var _next_id := 1

func _ready() -> void:
	rng.randomize()
	GameClock.minute_changed.connect(_check_restock)
	reset_state()

func reset_state() -> void:
	owned.clear()
	redeemed.clear()
	_next_id = 1
	restock()

func save_state() -> Dictionary:
	return {"listings": listings.duplicate(true), "owned": owned.duplicate(true), "redeemed": redeemed.duplicate(),
		"stock_hour": stock_hour, "next_id": _next_id}

func load_state(data: Dictionary) -> void:
	owned.clear()
	for entry in data.get("owned", []):
		if entry is Dictionary:
			owned.append(entry)
	redeemed.clear()
	var drained: Variant = data.get("redeemed", {})
	if drained is Dictionary:
		for key in drained:
			redeemed[str(key)] = true
	_next_id = int(data.get("next_id", 1))
	listings.clear()
	for entry in data.get("listings", []):
		if entry is Dictionary:
			listings.append(entry)
	stock_hour = int(data.get("stock_hour", -1))
	_check_restock()
	changed.emit()

# --- Shop --------------------------------------------------------------------

## Replaces the stock with a new batch for the current game hour.
func restock() -> void:
	stock_hour = current_hour()
	listings.clear()
	for i in rng.randi_range(STOCK_MIN, STOCK_MAX):
		var price := MIN_PRICE + roundi((MAX_PRICE - MIN_PRICE) * pow(rng.randf(), PRICE_SKEW))
		listings.append(make_listing(price))
	listings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.price > b.price)
	restocked.emit()
	changed.emit()

func current_hour() -> int:
	return floori(GameClock.unix() / float(RESTOCK_SECONDS))

## Game unix time of the next delivery.
func next_restock() -> int:
	return (current_hour() + 1) * RESTOCK_SECONDS

func _check_restock() -> void:
	if current_hour() != stock_hour:
		restock()

static func tier_for(price: int) -> Dictionary:
	for tier in TIERS:
		if price <= tier.max_price:
			return tier
	return TIERS[-1]

func make_listing(price: int) -> Dictionary:
	var third := clampi(int(float(price - MIN_PRICE) / (MAX_PRICE - MIN_PRICE + 1) * 3.0), 0, 2)
	var notes: Array = NOTES[third]
	var listing := {
		"id": _next_id, "price": price, "sold": false,
		"note": notes[rng.randi() % notes.size()], "seller": SELLERS[rng.randi() % SELLERS.size()],
		"drive": make_drive(price),
	}
	_next_id += 1
	return listing

func find_listing(id: int) -> Dictionary:
	for listing in listings:
		if listing.id == id:
			return listing
	return {}

## Buys a listing with dollars from the bank; the drive goes to the drawer. Returns the drive, or {}.
func buy(id: int) -> Dictionary:
	var listing := find_listing(id)
	if listing.is_empty() or listing.sold or not Wallet.can_afford(listing.price):
		return {}
	Wallet.withdraw(listing.price, "DeadDrive — %s" % listing.drive.name)
	listing.sold = true
	var drive: Dictionary = listing.drive.duplicate(true)
	drive.plugged = false
	owned.append(drive)
	changed.emit()
	return drive

# --- Drives ------------------------------------------------------------------

func find_drive(id: int) -> Dictionary:
	for drive in owned:
		if drive.id == id:
			return drive
	return {}

func plugged() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drive in owned:
		if drive.plugged:
			result.append(drive)
	return result

func set_plugged(id: int, value: bool) -> void:
	var drive := find_drive(id)
	if drive.is_empty() or drive.plugged == value:
		return
	drive.plugged = value
	changed.emit()

## Destroys an owned drive for good, plugged or not. A wallet hash that was only on this drive is
## lost with it (a wallet already drained stays drained). Returns false for an unknown drive.
func destroy(id: int) -> bool:
	var drive := find_drive(id)
	if drive.is_empty():
		return false
	owned.erase(drive)
	changed.emit()
	return true

## Drive letter in My Computer: E: for the first plugged drive, F: for the next...
func letter(id: int) -> String:
	var index := plugged().map(func(drive: Dictionary) -> int: return drive.id).find(id)
	return "%s:" % char("E".unicode_at(0) + maxi(index, 0))

## A drive with a random previous owner's files and, by its price tier, maybe a wallet.
func make_drive(price: int) -> Dictionary:
	var capacity: int = [2, 4, 8, 16, 32, 64, 128][clampi(int(float(price) / MAX_PRICE * 6.0 + rng.randf_range(-1.0, 1.0)), 0, 6)]
	var brand := BRANDS[rng.randi() % BRANDS.size()]
	var owner: String = "trader" if price >= 20 and rng.randf() < 0.5 else OWNERS[rng.randi() % OWNERS.size()]
	var files := _owner_files(owner)
	var tier := tier_for(price)
	var wallet := {}
	if rng.randf() < tier.chance:
		var amount := roundi(exp(rng.randf_range(log(float(tier["min"])), log(float(tier["max"])))) / 10.0) * 10
		wallet = {"hash": _make_hash(), "amount": amount}
		_hide(files, _text_file(WALLET_FILES[rng.randi() % WALLET_FILES.size()], _wallet_text(wallet.hash)))
	elif rng.randf() < DECOY_CHANCE:
		wallet = {"hash": _make_hash(), "amount": 0}
		_hide(files, _text_file(DECOY_FILES[rng.randi() % DECOY_FILES.size()], _wallet_text(wallet.hash)))
	return {
		"id": _next_id, "name": "%s %d GB" % [brand, capacity], "label": LABELS[rng.randi() % LABELS.size()],
		"capacity": capacity, "color": COLORS[rng.randi() % COLORS.size()], "plugged": false,
		"files": files, "wallet": wallet,
	}

## Total size in KB of a folder tree.
static func tree_size(items: Array) -> int:
	var total := 0
	for item: Dictionary in items:
		total += tree_size(item.children) if item.folder else int(item.size)
	return total

func _make_hash() -> String:
	var text := ""
	for i in HASH_LENGTH:
		text += "0123456789abcdef"[rng.randi() % 16]
	return text

func _wallet_text(hash: String) -> String:
	var notes := [
		"SkamCoin wallet backup\n\nRecovery hash:\n%s\n\nDON'T LOSE THIS",
		"skam wallet\n%s\n\nremember: never share it with anyone!!!",
		"Recovery hash for my SKAM wallet:\n%s\n\n(the long-term one, do not touch until 2030)",
		"%s\n\n^ wallet. moved everything here before the crash",
	]
	return notes[rng.randi() % notes.size()] % hash

## Puts [param file] into a random folder of the tree (or the root).
func _hide(items: Array, file: Dictionary) -> void:
	var folders := items.filter(func(item: Dictionary) -> bool: return item.folder)
	if folders.is_empty() or rng.randf() < 0.3:
		items.append(file)
		return
	var folder: Dictionary = folders[rng.randi() % folders.size()]
	_hide(folder.children, file)

func _folder(name: String, children: Array) -> Dictionary:
	return {"name": name, "folder": true, "children": children}

func _file(name: String, size_kb: int) -> Dictionary:
	return {"name": name, "folder": false, "size": size_kb, "text": ""}

func _text_file(name: String, text: String) -> Dictionary:
	return {"name": name, "folder": false, "size": maxi(text.length() / 1024, 1), "text": text}

func _photos(count: int, prefix := "IMG_") -> Array:
	var photos := []
	var number := rng.randi_range(1000, 8000)
	for i in count:
		photos.append(_file("%s%04d.jpg" % [prefix, number + i], rng.randi_range(1800, 5200)))
	return photos

func _pick(options: Array) -> Variant:
	return options[rng.randi() % options.size()]

## Folders and files a previous owner of the given kind would leave behind.
func _owner_files(owner: String) -> Array:
	match owner:
		"student":
			return [
				_folder("Homework", [_file("essay_final_FINAL2.docx", 48), _file("lab_report.pdf", 820), _text_file("notes.txt", _pick(["chapter 4 — read before Monday", "ask prof about the exam date", "group project: nobody answers the chat"]))]),
				_folder("Memes", _photos(rng.randi_range(3, 7), "meme_")),
				_file("schedule.pdf", 120),
			]
		"photographer":
			return [
				_folder("DCIM", [_folder("100PHOTO", _photos(rng.randi_range(5, 12)))]),
				_folder("Clients", [_file("invoice_0412.pdf", 96), _file("wedding_contract.docx", 64)]),
				_text_file("readme.txt", "If found, please return to the studio on Elm Street."),
			]
		"office":
			return [
				_folder("Reports", [_file("Q3_report.xlsx", 340), _file("Q4_report_draft.xlsx", 290), _file("presentation.pptx", 4100)]),
				_text_file("meeting_notes.txt", _pick(["Budget cut by 20%. Nobody is happy.", "Move the deadline again?", "Coffee machine broken. Escalate."])),
				_file("budget.xlsx", 210),
			]
		"gamer":
			return [
				_folder("saves", [_file("slot1.sav", 2300), _file("slot2.sav", 2280), _file("autosave.sav", 2310)]),
				_folder("mods", [_file("better_graphics.zip", 88000), _file("infinite_gold.zip", 1200)]),
				_text_file("keybinds.txt", "jump = space\ncrouch = ctrl\nrage quit = alt+f4"),
				_file("clip_victory.mp4", 64000),
			]
		_:
			return [
				_folder("Charts", _photos(rng.randi_range(2, 5), "chart_")),
				_text_file("trading_journal.txt", _pick(["bought the dip. it kept dipping.", "SKAM to the moon. all in.", "note to self: take profits next time"])),
				_folder("Taxes", [_file("tax_2027.xlsx", 150), _file("receipts.zip", 9400)]),
			]

# --- cryptohack.oc -----------------------------------------------------------

static func is_hash_format(text: String) -> bool:
	var clean := text.strip_edges().to_lower()
	if clean.length() != HASH_LENGTH:
		return false
	for character in clean:
		if not "0123456789abcdef".contains(character):
			return false
	return true

## Wallet {"hash", "amount"} on one of the player's drives with this hash, or {}.
func find_wallet(hash: String) -> Dictionary:
	var clean := hash.strip_edges().to_lower()
	for drive in owned:
		if not drive.wallet.is_empty() and drive.wallet.hash == clean:
			return drive.wallet
	return {}

## What cracking [param hash] would give, without draining it.
func check(hash: String) -> Redeem:
	if not is_hash_format(hash):
		return Redeem.BAD_FORMAT
	var wallet := find_wallet(hash)
	if wallet.is_empty():
		return Redeem.UNKNOWN
	if redeemed.has(wallet.hash):
		return Redeem.USED
	if int(wallet.amount) <= 0:
		return Redeem.EMPTY
	return Redeem.OK

## Drains the wallet into the SkamCoin account. Returns its dollars, or 0 when [method check] fails.
func redeem(hash: String) -> int:
	if check(hash) != Redeem.OK:
		return 0
	var wallet := find_wallet(hash)
	redeemed[wallet.hash] = true
	SkamMarket.receive(int(wallet.amount), "cryptohack.oc")
	changed.emit()
	return int(wallet.amount)
