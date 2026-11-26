class_name Lurker
extends Area2D
## A predator drawn to light. It waits inside the walls of the dark, unseen.
##
## It senses light only through LightSource + Sensing (AR28, AR29): every lit node in group
## `light_source` (the player's Chain-Light, the Ember Cache (Story 1.22); flares in 1.23), judged by the
## one rule in rules/sensing.gd. It never looks for the player (lint light_query).
## - Notice (wake, and every tick of the telegraph): the light is big enough and near enough, and the
##   lurker sits inside the play rect's notice margin, so the whole warning is seen (Pillar 2; AR20).
## - Hunt: light and distance alone (GDD Hunt; Story 1.20 Q1, sonlm): once it has telegraphed, a
##   hunt isn't dropped because the view scrolled. Landing, Snuff and cling still save you: they
##   shrink the light. Re-sensing inside the wait resumes the hunt with no telegraph (Q2, M1).
## - Retarget (FR16, FR21): it goes for the largest light it senses, a tie going to a non-player
##   light. Onto the player always costs a full telegraph; off the player onto a decoy costs none.
##   Identity is the node, so a new life's light is a new target. A hunt switches onto a player light
##   only where it notices it: off screen it stays on the decoy (_hunt_pick(); review of 1.20, sonlm).
## - Stir: a light it would sense while it sits off screen (or in the notice margin) raises `stir`,
##   which the edge cue (1.27) and the stirring sound (E3) read. A stirring lurker never hunts.
##
## Pillar 2 (every death teaches): it always telegraphs. Its eyes open and pulse for the telegraph
## time (Tuning lurker_telegraph_time) before it moves, and it damages only while `monitorable`, which
## is true only while it hunts a player light it senses (_harmful(), D7).

enum State { IDLE, TELEGRAPH, HUNT, RETURN }

# Telegraph, hunt and return numbers are Game.tuning keys (lurker_*, AR15); the telegraph's
# >= 0.75 s floor (Pillar 2) is Spec.TELEGRAPH_MIN. The sensing numbers are the GDD's, in Sensing.
# Presentation, which no system bends:
const GLOW_ENERGY := 1.3  ## red light the eyes cast on the wall around them; presentation (M1 lurker.glow_energy).
const EYE_OPEN_TIME := 0.2  ## s for the eyes to open (squash -> full) at the start of the telegraph; presentation (M1 lurker.eye_open_time).
const STIR_STEP_TIME := 0.35  ## s between two steps of `stir` (closed, half, open), in every state: 1.27's eye and glow draw it, so it changes at most 1 / 0.35 ≈ 2.9 times a second, under NFR8's 3 flashes/s (D9); presentation, sonlm 2026-11-22 (Q3), reviewed at the CP2 gate (1.30).
## The stir clock sums 1/60 s ticks, which lands a hair under 0.35 s on the 21st: this keeps the step
## on that tick, not the 22nd.
const STIR_CLOCK_SLACK := 1e-6

var state: State = State.IDLE
## The light it telegraphs at or hunts; null in IDLE and RETURN once a tick has found nothing.
var target: LightSource
## 0 closed, 1 half-open, 2 open: how far off-screen stirring has opened the eye (AC5, D9).
var stir := 0
## True on a tick when, in IDLE or RETURN, some lit light stirs it (Sensing.can_stir).
var stirring := false
var _timer := 0.0
var _unsensed := 0.0
var _velocity := Vector2.ZERO
var _home := Vector2.ZERO
var _t := 0.0
var _stir_clock := STIR_STEP_TIME  # s since `stir` last stepped; starts full, so the first step is at once

@onready var _eyes: Sprite2D = $Eyes
@onready var _body_sprite: Sprite2D = $Sprite
@onready var _glow: PointLight2D = $Glow


func _ready() -> void:
	add_to_group("predator")
	_home = global_position
	_eyes.modulate.a = 0.0
	monitorable = false  # harmless until it hunts: contact hurts only after a telegraph


## The Health.CAUSES id a hunting lurker hurts with (2 HP). The player's poll asks only while
## `monitorable` is true (Pillar 2).
func contact_cause() -> StringName:
	return &"lurker"


## The test seam (D7): set the target, then enter the state, as the FSM would. A forced HUNT at a
## lit player light is lethal until its first tick re-senses, as M1's _enter(HUNT) was.
func force(next: State, source: LightSource = null) -> void:
	target = source
	_enter(next)


# --- The rule, as the FSM asks it (tests call these too) ----------------------------------------
# `source` is untyped: a freed LightSource passed to a typed (even Object) parameter is a script
# error on 4.7.2 (probed), and each of these must answer false for it.

