extends Node
## The `Game` autoload (AR9, AR11): references to session-long state and the commands that load
## it, never rules. It keeps the same instances all session and resets them in place, because
## subscribers hold on to them: gear changes call `tuning.apply_gear()`, never a new Tuning, and
## replacing a ref is an assert (Story 1.4 D7). `devices` arrives with Story 1.37.
## Two refs are child nodes because they need the tree: `clock` (timers) and `display` (the
## window, Story 1.14). Neither holds rule state.
## `palette` (Story 1.18): the active zone's UI colours; presentation, not save data. A RefCounted,
## not a child: it needs no tree. World sets its zone on every room build; UI reads it by role.
## Starting up touches no file (D6): the entry scene calls `boot()` once, which loads
## `settings.json` and slot 1 and arms their writes. A test never boots against the real folder:
## one that checks a file points `store.dir` at a temp folder first and ends with
## `reset_for_tests()`.
## Saves (AR38, R14, Story 1.21). Two kinds, both through `store.write_slot()`:
## - `save_now()`, the resume save: the slot and the dive as they are. It is what moves where a
##   load wakes the player and what makes carried embers safe.
## - `save_progress()`, the progress save: the live slot, but with the resume keys and the dive of
##   the last resume save (`_resume`, taken in memory at each load and each successful resume
##   save, D6). So it never moves the resume point and never makes carried embers safe.
## Slot saves are armed (D7), like settings writes: off until `boot()`, `load_slot()` or
## `new_game()` ran, so a World added by a test can call a save and write nothing.
## A failed save is an environment error: one warning and `save_failed`, never a crash or a pause.

## A slot file was written. The autosave icon binds to it (Story 1.25).
signal save_succeeded(n: int)
## A slot save failed; nothing on disk changed. The "Not saved" state binds to it (Story 1.39).
signal save_failed(n: int, err: Error)
## A settings write failed (1.21 D11). Whether the UI shows it is Story 1.39's call.
signal settings_save_failed(err: Error)

var settings := Settings.new():  ## AR14: global, per machine; UI writes only these
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.settings is session-long: reset it in place, never replace it")
var slot := SlotState.new():  ## AR14: per save slot; New Game and Load reset it in place
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.slot is session-long: reset it in place, never replace it")
var dive := DiveState.new():  ## AR14: per dive; a rest, home and leaving the layer reset it
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.dive is session-long: reset it in place, never replace it")
var tuning := Tuning.new():  ## AR15: every bendable gameplay number; actors read it each tick
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.tuning is session-long: apply_gear() bends it in place, never replace it")
var clock := Clock.new():  ## ADR-4: the only writer of the time scale
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.clock is session-long: never replace it")
var display := Display.new():  ## AR8: the scale rule; the only code that touches the stretch or the window
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.display is session-long: never replace it")
var palette := Palettes.new():  ## AR27, Story 1.18 D1: the active zone; UI reads Palettes roles from it
	set(_value):
		@warning_ignore("assert_always_false")
		assert(false, "Game.palette is session-long: set_zone() changes it, never replace it")
## Reads and writes the player's files (AR37). Plumbing, not state, so no guard: tests change its
## `dir`, never the instance.
var store := SaveStore.new()
## The slot this session plays, 1..SaveStore.SLOTS. Only `load_slot()` and `new_game()` change it;
## until the slot picker (Story 1.38) it stays 1.
var active_slot := 1

var _booted := false
var _slot_armed := false  # false until boot(), load_slot() or new_game(): until then a save does nothing (1.21 D7)
var _slot_detached := false  # detach_slot(): a dev session reads and writes no slot file (1.21 D12)
# What the last load or successful resume save held for the keys a progress save must not move
# (D6): {slot = {SlotState.RESUME_KEYS key: value}, dive = DiveState.to_dict() or null}.
var _resume := _fresh_resume()
var _settings_armed := false  # false until load_settings(): until then a change writes nothing
var _settings_write_queued := false
var _overrides := {}  # StringName -> value: session-only values (DevTools' --set); none are ever saved


func _init() -> void:
	clock.name = "Clock"
	add_child(clock)
	display.name = "Display"
	add_child(display)
	settings.changed.connect(_on_settings_changed)


## Once per session, first thing in the entry scene's `_ready()` (D6). Not in this autoload's own
## `_ready()`: autoloads are ready before the test runner exists, so a test could not redirect
## the folder in time, and a missing file would be rewritten into the real user:// on every run.
## Then starts `display` (Story 1.14), after the settings so 7.2's display settings are loaded
## when it reads them; it stays inert under the headless display server (1.14 D2).
## Between the two it loads the active slot, slot 1 until the slot picker (Story 1.38), which arms
## slot saves; a session DevTools detached loads nothing there (`detach_slot()`).
func boot() -> void:
	if _booted:
		return
	_booted = true
	load_settings()
	load_slot(active_slot)
	display.start()


