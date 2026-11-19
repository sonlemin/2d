extends Node
## The `Game` autoload (AR9, AR11): references to session-long state and the commands that load
## it, never rules. It keeps the same instances all session and resets them in place, because
## subscribers hold on to them: gear changes call `tuning.apply_gear()`, never a new Tuning, and
## replacing a ref is an assert (Story 1.4 D7). `devices` arrives with Story 1.37.
## Two refs are child nodes because they need the tree: `clock` (timers) and `display` (the
## window, Story 1.14). Neither holds rule state.
## Starting up touches no file (D6): the entry scene calls `boot()` once, which loads
## `settings.json` and arms its writes. A test never boots against the real folder: one that
## checks the file points `store.dir` at a temp folder first and ends with `reset_for_tests()`.

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
## Reads and writes the player's files (AR37). Plumbing, not state, so no guard: tests change its
## `dir`, never the instance.
var store := SaveStore.new()

var _booted := false
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
## Story 1.21 adds: load slot 1 if present.
func boot() -> void:
	if _booted:
		return
	_booted = true
	load_settings()
	display.start()


## Loads `settings.json` into `settings` and arms its writes. A missing, corrupt or partly bad file
## gives the defaults for what is unusable, and is rewritten (R15). That is decided by
## `from_dict()`'s result, never by comparing dictionaries: JSON numbers come back as floats, and
## {"a": 1} != {"a": 1.0}.
## A file that can't be opened, or that a newer build wrote, also gives the defaults but is never
## written over: it may be whole (1.4 review; Story 1.21 gives slots the same rule). Writes then
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


## Every test that touches `Game` ends with this: defaults back on the same instances, settings
## writes disarmed, overrides dropped and the store pointed home, so nothing reaches the player's
## files. Leaves `_booted` alone: only `test_state` boots, on a temp folder, as its last case, and
## each test file runs in its own process.
func reset_for_tests() -> void:
	_settings_armed = false
	_overrides.clear()
	settings.reset()
	slot.reset()
	dive.reset()
	tuning.apply_gear([])
	clock.clear()
	store.dir = SaveStore.DEFAULT_DIR


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
