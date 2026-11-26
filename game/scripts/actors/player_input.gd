class_name PlayerInput
extends Node
## The only gameplay reader of `Input` (AR34): turns InputMap actions into per-tick intents for
## the Player, its parent. Owns the Light tap/hold machine (window from Settings), the real-time
## press buffers and lock() for scripted moments; the Cling/Snuff toggles join here in Story 1.35.
## No _physics_process of its own (Story 1.8 D1): a child ticks after its parent, so a self-ticking
## sampler would hand the Player last tick's input. The Player calls sample() first each tick.
## Real time is one tick per sample (D3): physics ticks stay at 60 per real second under
## Engine.time_scale (only their delta shrinks), so a hitstop never stretches a buffer or the
## Light window, and a paused tree, which skips the Player, freezes them with it (AR36).

const MOVE_DEADZONE := 0.2  ## stick tilt below this is no movement, and "standing still" for interact (UX-DR118, UX D7). Applied here: Input.action_press(strength) skips the action deadzone.
const INTERACT_FIRE := 0.6  ## ↓ tilt that fires interact, so a stick drifting down never rests you by accident (UX-DR118).
const INTERACT_REARM := 0.3  ## ↓ tilt it must fall below before it can fire again: one press, one interact (UX-DR118).
const ATTACK_BUFFER := 0.10  ## s real time an Attack press waits for the cooldown, so a press just before it ends still swings (Story 1.8 D9; same length as the jump buffer, FR1). A press in a pogo's hitstop is still lost, as in M1: the cooldown runs on game time and barely moves in the freeze (code review 2026-11-18, sonlm: keep M1).
## Lets a window that is a whole number of ticks (0.2 s = 12) start on that tick, not one later:
## twelve sums of 1/60 come to 0.19999…, eighteen to exactly 0.3.
const TIME_EPSILON := 1e-6
## The intents consume() clears: the two buffered presses (true from the press until consumed or
## their buffer runs out) and the three edges (true for one sample; consume() clears them for the
## rest of it). D2 called consume() a no-op for an edge; clearing is harmless and simpler.
const PRESSES: Array[StringName] = [&"jump_pressed", &"attack_pressed", &"dash_pressed", &"light_tap", &"interact"]

## Left/right and up/down, each zeroed below MOVE_DEADZONE.
var move := Vector2.ZERO
var jump_held := false
## Jump went up this tick: the jump cut keeps M1's release edge (D8).
var jump_released := false
var dash_held := false
## Hold mode: the same as jump_held (Story 1.35 adds the press-toggle).
var cling_held := false
## ↓ at or past the deadzone on its own, for the wall drop (FR7). Not move.y: ↑ is bound to Jump
## too, so clinging on ↑ and pressing ↓ would cancel to 0, and M1 dropped there.
var down_held := false
## Light held past Settings.light_tap_window: Snuff (FR9).
var snuff_active := false
## A Jump press waiting for the ground: kept Game.tuning jump_buffer (0.10 s) of real time.
var jump_pressed := false
## An Attack press waiting for the cooldown: kept ATTACK_BUFFER of real time.
var attack_pressed := false
## Edges, true for the one sample they happened in: an air-only dash pressed on the ground is lost,
## as in M1. A Light tap is a Flare Toss (Story 1.23: Player._handle_flare() reads the edge on the
## tick it happens, with no buffer: real ticks run through a hitstop); stations (1.24) decide what an
## interact does.
var dash_pressed := false
var light_tap := false
var interact := false

var _body: CharacterBody2D
var _locked := false
var _jump_left := 0.0  # s of real time the waiting Jump press has left
var _attack_left := 0.0
var _light_down := false  # the Light machine is timing a hold
var _light_wait_release := false  # after unlock(): Light must be seen up before a hold counts (D7)
var _light_time := 0.0  # s of real time Light has been held
var _interact_armed := false  # armed once ↓ is seen below INTERACT_REARM: a ↓ held at spawn never fires


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	assert(_body != null, "PlayerInput must be a child of a CharacterBody2D (the Player)")


