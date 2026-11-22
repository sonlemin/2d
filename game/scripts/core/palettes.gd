class_name Palettes
extends RefCounted
## The one home for UI colours (AR27, DESIGN Colors; Story 1.18 D1, D3): the two reserved colours,
## and per zone its four world colours, its six UI roles (UX-DR7 overrides applied) and its
## edge-cue glow floor. Every hex is DESIGN.md's token; test_palettes holds each to DESIGN's
## tables and contrast floors with its own copy, never reading them back from here.
## The statics read the tables. The one instance is `Game.palette`, the active zone: UI asks it
## `color(role)` and re-reads on `changed`, never caching a colour by zone id, because E4's 500 ms
## cross-fade will emit `changed` with blended colours (D2). Menus outside play (title, slot
## picker, gate) read `role_in(DEFAULT_ZONE, …)` (UX D13: they use Dusk).
## Presentation, not save data: no to_dict(). The hub and Layer 2 palettes (UX-DR10, E5/E6) are a
## new ZONES row, and the test checks it against the same floors.

signal changed  ## the active colours changed: a zone change now, a cross-fade step from E4

enum Role { HP, LABEL, EMPTY, RULE, SURFACE, GUTTER }

const AMBER := Color("#ffd27a")  ## chain-amber (UX-DR1): only the player's light, in every zone
const RED := Color("#d9473f")  ## predator-red (UX-DR2): only light-hunting danger, on shapes, never text
const DEFAULT_ZONE := &"dusk"  ## UX D13: menus outside play use Dusk; reset() comes back here

## Zone id -> {world: index 0-3 (UX-DR3), roles: in Role order (UX-DR5, UX-DR6), glow: the edge cue's
## glow floor (UX-DR9)}. In DESIGN order, which zones() keeps. An override names its base index and
## the smallest whole-percent blend toward index 3 that passes both floors (UX-DR7).
const ZONES := {
	&"dusk": {
		world = [
			Color("#2b1d14"),  # zone-dusk-0
			Color("#6b4a2f"),  # zone-dusk-1
			Color("#b08a5a"),  # zone-dusk-2
			Color("#d8c3a0"),  # zone-dusk-3
		],
		roles = [
			Color("#d8c3a0"),  # HP: ui-hp-dusk, index 3
			Color("#b08a5a"),  # LABEL: ui-label-dusk, index 2, passes as is (UX-DR7)
			Color("#836548"),  # EMPTY: ui-empty-dusk, index 1 +22% toward index 3 (UX-DR7)
			Color("#6b4a2f"),  # RULE: ui-rule-dusk, index 1, decorative (DESIGN A15)
			Color("#2b1d14"),  # SURFACE: zone-dusk-0
			Color("#18100b"),  # GUTTER: gutter-dusk, index 0 x 0.55 (DESIGN A2, UX-DR4)
		],
		glow = Color("#bb4038"),  # edge-cue glow floor: index 0 +83% toward predator-red, 3.03:1 (UX-DR9)
	},
	&"umber": {
		world = [
			Color("#1e1714"),  # zone-umber-0
			Color("#4a3a33"),  # zone-umber-1
			Color("#7d6a5c"),  # zone-umber-2
			Color("#a99a8c"),  # zone-umber-3
		],
		roles = [
			Color("#a99a8c"),  # HP: ui-hp-umber, index 3
			Color("#8f7e70"),  # LABEL: ui-label-umber, index 2 +41% toward index 3 (UX-DR7)
			Color("#726258"),  # EMPTY: ui-empty-umber, index 1 +42% toward index 3 (UX-DR7)
			Color("#4a3a33"),  # RULE: ui-rule-umber, index 1, decorative (DESIGN A15)
			Color("#1e1714"),  # SURFACE: zone-umber-0
			Color("#110d0b"),  # GUTTER: gutter-umber, index 0 x 0.55, rounded half up (DESIGN A2, UX-DR4)
		],
		glow = Color("#b23d36"),  # edge-cue glow floor: index 0 +79% toward predator-red, 3.04:1 (UX-DR9)
	},
	&"violet": {
		world = [
			Color("#0d0b14"),  # zone-violet-0
			Color("#2a2440"),  # zone-violet-1
			Color("#4f5d75"),  # zone-violet-2
			Color("#a9b4c2"),  # zone-violet-3
		],
		roles = [
			Color("#a9b4c2"),  # HP: ui-hp-violet, index 3
			Color("#6e7b8f"),  # LABEL: ui-label-violet, index 2 +34% toward index 3 (UX-DR7)
			Color("#5c5c73"),  # EMPTY: ui-empty-violet, index 1 +39% toward index 3 (UX-DR7)
			Color("#2a2440"),  # RULE: ui-rule-violet, index 1, decorative (DESIGN A15)
			Color("#0d0b14"),  # SURFACE: zone-violet-0
			Color("#07060b"),  # GUTTER: gutter-violet, index 0 x 0.55 (DESIGN A2, UX-DR4)
		],
		glow = Color("#a63834"),  # edge-cue glow floor: index 0 +75% toward predator-red, 3.01:1 (UX-DR9)
	},
}

var _zone: StringName = DEFAULT_ZONE


## The colour of `role` in `zone`.
static func role_in(zone: StringName, role: Role) -> Color:
	assert(has_zone(zone), "Palettes: unknown zone '%s'" % zone)
	return ZONES[zone].roles[role]


## World colour `index` (0 darkest, 3 lightest) of `zone`.
static func world_in(zone: StringName, index: int) -> Color:
	assert(has_zone(zone), "Palettes: unknown zone '%s'" % zone)
	assert(index >= 0 and index < 4, "Palettes: world index %d is not 0-3" % index)
	return ZONES[zone].world[index]


## The weakest edge-cue glow that still reaches the 3:1 shape floor on `zone`'s index 0 (UX-DR9).
static func glow_floor(zone: StringName) -> Color:
	assert(has_zone(zone), "Palettes: unknown zone '%s'" % zone)
	return ZONES[zone].glow


## Every zone id, in DESIGN order. The room validator's list too (D9: zone ids have one home).
static func zones() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(ZONES.keys())
	return out


static func has_zone(zone: StringName) -> bool:
	return ZONES.has(zone)


func zone() -> StringName:
	return _zone


## The active zone's colour for `role`.
func color(role: Role) -> Color:
	return role_in(_zone, role)


## Snaps to `zone` (E1: a room cut; E4 adds the cross-fade). `changed` fires only on a real change,
## so a same-zone room swap redraws nothing.
func set_zone(zone: StringName) -> void:
	assert(has_zone(zone), "Palettes.set_zone: unknown zone '%s'" % zone)
	if zone == _zone:
		return
	_zone = zone
	changed.emit()


func reset() -> void:
	set_zone(DEFAULT_ZONE)
