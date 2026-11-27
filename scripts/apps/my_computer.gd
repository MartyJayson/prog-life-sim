extends VBoxContainer

## My Computer: the local disk, flash drives plugged into the USB ports and the drives waiting in
## the drawer. A plugged drive opens like a folder; text files show their contents in the preview
## pane and can be copied (e.g. a wallet hash for cryptohack.oc).

signal site_requested(address: String)

const DRIVE_TILE = preload("res://scenes/computer/drive_tile.tscn")
const FILE_ROW = preload("res://scenes/computer/file_row.tscn")
const SIDE_DRIVE = preload("res://scenes/computer/side_drive.tscn")
const HARD_DRIVE = preload("res://assets/generated/hard_drive.svg")
const FLASH_DRIVE = preload("res://assets/generated/flash_drive.svg")
const FOLDER_ICON = preload("res://assets/generated/folder.svg")
const FILE_ICON = preload("res://assets/generated/file.svg")
const IMAGE_ICON = preload("res://assets/generated/file_image.svg")
const USB_PORTS := 2
const LOCAL_DISK_KB := 256 * 1048576
const LOCAL_DISK_USED_KB := 97 * 1048576
const FILE_TYPES := {
	"txt": "Text document", "jpg": "JPEG image", "docx": "Word document", "pdf": "PDF document",
	"xlsx": "Spreadsheet", "pptx": "Presentation", "zip": "ZIP archive", "mp4": "Video", "sav": "Save file",
}

@export var place_group: ButtonGroup
@export var file_group: ButtonGroup

## Drive being browsed, or -1 for This PC.
var drive_id := -1
## Folder names from the drive's root to the folder being shown.
var path: Array[String] = []
## File shown in the preview pane, or {}.
var selected: Dictionary = {}
var _history: Array[Dictionary] = []

func _ready() -> void:
	%LocalDisk.setup(HARD_DRIVE, Color.WHITE, "Local Disk (C:)", LOCAL_DISK_USED_KB, LOCAL_DISK_KB)
	%LocalDisk.disabled = true
	Drives.changed.connect(_refresh)
	_refresh()

func show_home() -> void:
	_go(-1, [])

func open_drive(id: int) -> void:
	_go(id, [])

func open_folder(folder_name: String) -> void:
	var deeper := path.duplicate()
	deeper.append(folder_name)
	_go(drive_id, deeper)

func go_up() -> void:
	if not path.is_empty():
		_go(drive_id, path.slice(0, -1))
	elif drive_id >= 0:
		_go(-1, [])

func go_back() -> void:
	if _history.is_empty():
		return
	var place: Dictionary = _history.pop_back()
	_show(place.drive, place.path)

## Plugs a drive from the drawer into a free USB port and opens it.
func plug(id: int) -> void:
	if Drives.plugged().size() >= USB_PORTS:
		return
	Drives.set_plugged(id, true)
	open_drive(id)

func eject_current() -> void:
	if drive_id >= 0:
		var id := drive_id
		_history.clear()
		_show(-1, [])
		Drives.set_plugged(id, false)

## Destroys a drive for good; a plugged one is pulled out first.
func destroy(id: int) -> void:
	if id == drive_id:
		_history.clear()
		_show(-1, [])
	_history = _history.filter(func(place: Dictionary) -> bool: return place.drive != id)
	%Back.disabled = _history.is_empty()
	Drives.destroy(id)

## Ribbon Destroy for the open drive: the first press asks, the second destroys.
func _destroy_current_pressed() -> void:
	if drive_id < 0:
		return
	if %DestroyCurrent.text != "Sure? Destroy":
		%DestroyCurrent.text = "Sure? Destroy"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_reset_destroy_current())
		return
	destroy(drive_id)

func _reset_destroy_current() -> void:
	%DestroyCurrent.text = "Destroy"

func copy_text() -> void:
	if selected.is_empty():
		return
	DisplayServer.clipboard_set(selected.text)
	%Copy.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			%Copy.text = "Copy text")

func _open_shop() -> void:
	site_requested.emit("deaddrive.oc")

func _go(id: int, new_path: Array) -> void:
	_history.append({"drive": drive_id, "path": path.duplicate()})
	_show(id, new_path)

## Shows This PC or a folder on a plugged drive.
func _show(id: int, new_path: Array) -> void:
	var drive := Drives.find_drive(id)
	if id >= 0 and (drive.is_empty() or not drive.plugged):
		id = -1
		new_path = []
	drive_id = id
	path.assign(new_path)
	selected = {}
	%Preview.hide()
	%Home.visible = id < 0
	%Folder.visible = id >= 0
	%Eject.visible = id >= 0
	%DestroyCurrent.visible = id >= 0
	_reset_destroy_current()
	%Back.disabled = _history.is_empty()
	%Up.disabled = id < 0
	var crumbs: PackedStringArray = ["This PC"]
	if id >= 0:
		crumbs.append(_volume_name(drive))
		crumbs.append_array(path)
		_fill_rows(_items(drive))
	%Path.text = "  ›  ".join(crumbs)
	_select_place()