## Once per physics tick, called by the Player before it reads any intent (D1).
func sample() -> void:
	var tick := 1.0 / Engine.physics_ticks_per_second
	dash_pressed = false
	light_tap = false
	interact = false
	jump_released = false
	if _locked:
		return
	move = Vector2(_axis(&"move_left", &"move_right"), _axis(&"move_up", &"move_down"))
	jump_held = Input.is_action_pressed("jump")
	dash_held = Input.is_action_pressed("dash")
	cling_held = jump_held
	down_held = Input.get_action_raw_strength("move_down") >= MOVE_DEADZONE
	jump_released = Input.is_action_just_released("jump")
	_jump_left = maxf(_jump_left - tick, 0.0)
	_attack_left = maxf(_attack_left - tick, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_left = Game.tuning.f(&"jump_buffer")
	if Input.is_action_just_pressed("attack"):
		_attack_left = ATTACK_BUFFER
	jump_pressed = _jump_left > 0.0
	attack_pressed = _attack_left > 0.0
	dash_pressed = Input.is_action_just_pressed("dash")
	_sample_light(tick)
	_sample_interact()


## Clears a waiting press once the Player has acted on it. An edge needs no consume.
func consume(intent: StringName) -> void:
	assert(intent in PRESSES, "PlayerInput.consume: '%s' is not a press intent" % intent)
	match intent:
		&"jump_pressed":
			_jump_left = 0.0
			jump_pressed = false
		&"attack_pressed":
			_attack_left = 0.0
			attack_pressed = false
		&"dash_pressed":
			dash_pressed = false
		&"light_tap":
			light_tap = false
		&"interact":
			interact = false


## Scripted moments (rest, the Fall): every intent off, every buffer and the Light machine cleared,
## so a held Snuff ends (D7).
func lock() -> void:
	_locked = true
	_clear()


## Held intents follow the keys again from the next sample; a press, the Light machine and
## interact all need a fresh press, so nothing held through a cutscene fires on its way out (D7).
func unlock() -> void:
	_locked = false
	_interact_armed = false
	_light_wait_release = true


func is_locked() -> bool:
	return _locked


func _clear() -> void:
	move = Vector2.ZERO
	jump_held = false
	jump_released = false
	dash_held = false
	cling_held = false
	down_held = false
	snuff_active = false
	jump_pressed = false
	attack_pressed = false
	dash_pressed = false
	light_tap = false
	interact = false
	_jump_left = 0.0
	_attack_left = 0.0
	_light_down = false
	_light_time = 0.0
	_interact_armed = false


## D4: a release inside the window is a tap and never Snuffs; held past it, Snuff until release.
## Accumulates as M1 did (the press tick counts), so Snuff starts on held tick ⌈window × 60⌉:
## 8 / 12 / 18 for 0.12 / 0.2 / 0.3 s. A Snuff stays on until release, so an Options change
## (1.36) made mid-hold never un-Snuffs it: it applies to the next hold.
## A hold starts on any held tick, not only on the press edge, so Light held through a pause or a
## respawn still Snuffs (as in M1) and a release and re-press inside one tick keeps the Snuff;
## only unlock() asks for a fresh press (D7).
func _sample_light(tick: float) -> void:
	var held := Input.is_action_pressed("light")
	if _light_wait_release:
		if held:
			return
		_light_wait_release = false
	if not _light_down and (held or Input.is_action_just_pressed("light")):
		_light_down = true
		_light_time = 0.0
	if not _light_down:
		return
	if held:
		_light_time += tick
		snuff_active = snuff_active or _light_time >= Game.settings.light_tap_window - TIME_EPSILON
		return
	# Released (possibly in the same tick it was pressed): a tap unless it had become a Snuff.
	light_tap = not snuff_active
	snuff_active = false
	_light_down = false
	_light_time = 0.0


## D6: fires on the tick ↓ crosses INTERACT_FIRE while armed, standing still on the ground. The
## crossing uses up the arm either way, so holding ↓ while running and then stopping, or landing
## with ↓ held, never fires; ↓ must fall below INTERACT_REARM first.
func _sample_interact() -> void:
	var down := Input.get_action_raw_strength("move_down")
	if down < INTERACT_REARM:
		_interact_armed = true
		return
	if down < INTERACT_FIRE or not _interact_armed:
		return
	_interact_armed = false
	var sideways := absf(Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left"))
	interact = _body.is_on_floor() and sideways < MOVE_DEADZONE


## Raw strengths with this script's deadzone, so keyboard (0 / 1), pads (1.37) and test strengths
## all go through the same rule.
func _axis(negative: StringName, positive: StringName) -> float:
	var v := Input.get_action_raw_strength(positive) - Input.get_action_raw_strength(negative)
	return 0.0 if absf(v) < MOVE_DEADZONE else v
