extends Node

## Player accounts shown on the login screen, registered as the `Profiles` autoload.
## Each user is a separate save slot (see `SaveGame`); the list is stored in `user://profiles.cfg`.

signal changed

const DEFAULT_PATH := "user://profiles.cfg"
const MAX_NAME_LENGTH := 20
const AVATARS: Array[Texture2D] = [
	preload("res://assets/generated/avatar_rocket.svg"),
	preload("res://assets/generated/avatar_flower.svg"),
	preload("res://assets/generated/avatar_ball.svg"),
	preload("res://assets/generated/avatar_duck.svg"),
]

## Where the user list is stored; tests point this at a scratch file.
var path := DEFAULT_PATH
## Oldest first. Each entry: {"id": String, "name": String, "avatar": int}.
## `id` names the user's save file, so it never changes.
var users: Array[Dictionary] = []
## Name of the user who is logged in, empty on the login screen.
var current := ""

func _ready() -> void:
	load_users()

func load_users() -> void:
	users.clear()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for entry in config.get_value("profiles", "users", []):
			if entry is Dictionary and entry.has("name"):
				users.append({
					"id": str(entry.get("id", _make_id(str(entry.name)))),
					"name": str(entry.name),
					"avatar": int(entry.get("avatar", 0)),
				})
		# Users saved before ids existed get one now; store it so it stays the same.
		if config.get_value("profiles", "users", []).any(func(entry) -> bool: return entry is Dictionary and not entry.has("id")):
			_save()
	changed.emit()

func has_user(user_name: String) -> bool:
	return users.any(func(entry: Dictionary) -> bool: return entry.name.to_lower() == user_name.strip_edges().to_lower())

## Returns why [param user_name] cannot be used for a new user, or an empty string when it can.
func name_error(user_name: String) -> String:
	var clean := user_name.strip_edges()
	if clean.is_empty():
		return "Type a name first."
	if clean.length() > MAX_NAME_LENGTH:
		return "The name is too long."
	if has_user(clean):
		return "This user already exists."
	return ""

func create(user_name: String) -> bool:
	if not name_error(user_name).is_empty():
		return false
	var clean := user_name.strip_edges()
	users.append({"id": _make_id(clean), "name": clean, "avatar": users.size() % AVATARS.size()})
	_save()
	changed.emit()
	return true

func avatar(entry: Dictionary) -> Texture2D:
	return AVATARS[posmod(int(entry.avatar), AVATARS.size())]

func find(user_name: String) -> Dictionary:
	for entry in users:
		if entry.name == user_name:
			return entry
	return {}

## Logs in as [param user_name] and loads their saved game (a new game for a new user).
func log_in(user_name: String) -> void:
	var entry := find(user_name)
	if entry.is_empty():
		return
	current = user_name
	SaveGame.load_profile(entry.id)

## Deletes every user, their saved games and the saved list.
func reset() -> void:
	SaveGame.delete_all()
	users.clear()
	current = ""
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	changed.emit()

## File-safe unique id: the name's letters and digits plus a timestamp.
func _make_id(user_name: String) -> String:
	var slug := ""
	for character in user_name.to_lower():
		if character.unicode_at(0) < 128 and (character.is_valid_identifier() or character.is_valid_int()):
			slug += character
	return "%s_%d" % [slug.left(12) if not slug.is_empty() else "user", Time.get_unix_time_from_system() * 1000.0]

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("profiles", "users", users)
	config.save(path)
