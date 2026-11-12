extends Node
## The `Game` autoload (AR9, AR11): references to session-long state and the commands that load
## it, never rules. It keeps the same instances all session and resets them in place, because
## subscribers hold on to them: gear changes call `tuning.apply_gear()`, never a new Tuning, and
## replacing a ref is an assert (Story 1.4 D7). `devices` arrives with Story 1.37.
## Starting up touches no file (D6): the entry scene calls `boot()` once, which loads
## `settings.json` and arms its writes. Tests never boot; a test that checks the file points
## `store.dir` at a temp folder first and ends with `reset_for_tests()`.

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
## Reads and writes the player's files (AR37). Plumbing, not state, so no guard: tests change its
## `dir`, never the instance.
var store := SaveStore.new()

var _booted := false
var _settings_armed := false  # false until load_settings(): until then a change writes nothing
var _settings_write_queued := false


func _init() -> void:
	clock.name = "Clock"
	add_child(clock)
	settings.changed.connect(_on_settings_changed)


## Once per session, first thing in the entry scene's `_ready()` (D6). Not in this autoload's own
## `_ready()`: autoloads are ready before the test runner exists, so a test could not redirect
## the folder in time, and a missing file would be rewritten into the real user:// on every run.
## Story 1.21 adds: load slot 1 if present.
func boot() -> void:
	if _booted:
		return
	_booted = true
	load_settings()


## Loads `settings.json` into `settings` and arms its writes. A missing, corrupt or partly bad file
## gives the defaults for what is unusable, and is rewritten (R15). That is decided by
## `from_dict()`'s result, never by comparing dictionaries: JSON numbers come back as floats, and
## {"a": 1} != {"a": 1.0}.
func load_settings() -> void:
	_settings_armed = false  # from_dict() emits changed for every key; a load is no edit to write
	var stored: Variant = store.read_settings()
	var clean := settings.from_dict(stored if stored is Dictionary else {})
	_settings_armed = true
	if stored == null or not clean:
		_queue_settings_write()


## Every test that touches `Game` ends with this: defaults back on the same instances, settings
## writes disarmed and the store pointed home, so nothing reaches the player's files. Leaves
## `_booted` alone: tests never boot.
func reset_for_tests() -> void:
	_settings_armed = false
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
