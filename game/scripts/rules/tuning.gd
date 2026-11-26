class_name Tuning
extends RefCounted
## The gameplay numbers that gear, assists and playtests bend, in one pure table (AR15). The
## session's instance lives in `core/game.gd`. Actors read `f(&"key")` where they use a value: a
## countdown may start from the current value, but no value is kept for reuse on a later frame.
## Gear bends the values through `apply_gear()` (AR16): set → add → mul, whatever order the gear
## comes in. Change a value → update the matching GDD table.
##
## The consts are the playtested M1 values (Story 1.3 moved them here from the actors' exports)
## unless a comment says otherwise. Not here, by design (Story 1.3 D1):
## - the chain curve, which stays in ChainState;
## - presentation numbers (camera, light easing, eye animation), local consts on their actors;
## - the sensing rule, which moves to Sensing in Story 1.20;
## - the Light tap window, which is a Settings value (Story 1.8), never a tuning key.
## Not here yet: M1 literals that never were exports, such as the crawler's 400 px/s fall cap and
## the lurker's ×2 brake once it loses you. The story that needs to bend one moves it here.

signal changed

# --- Movement (GDD Movement (M1), FR1) ---
const RUN_SPEED := 110.0  ## px/s; top run speed, on the ground and in the air (GDD Movement, FR1; M1 player.run_speed). M1 value, unchanged.
const RUN_ACCEL := 900.0  ## px/s²; how fast the run reaches top speed on the ground (GDD Movement "ground accel", FR1; M1 player.run_accel). M1 value, unchanged.
const AIR_ACCEL := 1500.0  ## px/s²; snappier steering in the air, to line up the next pogo (GDD Movement, FR1; M1 player.air_accel). M1 value, unchanged.
const GRAVITY := 900.0  ## px/s²; pull while rising, which with JUMP_VELOCITY sets the ≈ 60 px apex (GDD Movement, FR1; M1 player.gravity). M1 value, unchanged.
const MAX_FALL := 210.0  ## px/s terminal fall; slowed so a dive reads and ledges come in time (GDD Movement, FR1; M1 player.max_fall). Was 330.
const FALL_GRAVITY_SCALE := 0.6  ## × gravity while falling; rising is unchanged, so a dive floats (GDD Movement, FR1; M1 player.fall_gravity_scale). M1 value, unchanged.
const JUMP_VELOCITY := -330.0  ## px/s launch; apex ≈ 60 px (3.75 tiles) with GRAVITY (GDD Movement, FR1; M1 player.jump_velocity). Was -270 (apex ≈ 40 px).
const JUMP_CUT := 0.45  ## × upward velocity on an early Jump release; a tap is a short hop, a hold the full jump (GDD Movement, FR1; M1 player.jump_cut). M1 value, unchanged.
const COYOTE_TIME := 0.08  ## s; a jump still counts this long after leaving a ledge, so a late press isn't eaten (GDD Movement, FR1; M1 player.coyote_time). M1 value, unchanged.
const JUMP_BUFFER := 0.10  ## s; an early Jump press waits this long for the ground instead of being lost (GDD Movement, FR1; M1 player.jump_buffer). M1 value, unchanged.

# --- Dash (GDD Movement "Air dash", FR2) ---
const DASH_SPEED := 260.0  ## px/s; a horizontal burst that ignores gravity, once per airtime, refilled by a pogo hit (GDD Movement "Air dash", FR2; M1 player.dash_speed). M1 value, unchanged.
const DASH_TIME := 0.12  ## s on the dash timer; player.gd checks the timer before counting it down, so a dash runs 9 ticks (8 without gravity), 0.15 s and ≈ 39 px at DASH_SPEED, the GDD's length. CP1 gate (1.15, sonlm): keep the felt dash; the code stays as it is so the dash plays identically, and smoke_player_input pins the ticks (GDD Movement "Air dash", FR2; M1 player.dash_time). M1 value, unchanged.

# --- Cling (GDD Wall cling (M1) and the chain-end table, FR6/FR7) ---
const CLING_GRACE := 1.0  ## s of paused chain per cling; a pogo hit refills it (GDD Wall cling, FR6/FR7; M1 player.cling_time). Silk Grip +0.25 (E6). M1 value, unchanged.
const CLING_SLIDE := 18.0  ## px/s slow slide while clinging; clinging never climbs (GDD Wall cling, FR7; M1 player.cling_slide). Steady Grip sets 10 (E5). M1 value, unchanged.
const WALL_KICK_X := 150.0  ## px/s; push away from the wall when Jump is released mid-cling (GDD Wall cling, FR7; M1 player.wall_kick.x). M1 value, unchanged.
const WALL_KICK_Y := -260.0  ## px/s; the upward part of the same kick (GDD Wall cling, FR7; M1 player.wall_kick.y). M1 value, unchanged.
const KICK_LOCK := 0.15  ## s; no steering after a kick, so it actually carries you off the wall (GDD Wall cling, FR7; M1 player.kick_lock). M1 value, unchanged.

