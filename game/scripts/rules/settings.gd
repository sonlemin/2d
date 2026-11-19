class_name Settings
extends RefCounted
## Global, per-machine settings (AR14): one set for every slot, kept between launches. Read a value
## directly (`settings.brightness`); write it only through `set_value()`, which emits
## `changed(key)` (AR18). The session's instance lives in `core/game.gd`.
## rules/ does no file I/O (R15): `core/save_store.gd` persists these as `settings.json`, and the
## session's instance decides when to write.
## Brightness (Story 1.4) and the Light tap window (Story 1.8) exist so far. Each story adds its own key as one SCHEMA entry plus
## a typed var of the same name, and needs no version bump: a missing key takes its default.

signal changed(key: StringName)

## Every key, its default and the values it may take; a later story adds its key here plus a typed
## var of the same name.
const SCHEMA := {
	&"brightness": {default = 1, choices = [0, 1, 2, 3]},
	&"light_tap_window": {default = 0.12, choices = [0.12, 0.2, 0.3]},
}

## Index of the world's ambient level (4 levels, UX A1 / R1); 1 is the M1 default (the M1 shaft's
## ambient_index). It changes only the world's ambient level, never light radii or what predators
## sense (architecture → UI → Brightness).
var brightness := 1
## s: a Light release inside this window is a tap (Flare Toss), a hold past it is Snuff, so a tap
## never breaks the chain (FR9, UX-DR119; M1's 0.12 s Snuff hold is the default). Read by
## PlayerInput at each tick; Options > Accessibility shows it from Story 1.36.
var light_tap_window := 0.12


func set_value(key: StringName, v: Variant) -> void:
	assert(SCHEMA.has(key), "Settings: unknown key '%s'" % key)
	assert(is_valid(key, v), "Settings: %s is not a valid value for '%s'" % [v, key])
	if get(key) == v:
		return
	set(key, v)
	changed.emit(key)


## JSON-ready (D4), with String keys as SlotState and DiveState give; SaveStore wraps it as
## {"version": 1, "settings": {…}}.
func to_dict() -> Dictionary:
	var d := {}
	for key: StringName in SCHEMA:
		d[String(key)] = get(key)
	return d


## File data may be hand-edited or corrupt, an environment error, so this never asserts (D3): a
## missing or bad key takes its default, and unknown keys are ignored. Returns true when every key
## was present and valid; the caller rewrites the file when it isn't. Emits changed for every key,
## so a subscriber always refreshes after a load (D2).
func from_dict(d: Dictionary) -> bool:
	var clean := true
	for key: StringName in SCHEMA:
		var default: Variant = SCHEMA[key].default
		var v: Variant = d.get(key)  # a StringName lookup also finds the String keys JSON gives back
		# JSON numbers come back as floats: a whole one is the int it was written as.
		if typeof(v) == TYPE_FLOAT and typeof(default) == TYPE_INT and v == floorf(v):
			v = int(v)
		if v == null or not is_valid(key, v):
			clean = false
			v = default
		set(key, v)
	for key: StringName in SCHEMA:
		changed.emit(key)
	return clean


func reset() -> void:
	for key: StringName in SCHEMA:
		set(key, SCHEMA[key].default)
	for key: StringName in SCHEMA:
		changed.emit(key)


## True when `key` is in `schema` and `v` is one of its choices. The type check comes first, so
## `true` never passes for 1, and 2.0 never passes for 2. `schema` is only ever passed by DevTools'
## `--set` validator and its tests (a fake bool key, Story 1.11 D8); every other caller checks the
## real SCHEMA.
static func is_valid(key: StringName, v: Variant, schema: Dictionary = SCHEMA) -> bool:
	if not schema.has(key):
		return false
	var spec: Dictionary = schema[key]
	return typeof(v) == typeof(spec.default) and v in spec.choices
