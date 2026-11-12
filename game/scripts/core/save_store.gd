class_name SaveStore
extends RefCounted
## The only code that reads or writes the player's files (AR37; AR18: nothing outside core/ and
## world/room_loader.gd reads files). It handles `settings.json`; Story 1.21 adds the slots here.
## It reads, writes and returns errors, and never decides when to write: `core/game.gd` does.
## Parse with `JSON.new().parse()` only: `JSON.parse_string()` and ConfigFile print an engine
## `ERROR:` on bad input, which fails the test runner (R15).
## It never creates folders (Story 1.4 D5): `user://` always exists, and a failed
## `DirAccess.make_dir_recursive_absolute()` prints an engine `ERROR:`.

## What `read_settings()` found. MISSING and CORRUPT are safe to replace. UNREADABLE (it exists
## but can't be opened) and NEWER (a later build wrote it) may be whole, so the caller must never
## write over them (1.4 review; Story 1.21 gives slots the same rule: "rejected and left
## untouched").
enum Found { USABLE, MISSING, CORRUPT, UNREADABLE, NEWER }

const SETTINGS_VERSION := 1
const DEFAULT_DIR := "user://"

## The folder it reads and writes. Tests point it at a temp folder they create and remove; it is
## also the injectable save directory Story 1.21 needs.
var dir := DEFAULT_DIR


func settings_path() -> String:
	return dir.path_join("settings.json")


## `{found = Found.…, settings = {…}}`: the file's inner `settings` dictionary when USABLE, an
## empty one otherwise. A missing file is a first launch: silent. Anything else unusable warns
## once; the caller then uses the defaults, and `found` tells it whether it may rewrite the file.
func read_settings() -> Dictionary:
	var path := settings_path()
	if not FileAccess.file_exists(path):  # FileAccess.get_file_as_string() would print an error
		return {found = Found.MISSING, settings = {}}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _unusable(Found.UNREADABLE, path, "can't be opened (%s)" % error_string(FileAccess.get_open_error()))
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return _unusable(Found.CORRUPT, path, "is not valid JSON (%s)" % json.get_error_message())
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return _unusable(Found.CORRUPT, path, "is not a JSON object")
	# A JSON number comes back as a float. There is no settings migration yet: the first change to
	# a key's meaning bumps the version and adds one. Until then an older version can't exist, so
	# anything that isn't this version or a newer one is corrupt.
	var version: Variant = data.get("version")
	if not (version is int or version is float):
		return _unusable(Found.CORRUPT, path, "has no version number")
	if version > SETTINGS_VERSION:
		return _unusable(Found.NEWER, path, "has version %s, newer than this build's %d" % [version, SETTINGS_VERSION])
	if version != SETTINGS_VERSION:
		return _unusable(Found.CORRUPT, path, "has version %s, not %d" % [version, SETTINGS_VERSION])
	if not data.get("settings") is Dictionary:
		return _unusable(Found.CORRUPT, path, "has no settings object")
	return {found = Found.USABLE, settings = data["settings"]}


## Writes `.tmp`, then renames it over the file. On Linux the rename replaces the file in one
## step, so a crash mid-write leaves the old file whole. On Windows the engine deletes the old
## file and then moves the new one (4.7 `DirAccessWindows::rename`): a crash between the two
## leaves only `.tmp`, which nothing reads, so the next launch starts from the defaults. That
## is acceptable for settings; slots keep a `.bak` (Story 1.21). Returns the first error; the
## caller warns.
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


func _unusable(found: Found, path: String, why: String) -> Dictionary:
	var kept := found == Found.UNREADABLE or found == Found.NEWER
	push_warning("SaveStore: %s %s; using the default settings%s" % [
			path, why, " for this session and leaving the file as it is" if kept else ""])
	return {found = found, settings = {}}