# --- Attack (GDD Attack, pogo and chain (M1), FR4) ---
const POGO_VELOCITY := -300.0  ## px/s bounce on a pogo hit; apex ≈ 50 px, hang time to steer to the next target (GDD Attack, FR4; M1 player.pogo_velocity). Was -260.
const SLASH_ACTIVE := 0.12  ## s; how long a ground slash can hit (GDD Attack "Slash active 0.12 s", FR4; M1 player.swing_active). M1 value, unchanged.
const POGO_ARMED := 0.22  ## s; how long a pogo can hit, longer than a slash so a slightly early press still connects (GDD Attack "armed 0.22 s", FR4; M1 player.air_swing_active). M1 value, unchanged.
const ATTACK_COOLDOWN := 0.22  ## s; wait before the next attack, slash and pogo alike (GDD Attack "cooldown 0.22 s", FR4; M1 player.swing_cooldown). M1 value, unchanged.
const HITSTOP := 0.075  ## s of real time; the freeze frame on each pogo hit, the chain's hit feedback (GDD Attack "75 ms", FR4; M1 player.hitstop). Was 0.045.

# --- Damage (GDD Health and damage (M2), Story 1.19) ---
const KNOCKBACK_X := 150.0  ## px/s; push away from a crawler on contact (GDD Health and damage; M1 player.knockback.x). M1 value, unchanged.
const KNOCKBACK_Y := -150.0  ## px/s; the upward part of the same knock (GDD Health and damage; M1 player.knockback.y). M1 value, unchanged.
const INVULN_TIME := 0.6  ## s; invulnerable and blinking after a hit, so one contact can't hit twice in a row (GDD Health and damage, Combat "Defense"; M1 player.invuln_time). M1 value, unchanged.
const BANK_HEAL_MIN := 10.0  ## links; a chain banked safely at this length or more heals 1 HP, so a long chain is also a way back from a hit (GDD Health and damage "+1 HP when you bank a chain of 10 or more", FR12; [ASSUMPTION: playtest]). GDD Health; new in M2.

# --- Crawler (GDD Combat System, enemy table, FR58) ---
const CRAWLER_WALK_SPEED := 25.0  ## px/s; a walker's patrol pace along its ledge; no number in the GDD yet (GDD Combat, walker row; M1 crawler.walk_speed). M1 value, unchanged.
const CRAWLER_GRAVITY := 900.0  ## px/s² for walkers; not in a GDD table yet (M1 crawler.gravity). M1 value, unchanged.
const CRAWLER_HOVER_DRIFT := 10.0  ## px; amplitude of a hoverer's side-to-side drift, so a dive can string them together (GDD Combat "drifts 10 px", FR58; M1 crawler.hover_drift). M1 value, unchanged.
const CRAWLER_HOVER_PERIOD := 2.4  ## s; one drift cycle, its phase set by position so the shaft plays the same every time (GDD Combat "over 2.4 s", FR58; M1 crawler.hover_period). M1 value, unchanged.

# --- Lurker (GDD Predators: Lurker (M1)) ---
const LURKER_TELEGRAPH_TIME := 0.9  ## s of eyes-open warning before a hunt; never below 0.75 (Pillar 2, GDD Lurker; Spec.TELEGRAPH_MIN from 1.9; M1 lurker.telegraph_time). M1 value, unchanged.
const LURKER_LOSE_TRACK_TIME := 0.6  ## s; a lurker that lost you waits this long, harmless, before it heads home (GDD Lurker "waits 0.6 s"; M1 lurker.lose_track_time). M1 value, unchanged.
const LURKER_HUNT_SPEED := 95.0  ## px/s; the hunt, straight at you and through walls (GDD Lurker "95 px/s"; M1 lurker.hunt_speed). M1 value, unchanged.
const LURKER_HUNT_ACCEL := 220.0  ## px/s² toward the hunt speed; it brakes at twice this once it loses you; not in the GDD (M1 lurker.hunt_accel). M1 value, unchanged.
const LURKER_RETURN_SPEED := 40.0  ## px/s; the slow drift back home after a hunt; not in the GDD (M1 lurker.return_speed). M1 value, unchanged.

# --- Economy (GDD Economy, FR24) ---
const CACHE_RADIUS := 80.0  ## px; the Ember Cache's glow and the light predators sense, so at ≥ 80 px (the notice floor) it wakes lurkers like the player's light does (GDD Economy "Ember Cache glow", FR24; [ASSUMPTION: tuned at the CP2 gate, 1.30]). GDD Economy; new in M2.