## Loads `settings.json` into `settings` and arms its writes. A missing, corrupt or partly bad file
## gives the defaults for what is unusable, and is rewritten (R15). That is decided by
## `from_dict()`'s result, never by comparing dictionaries: JSON numbers come back as floats, and
## {"a": 1} != {"a": 1.0}.
## A file that can't be opened, or that a newer build wrote, also gives the defaults but is never
## written over: it may be whole (1.4 review; slots have the same rule, `load_slot()`). Writes then
## stay off, so a setting changed in that session lasts only until the game closes.
func load_settings() -> void:
	_settings_armed = false  # from_dict() emits changed for every key; a load is no edit to write
	var read := store.read_settings()
	var stored: Dictionary = read.settings
	var clean := settings.from_dict(stored)
	# Story 1.11 D8: an override outlives the load (DevTools applies --set before boot() runs), and
	# a session with any override writes no settings.json at all, not even a rewrite of a bad file.
	for key: StringName in _overrides:
		settings.set_value(key, _overrides[key])
	if not _overrides.is_empty():
		return
	if read.found == SaveStore.Found.UNREADABLE or read.found == SaveStore.Found.NEWER:
		return
	_settings_armed = true
	if read.found != SaveStore.Found.USABLE or not clean:
		_queue_settings_write()


## A settings value for this session only (DevTools' `--set`, Story 1.11 D8, sonlm 2026-11-19).
## While any override exists the session writes no settings.json at all: not the override, not a
## load's rewrite, not a later change to another key. A dev value must never reach the file the
## release builds read (`user://` is shared by editor runs and exports). Like an unreadable or
## newer file, the cost is that nothing changed this session is saved.
func override_setting(key: StringName, v: Variant) -> void:
	assert(Settings.is_valid(key, v), "Game.override_setting: %s is not valid for '%s'" % [v, key])
	if _overrides.is_empty():
		Log.info(Log.SAVE, "settings: overridden for this session; settings.json is not written")
	_overrides[key] = v
	_settings_armed = false  # a write already queued checks this and does nothing
	settings.set_value(key, v)


## Slot `n` into `slot` and `dive`, in place; then it is the active slot and saves are armed.
## Whatever it finds, `slot` and `dive` are left defined (R15):
## - USABLE: the file's values, with the default for any bad field (one warning when anything was
##   bad, one when the `.bak` had to be used). A file with no dive snapshot starts a fresh dive at
##   the slot's resume point (D5).
## - MISSING: the defaults, silently: a first launch.
## - CORRUPT, UNREADABLE, NEWER: the defaults and one warning. The files are left as they are, and
##   every save then fails (the store refuses to write over them) until `new_game()`.
## Mid-session the caller rebuilds the room afterwards (Story 1.33, its first caller outside boot).
func load_slot(n: int) -> SaveStore.Found:
	if _slot_detached:
		slot.reset()
		dive.reset()
		_resume = _fresh_resume()
		return SaveStore.Found.MISSING
	var read := store.read_slot(n)
	active_slot = n
	_slot_armed = true
	var has_dive := false
	if read.found == SaveStore.Found.USABLE:
		var clean := slot.from_dict(read.slot)
		if read.dive is Dictionary:
			has_dive = true
			clean = dive.from_dict(read.dive) and clean
		else:
			dive.reset()
			dive.set_respawn(slot.resume_room, slot.resume_entry)
		if read.from_bak:
			push_warning("Game: slot %d loaded from its backup (%s)" % [n, read.why])
		if not clean:
			push_warning("Game: slot %d had missing or bad values; the defaults were used for them" % n)
		if clean and not read.from_bak:
			Log.info(Log.SAVE, "slot %d loaded" % n)
	else:
		slot.reset()
		dive.reset()
		if read.found != SaveStore.Found.MISSING:
			push_warning("Game: slot %d can't be loaded (%s); playing from a new game and leaving the files as they are" % [n, read.why])
	_resume = {slot = _resume_part(slot.to_dict()), dive = dive.to_dict() if has_dive else null}
	return read.found


## The resume save (R14): a station rest, arriving home, a quit at a lit anchor (their callers
## arrive in Stories 1.24, 1.34 and E5). The slot's resume point follows the dive's respawn point
## (D5), and the dive is written whole, so a load wakes the player there with what they carried.
func save_now() -> Error:
	if not _slot_armed:
		return ERR_UNCONFIGURED
	slot.set_resume(dive.respawn_room, dive.respawn_entry)
	return _write_slot(slot.to_dict(), dive.to_dict(), true)


## The progress save (R14): a difficulty change, a purchase, a story flag, a phase checkpoint, a
## boss defeat. Live progress, but where a load wakes the player and what they carried stay as the
## last resume save left them (D6); "dive": null when this session has none yet.
func save_progress() -> Error:
	if not _slot_armed:
		return ERR_UNCONFIGURED
	var slot_part := slot.to_dict()
	for key in SlotState.RESUME_KEYS:
		slot_part[key] = _resume.slot[key]
	return _write_slot(slot_part, _resume.dive, false)


## E1's one progress moment (Options calls it in Story 1.36). A command, not a subscription to
## `slot.difficulty_changed`: a load and a reset emit that too, and neither is a change to save.
func set_difficulty(tier: StringName) -> void:
	var before := slot.difficulty
	slot.set_difficulty(tier)
	if slot.difficulty != before:
		save_progress()