func _refresh() -> void:
	# A drive ejected or gone while it was open sends the window back to This PC.
	if drive_id >= 0 and not Drives.find_drive(drive_id).get("plugged", false):
		_show(-1, [])
	var plugged := Drives.plugged()
	var side: VBoxContainer = %SideDrives
	_clear(side)
	for drive in plugged:
		var button: Button = SIDE_DRIVE.instantiate()
		button.text = _volume_name(drive)
		button.button_group = place_group
		button.set_meta("drive", drive.id)
		button.add_theme_color_override("icon_normal_color", drive.color)
		button.pressed.connect(open_drive.bind(drive.id))
		side.add_child(button)
	%NoDrives.visible = plugged.is_empty()
	%Ports.text = "%d  (%d in use)" % [USB_PORTS, plugged.size()]

	var devices: HFlowContainer = %Devices
	for tile in devices.get_children():
		if tile != %LocalDisk:
			devices.remove_child(tile)
			tile.queue_free()
	for drive in plugged:
		var tile: Button = DRIVE_TILE.instantiate()
		devices.add_child(tile)
		tile.setup(FLASH_DRIVE, drive.color, _volume_name(drive), Drives.tree_size(drive.files), drive.capacity * 1048576)
		tile.pressed.connect(open_drive.bind(drive.id))
		tile.allow_destroy()
		tile.destroy_confirmed.connect(destroy.bind(drive.id))

	var drawer: HFlowContainer = %Drawer
	_clear(drawer)
	var ports_full := plugged.size() >= USB_PORTS
	for drive in Drives.owned:
		if drive.plugged:
			continue
		var tile: Button = DRIVE_TILE.instantiate()
		drawer.add_child(tile)
		tile.setup(FLASH_DRIVE, drive.color, drive.name, 0, drive.capacity * 1048576, true)
		tile.get_node("%Plug").disabled = ports_full
		tile.get_node("%Plug").tooltip_text = "Both USB ports are busy. Eject a drive first." if ports_full else ""
		tile.plug_pressed.connect(plug.bind(drive.id))
		tile.allow_destroy()
		tile.destroy_confirmed.connect(destroy.bind(drive.id))
	%DrawerEmpty.visible = drawer.get_child_count() == 0
	_select_place()

func _select_place() -> void:
	%ThisPC.set_pressed_no_signal(drive_id < 0)
	for button: Button in %SideDrives.get_children():
		button.set_pressed_no_signal(button.get_meta("drive") == drive_id)

func _volume_name(drive: Dictionary) -> String:
	return "%s (%s)" % [drive.label, Drives.letter(drive.id)]

## Items of the folder at `path` on [param drive], folders first.
func _items(drive: Dictionary) -> Array:
	var items: Array = drive.files
	for folder_name in path:
		var match_index := items.find_custom(func(item: Dictionary) -> bool: return item.folder and item.name == folder_name)
		if match_index < 0:
			return []
		items = items[match_index].children
	var sorted := items.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.folder and not b.folder or (a.folder == b.folder and a.name.naturalnocasecmp_to(b.name) < 0))
	return sorted

func _fill_rows(items: Array) -> void:
	var rows: VBoxContainer = %Rows
	_clear(rows)
	for item: Dictionary in items:
		var row: Button = FILE_ROW.instantiate()
		row.button_group = file_group
		row.get_node("Row/Icon").texture = FOLDER_ICON if item.folder else _icon(item.name)
		row.get_node("Row/Name").text = item.name
		row.get_node("Row/Type").text = "Folder" if item.folder else _type(item.name)
		row.get_node("Row/Size").text = "" if item.folder else _size(int(item.size))
		row.set_meta("name", item.name)
		if item.folder:
			row.pressed.connect(open_folder.bind(item.name))
		else:
			row.pressed.connect(_select_file.bind(item))
		rows.add_child(row)
	%FolderEmpty.visible = items.is_empty()

func _select_file(item: Dictionary) -> void:
	selected = item
	var text: String = item.get("text", "")
	%FileIcon.texture = _icon(item.name)
	%FileName.text = item.name
	%FileMeta.text = "%s  ·  %s" % [_type(item.name), _size(int(item.size))]
	%FileText.text = text
	%FileText.visible = not text.is_empty()
	%Copy.visible = not text.is_empty()
	%Copy.text = "Copy text"
	%NoPreview.visible = text.is_empty()
	%Preview.show()

func _icon(file_name: String) -> Texture2D:
	return IMAGE_ICON if file_name.get_extension().to_lower() == "jpg" else FILE_ICON

func _type(file_name: String) -> String:
	var extension := file_name.get_extension().to_lower()
	return FILE_TYPES.get(extension, extension.to_upper() + " file")

func _size(kb: int) -> String:
	return %LocalDisk.format_size(kb)

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
