class_name Migrations
extends RefCounted
## Save-format migrations (AR37, Story 1.21 D10). Static and pure: `core/save_store.gd` reads a
## file and hands the whole parsed dictionary here.
## `VERSION` is the one home of the slot format's number: the steps and the number change together,
## so they live together. To change the format: bump VERSION, add `migrate_v<N>_to_v<N+1>` here,
## list it in `steps()`, and add a fixture (`tests/fixtures/slot_v<N>.json`) every later build must
## load. Story 1.41 freezes v1; Story 4.1 adds the first step.

## The slot format this build writes.
const VERSION := 1


## {from_version: Callable}: the step that turns a version-N file into N + 1. Each takes the whole
## file dictionary (`version`, `meta`, `slot`, `dive`), since a step may move data between its
## parts, and must leave `version == N + 1`. None yet; E4 adds `1: migrate_v1_to_v2` (Story 4.1).
static func steps() -> Dictionary:
	return {}


## `data` brought from its version up to `to`, one step at a time, on a deep copy: the caller's
## dictionary is never changed. Returns {} when a step is missing or didn't bump the version, and
## the copy as it is when the version is already `to`.
## The caller has already checked that `data.version` is a whole number in 1..to. Steps are looked
## up with int(version): a JSON number is a float, and {1: f}.has(1.0) is false (probed on 4.7.2).
## A passed `to` / `table` is only ever a test's.
static func migrate(data: Dictionary, to: int = VERSION, table: Dictionary = steps()) -> Dictionary:
	var out := data.duplicate(true)
	var v := int(out.get("version", 0))
	while v < to:
		if not table.has(v):
			return {}
		var step: Callable = table[v]
		step.call(out)
		var now: Variant = out.get("version")
		# The type first: comparing a String with a number is a script error on 4.7.2, not false.
		if not (now is int or now is float) or now != v + 1:
			return {}
		v += 1
	return out