## Every key `f()` knows, with its base value.
const BASE := {
	&"run_speed": RUN_SPEED,
	&"run_accel": RUN_ACCEL,
	&"air_accel": AIR_ACCEL,
	&"gravity": GRAVITY,
	&"max_fall": MAX_FALL,
	&"fall_gravity_scale": FALL_GRAVITY_SCALE,
	&"jump_velocity": JUMP_VELOCITY,
	&"jump_cut": JUMP_CUT,
	&"coyote_time": COYOTE_TIME,
	&"jump_buffer": JUMP_BUFFER,
	&"dash_speed": DASH_SPEED,
	&"dash_time": DASH_TIME,
	&"cling_grace": CLING_GRACE,
	&"cling_slide": CLING_SLIDE,
	&"wall_kick_x": WALL_KICK_X,
	&"wall_kick_y": WALL_KICK_Y,
	&"kick_lock": KICK_LOCK,
	&"pogo_velocity": POGO_VELOCITY,
	&"slash_active": SLASH_ACTIVE,
	&"pogo_armed": POGO_ARMED,
	&"attack_cooldown": ATTACK_COOLDOWN,
	&"hitstop": HITSTOP,
	&"knockback_x": KNOCKBACK_X,
	&"knockback_y": KNOCKBACK_Y,
	&"invuln_time": INVULN_TIME,
	&"bank_heal_min": BANK_HEAL_MIN,
	&"crawler_walk_speed": CRAWLER_WALK_SPEED,
	&"crawler_gravity": CRAWLER_GRAVITY,
	&"crawler_hover_drift": CRAWLER_HOVER_DRIFT,
	&"crawler_hover_period": CRAWLER_HOVER_PERIOD,
	&"lurker_telegraph_time": LURKER_TELEGRAPH_TIME,
	&"lurker_lose_track_time": LURKER_LOSE_TRACK_TIME,
	&"lurker_hunt_speed": LURKER_HUNT_SPEED,
	&"lurker_hunt_accel": LURKER_HUNT_ACCEL,
	&"lurker_return_speed": LURKER_RETURN_SPEED,
	&"cache_radius": CACHE_RADIUS,
}

## Rule switches gear can turn on (AR16). Quick Wick's instant Snuff is read from E5/E6.
const FLAGS: Array[StringName] = [&"instant_snuff"]

## The fixed order modifiers apply in (AR16), so the result never depends on gear order.
const OPS: Array[StringName] = [&"set", &"add", &"mul"]

var _values := {}  # StringName -> float, BASE with the owned gear applied
var _flags := {}  # StringName -> true, for each flag the owned gear switches on


func _init() -> void:
	apply_gear([])


## Recomputes every value from BASE and the owned gear, then emits `changed` once. `[]` is the
## reset in place: there is no to_dict(), because the save holds the gear ids, not these values.
## `table` is Gear.TABLE except in tests, which inject fixture rows. Ids not in the table are ignored.
## Values are computed here, once, so `f()` stays a lookup: actors call it many times per tick.
func apply_gear(gear_ids: Array[StringName], table: Array[Dictionary] = Gear.TABLE) -> void:
	# Every row, owned or not, and before the filter reads `id`: the session's instance applies []
	# at boot, so a bad Gear.TABLE row fails the first debug run, not the day someone owns it.
	for row in table:
		_check_row(row)
	var rows := table.filter(func(row: Dictionary) -> bool: return StringName(row.get("id", &"")) in gear_ids)
	_values = BASE.duplicate()
	_flags = {}
	var was_set := {}
	for op in OPS:
		for row in rows:
			if StringName(row.op) != op:
				continue
			var stat := StringName(row.stat)
			if op == &"set":
				# Two sets on one stat would make the result depend on gear order (AR16).
				assert(not was_set.has(stat), "Tuning: two gear rows set '%s'" % stat)
				was_set[stat] = true
				_values[stat] = float(row.value)
			elif op == &"add":
				_values[stat] += float(row.value)
			else:
				_values[stat] *= float(row.value)
	for row in rows:
		if StringName(row.op) == &"flag":
			_flags[StringName(row.stat)] = true
	changed.emit()


## The current value of a tuning key. An unknown key is a programmer error.
func f(key: StringName) -> float:
	assert(_values.has(key), "Tuning: unknown key '%s'" % key)
	return _values[key]


## Whether owned gear switches on this rule. An unknown flag is a programmer error.
func flag(key: StringName) -> bool:
	assert(key in FLAGS, "Tuning: unknown flag '%s'" % key)
	return _flags.has(key)


## A gear row is a code table, so a malformed one is a programmer error (Story 1.3 D5).
func _check_row(row: Dictionary) -> void:
	assert(row.has("id") and row.has("stat") and row.has("op"), "Tuning: a gear row needs id, stat and op: %s" % row)
	var op := StringName(row.op)
	var stat := StringName(row.stat)
	if op == &"flag":
		assert(stat in FLAGS, "Tuning: gear '%s' flags an unknown rule '%s'" % [row.id, stat])
		return
	assert(op in OPS, "Tuning: gear '%s' has an unknown op '%s'" % [row.id, op])
	assert(BASE.has(stat), "Tuning: gear '%s' bends an unknown key '%s'" % [row.id, stat])
	assert(row.get("value") is float or row.get("value") is int, "Tuning: gear '%s' needs a number value" % row.id)