## Wake and telegraph: Sensing.can_notice() against the `world` node's play rect.
func notices(source: Variant) -> bool:
	var rect: Variant = _play_rect()
	return rect != null and LightSource.live(source) \
			and Sensing.can_notice(source.global_position, source.radius(), global_position, rect)


## The hunt: light and distance alone (Q1).
func senses(source: Variant) -> bool:
	return LightSource.live(source) and Sensing.can_sense(source.global_position, source.radius(), global_position)


## Off screen (or in the notice margin) but in reach: the edge cue's and the stirring sound's rule.
func stirs_for(source: Variant) -> bool:
	var rect: Variant = _play_rect()
	return rect != null and LightSource.live(source) \
			and Sensing.can_stir(source.global_position, source.radius(), global_position, rect)


## AR20: "seen" means inside World.play_rect(), never the viewport, since a gutter hides what is
## behind it. No World (or a `world` node with no play rect) means no screen: nothing is noticed.
func _play_rect() -> Variant:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method(&"play_rect"):
		return null
	return world.play_rect()


## D7: the one rule for `monitorable`. Only a hunt of a lit player light it senses this tick hurts;
## a hunt of a flare or the cache never does.
func _harmful(sensed_now: bool) -> bool:
	return state == State.HUNT and sensed_now and LightSource.live(target) and target.kind == Sensing.KIND_PLAYER


# --- The FSM (Story 1.20 D6: the rows are named in the comments) --------------------------------

func _physics_process(delta: float) -> void:
	var t := Game.tuning
	_t += delta
	# Read before anything moves this tick, as M1 read senses() at the top.
	var lit := _lit_sources()
	var was := state
	stirring = false
	match state:
		State.IDLE:
			var pick_n := _pick(lit, notices)
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta * 2.0)
			_rest(pick_n, pick_n == null and lit.any(stirs_for))
		State.TELEGRAPH:
			_timer -= delta
			# The rate is declared in Fx.EFFECTS and held to the 2 Hz pulse cap there (NFR8).
			_eyes.modulate.a = 0.1 + 0.9 * Fx.pulse(_t, Fx.EYE_PULSE_HZ)
			_body_sprite.position.x = sin(_t * Fx.SHIVER_RATE) * 0.5  # a small shiver, declared in Fx.EFFECTS
			_telegraph(_pick(lit, notices))
		State.HUNT:
			_eyes.modulate.a = 1.0
			_hunt(_hunt_pick(lit), delta)
		State.RETURN:
			var pick_n := _pick(lit, notices)  # before the step home, as M1 sensed at the top of the tick
			var stirs := pick_n == null and lit.any(stirs_for)
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta)
			global_position = global_position.move_toward(_home, t.f(&"lurker_return_speed") * delta)
			_rest(pick_n, stirs)
	_step_stir(delta)
	if state != was and Log.enabled(Log.LURKER):
		Log.debug(Log.LURKER, "%s %s -> %s (%s)" % [name, State.keys()[was], State.keys()[state], target.kind if LightSource.live(target) else &"none"])
	_update_look()


## IDLE and RETURN, with the light read before this tick's step home. I1: a noticed light wakes it,
## full telegraph. I2: otherwise `stirs` (some lit light would wake it off screen) sets `stirring`;
## RETURN reaches home -> IDLE.
func _rest(pick_n: LightSource, stirs: bool) -> void:
	if pick_n != null:
		target = pick_n
		_enter(State.TELEGRAPH)
		return
	target = null
	stirring = stirs
	if state == State.RETURN and global_position.distance_to(_home) < 1.0:
		_enter(State.IDLE)


func _telegraph(pick_n: LightSource) -> void:
	if not LightSource.live(target) or pick_n == null:
		# T1: the light went out (M1 D6). T2: nothing is noticed on screen any more (Q1: every tick of
		# the warning is seen).
		_enter(State.IDLE if global_position.distance_to(_home) < 1.0 else State.RETURN)
	elif pick_n != target and pick_n.kind == Sensing.KIND_PLAYER:
		# T3 (FR21): onto the player is always a full telegraph.
		target = pick_n
		_enter(State.TELEGRAPH)
	else:
		target = pick_n  # T4: one decoy for another keeps the timer; T5: the same light
		if _timer <= 0.0:
			_enter(State.HUNT)


