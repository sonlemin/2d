class_name SaveStore
extends RefCounted
## The only code that reads or writes the player's files (AR37; AR18: nothing outside core/ and
## world/room_loader.gd reads files): `settings.json` and the three slots, `slot_N.json`
## (Story 1.21). It reads, writes and returns errors, and never decides when to write:
## `core/game.gd` does.
## Parse with `JSON.new().parse()` only: `JSON.parse_string()` and ConfigFile print an engine
## `ERROR:` on bad input, which fails the test runner (R15).
## It never creates folders (Story 1.4 D5): `user://` always exists, and a failed
## `DirAccess.make_dir_recursive_absolute()` prints an engine `ERROR:`.
## It never calls `DirAccess.copy_absolute()` either: that prints an engine `ERROR:` whenever the
## source or the destination can't be opened (probed on 4.7.2), so the `.bak` is copied with
## FileAccess.
## A slot is three files (1.21 D4): `slot_N.json`, `slot_N.json.bak` (the file as it was before
## the last write) and, only during a write, `slot_N.json.tmp`.

## What a read found, for settings and for each slot file. For settings, MISSING and CORRUPT are
## safe to replace. UNREADABLE (it exists but can't be opened) and NEWER (a later build wrote it)
## may be whole, so nothing ever writes over them (1.4 review). A slot is stricter: `write_slot()`
## refuses a CORRUPT one too, so a damaged slot is replaced only by New Game (`delete_slot()`).
enum Found { USABLE, MISSING, CORRUPT, UNREADABLE, NEWER }

const SETTINGS_VERSION := 1
const DEFAULT_DIR := "user://"
const SLOTS := 3  ## save slots, numbered 1..SLOTS (UX slot picker, Story 1.38)

## The folder it reads and writes. Tests point it at a temp folder they create and remove.
var dir := DEFAULT_DIR
## The slot format `read_slot()` accepts, and the steps it migrates an older file with. Only a
## test changes them (to load a v1 file as v3 through fake steps); the number's home is Migrations.
var version := Migrations.VERSION
var steps := Migrations.steps()


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


## Through the same verified write as a slot (`_write()`), with no `.bak` (1.21 D11). On Windows
## the engine deletes the old file and then moves the new one (4.7 `DirAccessWindows::rename`): a
## crash between the two leaves only `.tmp`, which nothing reads, so the next launch starts from
## the defaults. That is acceptable for settings. Returns the first error; the caller warns.
func write_settings(settings: Dictionary) -> Error:
	var err := _write(settings_path(), JSON.stringify({"version": SETTINGS_VERSION, "settings": settings}, "\t"), false)
	if err == OK:
		Log.info(Log.SAVE, "settings written")
	return err


func slot_path(n: int) -> String:
	assert(n >= 1 and n <= SLOTS, "SaveStore: no slot %d (slots are 1..%d)" % [n, SLOTS])
	return dir.path_join("slot_%d.json" % n)


## `{found, from_bak, why, version, meta, slot, dive}`: slot `n` as its two files give it. `slot`
## and `meta` are Dictionaries (empty unless USABLE); `dive` is a Dictionary, or null when the file
## holds no dive snapshot. `meta` is only a copy for the slot picker: nothing loads state from it.
## It prints nothing and pushes no warning: `why` says what was wrong, and the caller warns.
## The main file first, then `.bak` (1.21 D3):
## - a USABLE main file is the slot;
## - a NEWER or UNREADABLE main file may be whole, so it blocks the slot: never bypassed for an
##   older `.bak`;
## - a MISSING or CORRUPT main file falls back to `.bak`, by the same three rules (`from_bak` is
##   true when the `.bak` is what loaded). A missing main file with a whole `.bak` is what a crash
##   between the backup and the rename leaves on Windows (D4);
## - both MISSING is an empty slot; anything else left is CORRUPT, a damaged slot.
func read_slot(n: int) -> Dictionary:
	var path := slot_path(n)
	var main := _read_slot_file(path)
	if main.found in [Found.USABLE, Found.NEWER, Found.UNREADABLE]:
		return main
	var bak := _read_slot_file(path + ".bak")
	if bak.found in [Found.USABLE, Found.NEWER, Found.UNREADABLE]:
		bak.from_bak = bak.found == Found.USABLE
		if main.found == Found.CORRUPT:
			bak.why = "%s; %s" % [main.why, bak.why if bak.why != "" else "its .bak was used"]
		elif bak.why == "":
			bak.why = "%s is missing; its .bak was used" % path
		return bak
	if main.found == Found.MISSING and bak.found == Found.MISSING:
		return main
	var both := PackedStringArray([main.why, bak.why])
	return _slot_result(Found.CORRUPT, "; ".join(both) if main.why != "" and bak.why != "" else main.why + bak.why)


## Slot `n`, safely (1.21 D4): `.tmp` is written and read back before anything else is touched,
## the current main file becomes `.bak` only when it is known good, and the rename comes last. So
## a failed write changes nothing, and a whole main file or a whole `.bak` exists at every moment.
## A slot that is CORRUPT, UNREADABLE or NEWER is never written over (D3): the caller starts a new
## game through `delete_slot()` instead. Returns the first error; the caller warns and signals.
func write_slot(n: int, data: Dictionary) -> Error:
	var read := read_slot(n)
	match read.found:
		Found.CORRUPT:
			return ERR_FILE_CORRUPT
		Found.UNREADABLE:
			return ERR_FILE_CANT_OPEN
		Found.NEWER:
			return ERR_FILE_UNRECOGNIZED
	var text := JSON.stringify(data, "\t")
	# Only a main file that just read USABLE is copied: never a corrupt one over the good `.bak`
	# the slot loaded from, and there is nothing to copy on a first save.
	var err := _write(slot_path(n), text, read.found == Found.USABLE and not read.from_bak)
	if err == OK:
		Log.info(Log.SAVE, "slot %d written (%d bytes)" % [n, text.to_utf8_buffer().size()])
	return err