## A new game in slot `n`, saved at once. It is the only way to write over a damaged or newer
## slot: the old files go first, so an overwritten game's `.bak` can never load later. Its callers
## arrive in Stories 1.33 / 1.38; mid-session they rebuild the room afterwards.
func new_game(n: int, tier: StringName = SlotState.DEFAULT_DIFFICULTY) -> Error:
	var err := OK if _slot_detached else store.delete_slot(n)
	slot.reset()
	dive.reset()
	slot.set_difficulty(tier)
	_resume = _fresh_resume()
	if _slot_detached:
		return ERR_UNCONFIGURED
	active_slot = n
	_slot_armed = true
	if err != OK:
		# An old file is still there, so the new game is not what the slot holds: a failed save.
		push_warning("Game: slot %d's old files can't be removed (%s); the new game is not saved" % [n, error_string(err)])
		save_failed.emit(n, err)
		return err
	return save_now()


## Removes slot `n`'s files (the slot picker's delete, Story 1.38). Deleting the active slot also
## drops what its last resume save held, so a later progress save can't bring it back.
func delete_slot(n: int) -> Error:
	if _slot_detached:
		return ERR_UNCONFIGURED
	var err := store.delete_slot(n)
	if n == active_slot:
		_resume = _fresh_resume()
	return err


## For the rest of the process no command here reads or writes a slot file (D12, sonlm
## 2026-11-25): DevTools calls it for `--room`, `--chain`, `--hp` and `--perf`, before `boot()`.
## The same rule as `override_setting()`: a dev value must never reach the file a normal run
## reads (`user://` is shared by editor runs and exports). `load_slot()` then gives the defaults
## and `new_game()` only resets; neither arms, so `boot()` needs no branch.
func detach_slot() -> void:
	if _slot_detached:
		return
	_slot_detached = true
	_slot_armed = false
	Log.info(Log.SAVE, "slot: detached for this session; no slot file is read or written")


## Every test that touches `Game` ends with this: defaults back on the same instances, settings
## writes and slot saves disarmed, overrides dropped, the slot attached again and the store pointed
## home, so nothing reaches the player's files. A test that wants a real save points `store.dir`
## at a temp folder and calls `load_slot(1)` or `new_game(1)` (1.21 D7). Leaves `_booted` alone:
## only `test_state` and `test_saves` boot, on a temp folder, as their last case, and each test
## file runs in its own process.
func reset_for_tests() -> void:
	_settings_armed = false
	_slot_armed = false
	_slot_detached = false
	active_slot = 1
	_overrides.clear()
	settings.reset()
	slot.reset()
	dive.reset()
	tuning.apply_gear([])
	clock.clear()
	palette.reset()
	_resume = _fresh_resume()
	store.dir = SaveStore.DEFAULT_DIR
	store.version = Migrations.VERSION  # a test of the migration path may have changed these two
	store.steps = Migrations.steps()


func _on_settings_changed(_key: StringName) -> void:
	if _settings_armed:
		_queue_settings_write()


## At most one write per frame, with the latest values: two quick changes write once.
func _queue_settings_write() -> void:
	if _settings_write_queued:
		return
	_settings_write_queued = true
	_write_settings.call_deferred()


func _write_settings() -> void:
	_settings_write_queued = false
	if not _settings_armed:  # reset_for_tests() may have disarmed writes after the queue
		return
	var err := store.write_settings(settings.to_dict())
	if err != OK:
		# An environment error (Architecture → Error Handling): warn and play on, never crash or
		# pause. The value stays set for this session.
		push_warning("Game: settings not saved to %s (%s)" % [store.settings_path(), error_string(err)])
		settings_save_failed.emit(err)


## One slot file: `meta` is the live slot's line for the picker plus the time of the save (whole
## Unix seconds; Story 1.38's "most recent slot" compares it). `resume`: a resume save, which on
## success becomes what later progress saves keep.
func _write_slot(slot_part: Dictionary, dive_part: Variant, resume: bool) -> Error:
	var meta := slot.meta()
	meta["saved_at"] = int(Time.get_unix_time_from_system())
	var err := store.write_slot(active_slot, {"version": Migrations.VERSION, "meta": meta, "slot": slot_part, "dive": dive_part})
	if err != OK:
		# An environment error (Architecture → Error Handling): warn and play on, never crash or
		# pause. A failed resume save leaves `_resume` alone: the file still holds the old one.
		push_warning("Game: slot %d not saved to %s (%s)" % [active_slot, store.slot_path(active_slot), error_string(err)])
		save_failed.emit(active_slot, err)
		return err
	if resume:
		_resume = {slot = _resume_part(slot_part), dive = dive_part}
	save_succeeded.emit(active_slot)
	return OK


## What a slot that never had a resume save holds: a new slot's resume keys and no dive.
static func _fresh_resume() -> Dictionary:
	return {slot = _resume_part(SlotState.new().to_dict()), dive = null}


static func _resume_part(slot_dict: Dictionary) -> Dictionary:
	var out := {}
	for key in SlotState.RESUME_KEYS:
		out[key] = slot_dict[key]
	return out
