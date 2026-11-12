class_name Log
## The one logger (AR55): prints `[category] message`, silent in release builds.
## Static rather than an autoload, and it depends on nothing, so rules/, tests and boot code can
## all log without `Game`.
## - `Log.info(Log.SAVE, "slot 2 written (%d bytes)" % n)`: milestones only, never per frame.
## - `if Log.enabled(Log.LURKER): Log.debug(Log.LURKER, …)`: hot paths. The guard skips building
##   the message; categories stay off until DevTools reads `--log=` (Story 1.11).
## This is the one script allowed a bare `print(` (the Story 1.9 lint).

const SAVE := &"save"
const ROOM := &"room"
const INPUT := &"input"
const CLOCK := &"clock"
const LURKER := &"lurker"
const WEAVER := &"weaver"
const AUDIO := &"audio"
const UI := &"ui"
const CATEGORIES: Array[StringName] = [SAVE, ROOM, INPUT, CLOCK, LURKER, WEAVER, AUDIO, UI]

static var _debug_on := {}  # StringName -> true


static func info(cat: StringName, msg: String) -> void:
	_check(cat)
	if OS.is_debug_build():
		print(format(cat, msg))


static func debug(cat: StringName, msg: String) -> void:
	if enabled(cat):
		print(format(cat, msg))


## The hot-path guard. The assert is inline, not `_check()`, because release builds strip an
## assert but keep a call: a disabled category costs this call and `OS.is_debug_build()`.
static func enabled(cat: StringName) -> bool:
	assert(cat in CATEGORIES, "Log: unknown category '%s'" % cat)
	return OS.is_debug_build() and _debug_on.has(cat)


static func set_enabled(cats: Array[StringName]) -> void:
	_debug_on.clear()
	for cat in cats:
		_check(cat)
		_debug_on[cat] = true


static func format(cat: StringName, msg: String) -> String:
	return "[%s] %s" % [cat, msg]


## A typo'd category is a programmer error: fail loudly in debug, cost nothing in release.
static func _check(cat: StringName) -> void:
	assert(cat in CATEGORIES, "Log: unknown category '%s'" % cat)
