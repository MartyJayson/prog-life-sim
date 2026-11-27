extends Node

## Per-user saved game, registered as the `SaveGame` autoload.
##
## Each user's progress lives in `user://saves/<profile id>.save`. Logging in loads it into the
## game-state autoloads (Wallet, Mailbox, Jobs); a brand-new user starts from their defaults.
## Progress is written shortly after every change, on a periodic timer and when the game closes.

signal saved

const DEFAULT_DIR := "user://saves"
const VERSION := 1
## Seconds to wait after a change before writing, so bursts of changes cost one write.
const SAVE_DELAY := 0.5
const AUTOSAVE_INTERVAL := 30.0

## Where save files go; tests point this at a scratch folder.
var directory := DEFAULT_DIR
## Profile id whose progress is loaded, empty before login.
var profile_id := ""

var _dirty := false
var _countdown := 0.0
var _autosave := 0.0

func _ready() -> void:
	Wallet.changed.connect(_changed.unbind(1))
	Wallet.tokens_changed.connect(_changed.unbind(1))
	Mailbox.changed.connect(_changed)
	Jobs.changed.connect(_changed)

func _process(delta: float) -> void:
	if profile_id.is_empty():
		return
	_autosave += delta
	if _dirty:
		_countdown -= delta
		if _countdown <= 0.0:
			save()
	elif _autosave >= AUTOSAVE_INTERVAL:
		# Keeps time-based state such as letters still on their way up to date.
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not profile_id.is_empty():
		save()

func path_for(id: String) -> String:
	return directory.path_join(id + ".save")

func has_save(id: String) -> bool:
	return FileAccess.file_exists(path_for(id))

## Loads [param id]'s progress, or starts a new game for them when they have no save yet.
func load_profile(id: String) -> void:
	profile_id = id
	var data := _read(path_for(id))
	_restore(Wallet, data.get("wallet", {}))
	_restore(Mailbox, data.get("mailbox", {}))
	_restore(Jobs, data.get("jobs", {}))
	_dirty = false
	if data.is_empty():
		save()

## Writes the current progress to the logged-in user's save file.
func save() -> bool:
	_dirty = false
	_autosave = 0.0
	if profile_id.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(path_for(profile_id), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save for %s: %s" % [profile_id, error_string(FileAccess.get_open_error())])
		return false
	file.store_var({
		"version": VERSION,
		"wallet": Wallet.save_state(),
		"mailbox": Mailbox.save_state(),
		"jobs": Jobs.save_state(),
	})
	saved.emit()
	return true

func delete_save(id: String) -> void:
	if has_save(id):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(id)))

## Removes every save file and logs out, without writing anything back.
func delete_all() -> void:
	profile_id = ""
	_dirty = false
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".save"):
			dir.remove(file_name)

func _changed() -> void:
	if profile_id.is_empty():
		return
	_dirty = true
	_countdown = SAVE_DELAY

func _restore(target: Node, data: Variant) -> void:
	target.reset_state()
	if data is Dictionary and not data.is_empty():
		target.load_state(data)

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if data is Dictionary:
		return data
	push_warning("Save file %s is damaged; starting a new game." % file_path)
	return {}