func _hunt(pick_s: LightSource, delta: float) -> void:
	var t := Game.tuning
	if not LightSource.live(target):
		_enter(State.RETURN)  # H1: a flare burnt out, the cache taken, a death (M1 D6): home at once
		return
	if pick_s != null and pick_s != target and pick_s.kind == Sensing.KIND_PLAYER:
		target = pick_s  # H3 (FR21): every hunt of the player is telegraphed; a new life's light is a new node. _hunt_pick() gave it only because it is noticed
		_enter(State.TELEGRAPH)
		return
	var sensed := pick_s != null
	if sensed:
		target = pick_s  # H4: off the player onto a decoy, no telegraph (FR16); H5: the same light
		_unsensed = 0.0  # Q2: a re-sense inside the wait resumes the hunt
	else:
		_unsensed += delta  # H2: lost the scent
	monitorable = _harmful(sensed)  # lost the scent -> harmless at once: a Snuff or landing in time always saves you
	if _unsensed >= t.f(&"lurker_lose_track_time"):
		_enter(State.RETURN)
		return
	# Lost the scent: stop closing in at once (landing / Snuff must feel safe), then give up.
	var want := Vector2.ZERO
	if sensed:
		want = global_position.direction_to(target.global_position) * t.f(&"lurker_hunt_speed")
	var accel := t.f(&"lurker_hunt_accel")
	_velocity = _velocity.move_toward(want, accel * 2.0 * delta if not sensed else accel * delta)
	global_position += _velocity * delta


## D9: one step toward the goal at most once per STIR_STEP_TIME, in every state, never reset outside
## this clock, so whatever draws `stir` changes at most ~2.9 times a second however the condition
## flickers (the view bobbing at the reach limit, a lurker on the notice edge).
func _step_stir(delta: float) -> void:
	_stir_clock += delta
	var goal := 2 if stirring else 0
	if stir != goal and _stir_clock >= STIR_STEP_TIME - STIR_CLOCK_SLACK:
		stir += signi(goal - stir)
		_stir_clock = 0.0


## The hunt's pick: the largest light it senses (Q1: no screen test), with one exception (row H3b;
## review of 1.20, sonlm 2026-11-25). A player light it isn't hunting and doesn't notice (off screen,
## or in the notice margin) can't be telegraphed at where the warning is seen (Pillar 2), so it is
## left out and the hunt stays on the largest of its target and the decoys: a flare keeps working
## off screen however bright the player grows. On screen the player light is picked as before (H3).
func _hunt_pick(lit: Array[LightSource]) -> LightSource:
	var pick_s := _pick(lit, senses)
	if pick_s == null or pick_s == target or pick_s.kind != Sensing.KIND_PLAYER or notices(pick_s):
		return pick_s
	var rest: Array[LightSource] = []
	for s in lit:
		if s == target or s.kind != Sensing.KIND_PLAYER:
			rest.append(s)
	return _pick(rest, senses)


## Every lit LightSource, in group order (tree order), so a tie between two decoys keeps the earlier.
func _lit_sources() -> Array[LightSource]:
	var out: Array[LightSource] = []
	for n in get_tree().get_nodes_in_group(LightSource.GROUP):
		if LightSource.live(n):
			out.append(n)
	return out


## The light `rule` (notices or senses) picks among `lit`, by Sensing.pick_target(); null for none.
func _pick(lit: Array[LightSource], rule: Callable) -> LightSource:
	var cands: Array[LightSource] = []
	var entries: Array[Dictionary] = []
	for s in lit:
		if rule.call(s):
			cands.append(s)
			entries.append(s.sensed())
	var i := Sensing.pick_target(entries)
	return null if i < 0 else cands[i]


## Readability: the eyes cast red light on the wall (and on the lurker's own body while it hunts),
## and they open from a slit to full at the start of the telegraph.
func _update_look() -> void:
	_glow.energy = _eyes.modulate.a * GLOW_ENERGY
	_glow.visible = _glow.energy > 0.01
	if state == State.TELEGRAPH:
		_eyes.scale.y = clampf((Game.tuning.f(&"lurker_telegraph_time") - _timer) / EYE_OPEN_TIME, 0.25, 1.0)
	else:
		_eyes.scale.y = 1.0


func _enter(next: State) -> void:
	state = next
	_body_sprite.position.x = 0.0
	monitorable = _harmful(true)  # D7: a HUNT at a lit player light is lethal until its first tick re-senses
	match next:
		State.TELEGRAPH:
			_timer = Game.tuning.f(&"lurker_telegraph_time")
			# Every hunt starts from rest, as in M1, where a telegraph came only from IDLE or RETURN:
			# a telegraph reached from a hunt (H3) must not hand the old hunt's speed to the new one.
			_velocity = Vector2.ZERO
		State.HUNT:
			_unsensed = 0.0
		State.RETURN:
			_velocity = Vector2.ZERO