## Removes slot `n`'s three files; a missing one is no error. Returns the first real error.
## `DirAccess.remove_absolute()` returns FAILED for a missing file, so each is checked first.
func delete_slot(n: int) -> Error:
	var path := slot_path(n)
	var first := OK
	for file: String in [path, path + ".bak", path + ".tmp"]:
		if not FileAccess.file_exists(file):
			continue
		var err := DirAccess.remove_absolute(file)
		if err != OK and first == OK:
			first = err
	return first


## True when the file at `path` holds exactly `text` and that text parses as JSON: the read-back
## of a write. On the web it reads the in-memory filesystem, so it proves the write was whole, not
## that it will persist (Story 1.39).
static func verify_file(path: String, text: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var got := f.get_as_text()
	return got == text and JSON.new().parse(got) == OK


## The one write (1.21 D4), for slots and settings: `text` to `path + ".tmp"`, read back
## (`verify_file()`), then renamed over `path`. With `backup`, the file now at `path` is copied to
## `path + ".bak"` between the two, after `.tmp` is known whole. On Linux the rename replaces the
## file in one step. On Windows the engine deletes the target, then moves (4.7 source): a crash
## between the two leaves no main file, a whole `.bak` and a whole `.tmp`, which `read_slot()`
## covers. Prints nothing on any failure (probed on 4.7.2).
func _write(path: String, text: String, backup: bool) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var stored := f.store_string(text)
	f.close()
	if not stored or not verify_file(tmp, text):
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	if backup:
		var err := _copy(path, path + ".bak")
		if err != OK:
			DirAccess.remove_absolute(tmp)
			return err
	return DirAccess.rename_absolute(tmp, path)


## `from`'s bytes into `to`, with FileAccess: `DirAccess.copy_absolute()` prints an engine
## `ERROR:` when either file can't be opened.
static func _copy(from: String, to: String) -> Error:
	var src := FileAccess.open(from, FileAccess.READ)
	if src == null:
		return FileAccess.get_open_error()
	var bytes := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(to, FileAccess.WRITE)
	if dst == null:
		return FileAccess.get_open_error()
	var stored := dst.store_buffer(bytes)
	dst.close()
	return OK if stored else ERR_FILE_CANT_WRITE


## One slot file, judged alone. The version is judged before the rest of the shape: a newer
## build may have changed the shape, and its file must read as NEWER (kept), never as CORRUPT.
## Every version this build can read has `slot` (a Dictionary) and `dive` (a Dictionary or null)
## at the top level, so a migration step may rely on both.
func _read_slot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):  # FileAccess.get_file_as_string() would print an error
		return _slot_result(Found.MISSING, "")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _slot_result(Found.UNREADABLE, "%s can't be opened (%s)" % [path, error_string(FileAccess.get_open_error())])
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return _slot_result(Found.CORRUPT, "%s is not valid JSON (%s)" % [path, json.get_error_message()])
	var parsed: Variant = json.get_data()
	if not parsed is Dictionary:
		return _slot_result(Found.CORRUPT, "%s is not a JSON object" % path)
	var data: Dictionary = parsed
	# A JSON number comes back as a float. Check the type before comparing: on 4.7.2 "1" == 1 is
	# a script error, not false. Above 2^53 a float was never a version a build wrote.
	var v: Variant = data.get("version")
	if not (v is int or v is float) or v != floorf(v) or v < 1 or absf(v) > SlotState.WHOLE_FLOAT_MAX:
		return _slot_result(Found.CORRUPT, "%s has no whole version number" % path)
	if v > version:
		return _slot_result(Found.NEWER, "%s has version %d, newer than this build's %d" % [path, v, version], int(v))
	var shape := _slot_shape(data)
	if shape != "":
		return _slot_result(Found.CORRUPT, "%s %s" % [path, shape])
	if v < version:
		data = Migrations.migrate(data, version, steps)
		if data.is_empty():
			return _slot_result(Found.CORRUPT, "%s has version %d, and this build has no way to bring it to %d" % [path, v, version])
		shape = _slot_shape(data)
		if shape != "":
			return _slot_result(Found.CORRUPT, "%s %s after its migration" % [path, shape])
	var out := _slot_result(Found.USABLE, "", version)
	out.slot = data["slot"]
	out.dive = data.get("dive")
	if data.get("meta") is Dictionary:  # a missing or bad meta never costs a good slot
		out.meta = data["meta"]
	return out


## What is wrong with a slot file's top level, or "".
static func _slot_shape(data: Dictionary) -> String:
	if not data.get("slot") is Dictionary:
		return "has no slot object"
	var dive: Variant = data.get("dive")  # a missing key reads as null: no dive snapshot
	if not (dive == null or dive is Dictionary):
		return "has a dive that is neither an object nor null"
	return ""


static func _slot_result(found: Found, why: String, v := 0) -> Dictionary:
	return {found = found, from_bak = false, why = why, version = v, meta = {}, slot = {}, dive = null}


func _unusable(found: Found, path: String, why: String) -> Dictionary:
	var kept := found == Found.UNREADABLE or found == Found.NEWER
	push_warning("SaveStore: %s %s; using the default settings%s" % [
			path, why, " for this session and leaving the file as it is" if kept else ""])
	return {found = found, settings = {}}
