class_name SaveStore
extends RefCounted
## The only code that reads or writes the player's files (AR37; AR18: nothing outside core/ and
## world/room_loader.gd reads files). It handles `settings.json`; Story 1.21 adds the slots here.
## It reads, writes and returns errors, and never decides when to write: `core/game.gd` does.
## Parse with `JSON.new().parse()` only: `JSON.parse_string()` and ConfigFile print an engine
## `ERROR:` on bad input, which fails the test runner (R15).
## It never creates folders (Story 1.4 D5): `user://` always exists, and a failed
## `DirAccess.make_dir_recursive_absolute()` prints an engine `ERROR:`.

const SETTINGS_VERSION := 1
const DEFAULT_DIR := "user://"

## The folder it reads and writes. Tests point it at a temp folder they create and remove; it is
## also the injectable save directory Story 1.21 needs.
var dir := DEFAULT_DIR


func settings_path() -> String:
	return dir.path_join("settings.json")


## The inner `settings` dictionary, or null when nothing usable is there. A missing file is a
## first launch: null, silently. Anything else unusable warns once; the caller then uses the
## defaults and rewrites the file.
func read_settings() -> Variant:
	var path := settings_path()
	if not FileAccess.file_exists(path):  # FileAccess.get_file_as_string() would print an error
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _unusable(path, "can't be opened (%s)" % error_string(FileAccess.get_open_error()))
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return _unusable(path, "is not valid JSON (%s)" % json.get_error_message())
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return _unusable(path, "is not a JSON object")
	# A JSON number comes back as a float. A newer version counts as corrupt: there is no settings
	# migration yet; the first change to a key's meaning bumps the version and adds one.
	var version: Variant = data.get("version")
	if not (version is int or version is float) or version != SETTINGS_VERSION:
		return _unusable(path, "has version %s, not %d" % [version, SETTINGS_VERSION])
	if not data.get("settings") is Dictionary:
		return _unusable(path, "has no settings object")
	return data["settings"]


## Writes `.tmp`, then renames it over the file (which replaces it), so a crash mid-write leaves
## the old file whole. Returns the first error; the caller warns.
func write_settings(settings: Dictionary) -> Error:
	var path := settings_path()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var written := f.store_string(JSON.stringify({"version": SETTINGS_VERSION, "settings": settings}, "\t"))
	f.close()
	if not written:
		return ERR_FILE_CANT_WRITE
	var err := DirAccess.rename_absolute(tmp, path)
	if err == OK:
		Log.info(Log.SAVE, "settings written")
	return err


func _unusable(path: String, why: String) -> Variant:
	push_warning("SaveStore: %s %s; using the default settings" % [path, why])
	return null
