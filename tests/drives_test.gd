extends SceneTree

# Run with: godot --headless --path . --script res://tests/drives_test.gd
# Pass `-- --screenshot` to also save res://.godot/deaddrive.png, my_computer.png and cryptohack.png
# (needs a window, not --headless).
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	if condition:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)

func shot(file_name: String) -> void:
	if not "--screenshot" in OS.get_cmdline_user_args():
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/%s.png" % file_name)

## The file tree items with text, flattened.
func text_files(items: Array) -> Array:
	var found := []
	for item: Dictionary in items:
		if item.folder:
			found.append_array(text_files(item.children))
		elif not item.text.is_empty():
			found.append(item)
	return found

## Folder names leading to the file that contains [param needle], or null.
func path_to(items: Array, needle: String, trail: Array = []) -> Variant:
	for item: Dictionary in items:
		if item.folder:
			var deeper: Variant = path_to(item.children, needle, trail + [item.name])
			if deeper != null:
				return deeper
		elif item.text.contains(needle):
			return trail
	return null

func run() -> void:
	load("res://scripts/apps/browser.gd").instant_loading = true
	load("res://scripts/web/cryptohack.gd").crack_time = 0.0
	var clock: Node = root.get_node("GameClock")
	var drives: Node = root.get_node("Drives")
	var wallet: Node = root.get_node("Wallet")
	var market: Node = root.get_node("SkamMarket")
	clock.running = false
	clock.reset_state()
	wallet.reset_state()
	market.reset_state()
	drives.reset_state()

	# Odds by price tier.
	check(drives.tier_for(3).chance == 0.5 and drives.tier_for(30).chance == 0.9, "a $3 drive has a 50% wallet chance and a $30 drive 90%")
	check(drives.tier_for(3)["max"] < drives.tier_for(30)["min"], "expensive drives hold bigger wallets")
	for price in [3, 12, 30]:
		var tier: Dictionary = drives.tier_for(price)
		var wallets := 0
		var low := INF
		var high := 0.0
		for i in 2000:
			var drive: Dictionary = drives.make_drive(price)
			if int(drive.wallet.get("amount", 0)) > 0:
				wallets += 1
				low = minf(low, drive.wallet.amount)
				high = maxf(high, drive.wallet.amount)
		var rate := wallets / 2000.0
		print("$%d: wallet in %.1f%% of drives, $%d..$%d" % [price, rate * 100.0, low, high])
		check(absf(rate - tier.chance) < 0.04 and low >= tier["min"] and high <= tier["max"], "$%d drives match their tier" % price)

	# Stock: a batch per game hour, cheap drives common, expensive ones not guaranteed.
	check(drives.listings.size() >= drives.STOCK_MIN and drives.listings.size() <= drives.STOCK_MAX, "a batch of 6-9 drives is in stock")
	check(drives.listings.all(func(l: Dictionary) -> bool: return l.price >= 3 and l.price <= 30), "prices run from $3 to $30")
	var first_batch: int = drives.listings[0].id
	clock.advance(5.0 * 29)
	check(drives.listings[0].id == first_batch, "the stock stays the same within the hour (08:30 -> 08:59)")
	clock.advance(5.0)
	check(clock.time_text() == "09:00" and drives.listings[0].id != first_batch, "a new batch arrives at 09:00")
	var batches_with_top := 0
	var cheap := 0
	var pricey := 0
	var total := 0
	for i in 300:
		drives.restock()
		if drives.listings.any(func(l: Dictionary) -> bool: return l.price >= 25):
			batches_with_top += 1
		for listing in drives.listings:
			total += 1
			if listing.price <= 9:
				cheap += 1
			elif listing.price >= 20:
				pricey += 1
	print("Batches with a $25+ drive: %d / 300; drives up to $9: %.0f%%" % [batches_with_top, cheap * 100.0 / total])
	check(batches_with_top > 30 and batches_with_top < 270, "expensive drives are sometimes missing")
	check(cheap > pricey * 2, "cheap drives are far more common than expensive ones (%d vs %d)" % [cheap, pricey])

	# Buying.
	drives.listings.clear()
	drives.listings.append(drives.make_listing(30))
	drives.listings.append(drives.make_listing(3))
	var rich: Dictionary = drives.listings[0]
	rich.drive = drives.make_drive(30)
	while rich.drive.wallet.get("amount", 0) <= 0:
		rich.drive = drives.make_drive(30)
	rich.drive.id = rich.id
	check(drives.buy(rich.id).name == rich.drive.name and wallet.balance == wallet.START_BALANCE - 30, "buying a $30 drive charges the bank")
	check(drives.buy(rich.id).is_empty(), "a sold drive cannot be bought twice")
	check(drives.owned.size() == 1 and not drives.owned[0].plugged, "the drive waits in the drawer")

	# The shop page.
	var browser = load("res://scenes/apps/browser.tscn").instantiate()
	browser.custom_minimum_size = Vector2(1080, 880)
	root.add_child(browser)
	await process_frame
	check(browser.directory.has("deaddrive.oc") and browser.directory.has("cryptohack.oc"), "both sites are in the web directory")
	browser.open_url("DeadDrive.oc")
	await process_frame
	var shop = browser.page
	check(shop != null and shop.name == "DeadDrive", "DeadDrive.oc opens the shop")
	check(shop.listings.get_child_count() == 2 and shop.listings.get_child(0).get_node("%Buy").disabled, "sold drives stay listed as sold")
	shop.listings.get_child(1).get_node("%Buy").pressed.emit()
	check(drives.owned.size() == 2 and wallet.balance == wallet.START_BALANCE - 33, "the Buy button buys a drive")
	drives.restock()
	await shot("deaddrive")

	# My Computer: plug in, browse to the wallet file, copy the hash.
	# Mounted like on the desktop: inside the OS theme, on an opaque window body.
	var holder := PanelContainer.new()
	holder.theme = load("res://assets/generated/os_theme.tres")
	holder.theme_type_variation = &"MailList"
	var computer = load("res://scenes/apps/my_computer.tscn").instantiate()
	computer.custom_minimum_size = Vector2(1160, 680)
	holder.add_child(computer)
	browser.hide()
	root.add_child(holder)
	await process_frame
	check(computer.get_node("%Drawer").get_child_count() == 2 and computer.get_node("%SideDrives").get_child_count() == 0, "both drives are in the drawer")
	var rich_drive: Dictionary = drives.owned[0]
	computer.plug(rich_drive.id)
	check(rich_drive.plugged and computer.drive_id == rich_drive.id and computer.get_node("%Path").text.ends_with("(E:)"), "a plugged drive opens as E:")
	computer.plug(drives.owned[1].id)
	check(drives.letter(drives.owned[1].id) == "F:" and computer.get_node("%SideDrives").get_child_count() == 2, "a second drive is F: in the sidebar")
	var spare: Dictionary = drives.buy(drives.listings[-1].id) if wallet.can_afford(drives.listings[-1].price) else {}
	computer.plug(spare.get("id", -1))
	check(drives.plugged().size() == 2, "only two USB ports")
	computer.open_drive(rich_drive.id)
	var trail: Variant = path_to(rich_drive.files, rich_drive.wallet.hash)
	check(trail != null, "the wallet hash is in a file on the drive")
	for folder_name in trail:
		computer.open_folder(folder_name)
	var wallet_row: Button = null
	for row: Button in computer.get_node("%Rows").get_children():
		if computer.get_node("%FolderEmpty").visible:
			break
		if row.get_node("Row/Type").text == "Text document":
			row.pressed.emit()
			if computer.selected.text.contains(rich_drive.wallet.hash):
				wallet_row = row
				break
	check(wallet_row != null and computer.get_node("%Preview").visible and computer.get_node("%FileText").text.contains(rich_drive.wallet.hash), "the wallet file shows its hash")
	computer.copy_text()
	check(DisplayServer.get_name() == "headless" or DisplayServer.clipboard_get().contains(rich_drive.wallet.hash), "Copy puts the text on the clipboard")
	await shot("my_computer")
	computer.go_up()
	check(computer.path.size() == maxi(trail.size() - 1, 0), "Up goes one folder up")
	computer.open_drive(rich_drive.id)
	computer.show_home()
	computer.go_back()
	check(computer.drive_id == rich_drive.id and computer.path.is_empty(), "Back returns to the drive")
	computer.eject_current()
	check(not rich_drive.plugged and computer.drive_id == -1, "Eject unplugs the drive and returns to This PC")

	# cryptohack.oc
	holder.hide()
	browser.show()
	browser.open_url("cryptohack.oc")
	await process_frame
	var hack = browser.page
	check(hack.name == "CryptoHack", "cryptohack.oc opens")
	hack.hash_field.text = "not a hash"
	hack.crack()
	check(hack.result.text == "INVALID HASH", "a malformed hash is rejected")
	hack.hash_field.text = "ab".repeat(32)
	await hack.crack()
	check(hack.result.text == "WALLET NOT FOUND", "an unknown hash finds nothing")
	var holdings_before: float = market.holdings
	hack.hash_field.text = "  " + rich_drive.wallet.hash.to_upper() + " "
	await hack.crack()
	var expected: float = rich_drive.wallet.amount / market.price
	check(is_equal_approx(market.holdings - holdings_before, expected), "the wallet's dollars arrive as SKAM ($%d)" % rich_drive.wallet.amount)
	check(market.trades[0].side == "in" and market.cost_basis == 0.0, "the top-up is logged and costs nothing")
	await shot("cryptohack")
	await hack.crack()
	check(hack.result.text == "ALREADY DRAINED" and is_equal_approx(market.holdings - holdings_before, expected), "a wallet is drained only once")
	var decoy: Dictionary = drives.make_drive(3)
	while decoy.wallet.is_empty() or decoy.wallet.amount > 0:
		decoy = drives.make_drive(3)
	drives.owned.append(decoy)
	hack.hash_field.text = decoy.wallet.hash
	await hack.crack()
	check(hack.result.text == "WALLET IS EMPTY", "an emptied wallet pays nothing")

	# Destroying drives in My Computer.
	holder.show()
	browser.hide()
	var doomed: Dictionary = drives.owned[1]
	if doomed.plugged:
		computer.open_drive(doomed.id)
	else:
		computer.plug(doomed.id)
	check(computer.drive_id == doomed.id and computer.get_node("%DestroyCurrent").visible, "an open drive shows Destroy in the ribbon")
	computer._destroy_current_pressed()
	check(drives.find_drive(doomed.id) == doomed, "the first Destroy press only asks")
	computer._destroy_current_pressed()
	check(drives.find_drive(doomed.id).is_empty() and computer.drive_id == -1, "the second press destroys the open drive and returns to This PC")
	var drawer_tile: Button = null
	for tile in computer.get_node("%Drawer").get_children():
		if tile.get_node("%Title").text == rich_drive.name:
			drawer_tile = tile
	check(drawer_tile != null and drawer_tile.get_node("%Destroy").visible, "drawer drives have a Destroy button")
	drawer_tile.get_node("%Destroy").pressed.emit()
	await shot("my_computer_destroy")
	check(drawer_tile.get_node("%Destroy").text == "Sure? Destroy" and not drives.find_drive(rich_drive.id).is_empty(), "Destroy asks to confirm")
	drawer_tile.get_node("%Destroy").pressed.emit()
	check(drives.find_drive(rich_drive.id).is_empty(), "confirming destroys the drive in the drawer")
	check(drives.check(rich_drive.wallet.hash) == drives.Redeem.UNKNOWN, "a destroyed drive's hash is gone with it")
	check(not drives.destroy(rich_drive.id), "a drive cannot be destroyed twice")

	# Save and load.
	var saved: Dictionary = drives.save_state()
	drives.reset_state()
	drives.load_state(saved)
	check(drives.owned.size() == saved.owned.size() and drives.redeemed.has(rich_drive.wallet.hash), "drives and drained wallets are saved")
	check(drives.listings.size() == saved.listings.size() and drives.stock_hour == saved.stock_hour, "the shop stock is saved for the same hour")

	holder.queue_free()
	browser.queue_free()
	await process_frame
	print("Drive checks finished; failures: ", failures)
	quit(1 if failures else 0)
