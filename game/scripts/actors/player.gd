class_name Player
extends CharacterBody2D
## The descender. Runs, jumps, dashes, slashes on the ground and pogos (Attack in the air).
## Pogo hits feed the ChainState, which drives Blade Bloom (hitbox scale) and Chain-Light (light radius).
## Landing or holding Light past the tap window (Snuff) breaks the chain. A hit costs HP (Health, per
## life); a predator hurts only while monitorable. hurt() is the one damage path, for every source
## (Story 1.19 D2): World's spike poll calls it, and so does the contact poll here.
## Reads only its PlayerInput's intents, never Input (AR34, Story 1.8).

signal died
signal chain_changed(count: int)
## A pogo landed: World kicks its CameraRig, which owns the shake (AR27).
signal pogo_hit

# Gameplay numbers live in rules/tuning.gd and are read through Game.tuning each tick (AR15).
# These stay local because no system bends them (Story 1.3 D1).
const LIGHT_KICK := 18.0  ## px the visible light flares on a pogo hit; presentation: sensing reads chain.light_radius(), never this (M1 player.light_kick).
const LIGHT_LERP := 10.0  ## 1/s easing of the visible light toward its target radius; presentation (M1 player.light_lerp).
const HITSTOP_SCALE := 0.05  ## time scale during a pogo hitstop: it only makes the freeze a freeze; its length is Tuning hitstop (Story 1.3 D3).
const LIGHT_TEXTURE_HALF := 64.0        ## light.png is 128 px

var chain := ChainState.new()
var health := Health.new()  ## per-life (AR12): a respawn is a new Player, so full HP (FR13)
var is_dead := false
## The cause id of the hit that killed this life (Health.CAUSES), or &"" for a death with no cause
## (World's backstops, a test's die()). The death card reads it (Story 1.29).
var death_cause: StringName = &""

var _facing := 1
var _coyote := 0.0
var _dash_left := 0.0
var _dash_dir := 1
var _jumping := false                   ## only a real jump may be cut short by releasing Jump
var _can_dash := true
var _swing_left := 0.0
var _swing_cd := 0.0
var _swing_is_pogo := false
var _swing_hit := false                 ## a swing connects at most once for the chain
var _shown_radius := ChainState.BASE_RADIUS
var _clinging := false
var _cling_side := 0
var _cling_left := 0.0
var _kick_left := 0.0
var _flash_start := -1  # Engine.get_physics_frames() of the hit whose flash is drawing; -1 none
var _flash_white := false  # that flash may draw white (the Q1 gap allowed it)
## Engine.get_physics_frames() where the last white hit flash started, for the once-per-second gap
## (Q1); -1 never. Public: World hands it to the next life at a respawn, so the gap holds across a
## death (review of Story 1.19).
var last_white_frame := -1

@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $Light
@onready var _slash: Area2D = $Slash
@onready var _pogo: Area2D = $Pogo
@onready var _hurtbox: Area2D = $Hurtbox
## Public for tests and scripted moments (`player.input.lock()`).
@onready var input: PlayerInput = $PlayerInput


func _ready() -> void:
	add_to_group("player")
	chain.changed.connect(_on_chain_changed)
	chain.banked.connect(_on_banked)
	chain.ended.connect(_on_chain_ended)
	_set_swing_visible(false)
	_apply_bloom()
	_cling_left = Game.tuning.f(&"cling_grace")


func light_radius() -> float:
	return chain.light_radius()


func _physics_process(delta: float) -> void:
	# Before the dead return: a lethal hit flashes too, and its sprite must be restored (AC8).
	_tick_flash()
	_recover_squash()
	if is_dead:
		return
	input.sample()  # first, so every read this tick sees this tick's input (Story 1.8 D1)
	_tick_timers(delta)
	_handle_snuff()
	if not _handle_cling(delta):
		_handle_horizontal(delta)
		_handle_vertical(delta)
		_handle_attack()
	move_and_slide()
	if is_on_floor():
		_end_cling()
		_cling_left = Game.tuning.f(&"cling_grace")
		_coyote = Game.tuning.f(&"coyote_time")
		_can_dash = true
		_jumping = false
		chain.break_chain()  # Landing breaks the chain; the ground is a sanctuary.
	_process_swing()
	_poll_contacts()  # after the landing break, Snuff and cling: a hit on an escape tick finds the chain already banked (D3)
	_update_light(delta)


## The pogo squash eases back on the physics tick at one tick = 1/60 s of real time, as CameraRig
## and PlayerInput count it (Story 1.19). Physics ticks run at 60 per real second in a hitstop too,
## so the squash shows through the freeze; `delta / Engine.time_scale` in _process misread the hit
## frame (scaled before the request) and snapped it back at once (ledger, Story 1.16).
func _recover_squash() -> void:
	var real := 1.0 / Engine.physics_ticks_per_second
	_sprite.scale = _sprite.scale.lerp(Vector2.ONE, clampf(12.0 * real, 0.0, 1.0))


func _tick_timers(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_swing_cd = maxf(_swing_cd - delta, 0.0)
	health.tick(delta)  # game time: a hitstop pauses it, as M1's _invuln did
	# Story 1.16 D4: alpha, not visible, so the reduce-flashing variant (steady transparency) is the
	# same path; the rate and both variants live in Fx's gate (NFR8, UX-DR126).
	_sprite.modulate.a = Fx.blink_alpha(health.invuln)


## Held past the tap window = Snuff; PlayerInput times it on real time (FR9). A tap is Flare Toss (1.23).
func _handle_snuff() -> void:
	if input.snuff_active != chain.snuffed:
		chain.set_snuffed(input.snuff_active)


## Wall cling (hold Jump at a wall while falling): the chain pauses and its light hides.
## Release Jump = kick off the wall; Down = drop. Grace runs out -> the chain breaks (banks).
## Returns true while clinging (normal movement is skipped).
func _handle_cling(delta: float) -> bool:
	var t := Game.tuning
	if not _clinging:
		if is_on_floor() or velocity.y < 0.0 or _dash_left > 0.0 or not input.cling_held:
			return false
		_cling_side = _wall_side()
		if _cling_side == 0:
			return false
		_clinging = true
		chain.set_clinging(true)
	# Jump is held all through a cling, so the only press that can be waiting is the one that
	# started it: it went into the cling (M1 never buffered it), not into a jump after the kick.
	input.consume(&"jump_pressed")
	if not input.cling_held:
		_end_cling()
		velocity = Vector2(-_cling_side * t.f(&"wall_kick_x"), t.f(&"wall_kick_y"))
		_facing = -_cling_side
		_sprite.flip_h = _facing < 0
		_kick_left = t.f(&"kick_lock")
		_jumping = false
		return true
	if input.down_held or _wall_side() != _cling_side:
		_end_cling()
		return false
	_cling_left -= delta
	if _cling_left <= 0.0:
		chain.break_chain()  # grace is over: the chain ends safely, embers bank
	velocity = Vector2(0.0, t.f(&"cling_slide"))
	return true


func _end_cling() -> void:
	if _clinging:
		_clinging = false
		chain.set_clinging(false)


## Which side (-1 left, 1 right) has a wall right next to the body, or 0.
func _wall_side() -> int:
	for side in [_facing, -_facing]:
		if test_move(global_transform, Vector2(side * 2.0, 0.0)):
			return side
	return 0


func _handle_horizontal(delta: float) -> void:
	var t := Game.tuning
	var dir := input.move.x
	if dir != 0.0:
		_facing = int(signf(dir))
		_sprite.flip_h = _facing < 0
		_slash.scale.x = absf(_slash.scale.x) * _facing
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = t.f(&"dash_speed") * _dash_dir  # direction is locked when the dash starts
		return
	if input.dash_pressed and _can_dash and not is_on_floor():
		_can_dash = false
		_dash_left = t.f(&"dash_time")
		_dash_dir = _facing
		_jumping = false
		velocity = Vector2(t.f(&"dash_speed") * _dash_dir, 0.0)
		return
	var accel := t.f(&"run_accel") if is_on_floor() else t.f(&"air_accel")
	if _kick_left > 0.0:
		_kick_left -= delta
		return
	velocity.x = move_toward(velocity.x, dir * t.f(&"run_speed"), accel * delta)


func _handle_vertical(delta: float) -> void:
	if _dash_left > 0.0:
		return  # dash ignores gravity
	var t := Game.tuning
	var g := t.f(&"gravity") * (t.f(&"fall_gravity_scale") if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, t.f(&"max_fall"))
	# The press waits jump_buffer (FR1) of real time in PlayerInput, so a hitstop never eats it.
	if input.jump_pressed and _coyote > 0.0:
		velocity.y = t.f(&"jump_velocity")
		_jumping = true
		input.consume(&"jump_pressed")
		_coyote = 0.0
	if input.jump_released and _jumping and velocity.y < 0.0:
		velocity.y *= t.f(&"jump_cut")


func _handle_attack() -> void:
	# A press waits ATTACK_BUFFER of real time for the cooldown (Story 1.8 D9). The cooldown runs on
	# game time, so a press in a pogo's hitstop still runs out first, as in M1 (sonlm, 2026-11-18).
	if not input.attack_pressed or _swing_cd > 0.0:
		return
	input.consume(&"attack_pressed")
	_swing_is_pogo = not is_on_floor()  # in the air, Attack always pogoes (one key, still timed)
	_swing_left = Game.tuning.f(&"pogo_armed") if _swing_is_pogo else Game.tuning.f(&"slash_active")
	_swing_cd = Game.tuning.f(&"attack_cooldown")
	_swing_hit = false
	_set_swing_visible(true)


func _process_swing() -> void:
	if _swing_left <= 0.0:
		return
	_swing_left -= get_physics_process_delta_time()
	var box := _pogo if _swing_is_pogo else _slash
	# A pogo that reaches the ground (landing frame) is just a downward slash: no bounce, no link.
	var counts := _swing_is_pogo and not is_on_floor()
	for body in box.get_overlapping_bodies():
		if not body.has_method("take_hit") or body.is_queued_for_deletion():
			continue
		body.take_hit()
		if counts and not _swing_hit:
			_swing_hit = true
			_on_pogo_hit()
	if _swing_left <= 0.0:
		_set_swing_visible(false)


func _on_pogo_hit() -> void:
	velocity.y = Game.tuning.f(&"pogo_velocity")
	_jumping = false
	_dash_left = 0.0
	_can_dash = true  # pogo refreshes the air dash: keeps the chain steerable
	_cling_left = Game.tuning.f(&"cling_grace")
	chain.add_hit()
	_shown_radius += LIGHT_KICK
	_sprite.scale = Vector2(0.75, 1.3)  # stretch up out of the bounce
	pogo_hit.emit()
	Fx.chain_popup(_fx_parent(), global_position, chain.count, ChainState.ember_value(chain.count))
	_freeze_frame()


## FR4: the Clock times the 75 ms in real time and ends it, even if this player is freed mid-freeze.
func _freeze_frame() -> void:
	var seconds := Game.tuning.f(&"hitstop")
	if seconds <= 0.0:
		return
	Game.clock.request(&"hitstop", HITSTOP_SCALE, seconds)


func _set_swing_visible(on: bool) -> void:
	_slash.visible = on and not _swing_is_pogo
	_pogo.visible = on and _swing_is_pogo


func _on_banked(amount: int) -> void:
	if not is_dead:
		Fx.popup(_fx_parent(), global_position + Vector2(0, -10), tr("POPUP_BANKED") % amount, Color(1, 0.93, 0.7))


## Runtime spawns belong to the room, never to World (AR23, D8): the room frees them with itself.
## A bare test player with no World falls back to its parent.
func _fx_parent() -> Node:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("current_room"):
		var room: Node = world.current_room()
		if room != null:
			return room
	return get_parent()


func _on_chain_changed(count: int) -> void:
	_apply_bloom()
	chain_changed.emit(count)


func _apply_bloom() -> void:
	var s := chain.bloom_scale()
	_slash.scale = Vector2(s * _facing, s)
	_pogo.scale = Vector2(s, s)


func _update_light(delta: float) -> void:
	var target := chain.light_radius()
	_shown_radius = lerpf(_shown_radius, target, clampf(LIGHT_LERP * delta, 0.0, 1.0))
	_light.texture_scale = _shown_radius / LIGHT_TEXTURE_HALF


## Contact damage, polled every tick, never entered/exited (D3): a crawler or a lurker still
## overlapping when the invulnerability ends hits again. One hit per tick: a predator first (the
## larger hit, and deterministic), then a crawler.
## A predator counts only while `monitorable` is true when the poll reads it (Pillar 2: a predator
## damages only while monitorable). The overlap list lags a monitorable change by one physics step
## (probed on 4.7.2), so the poll reads the flag itself: a lurker that lost the scent this tick is
## harmless this tick, with no tick of lag.
## "In time" (D3): predators run before the player, so one already listed on the tick of an escape
## still reads monitorable here and hurts: the player was touched while it was lethal. It re-senses
## on the next tick, so any contact from then on is safe (smoke_rooms pins both sides).
func _poll_contacts() -> void:
	if is_dead or health.invulnerable():
		return
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group(&"predator") and area.monitorable and not area.is_queued_for_deletion():
			# Only an enemy may leave contact_cause() out (dev guide); a predator without one would
			# be silently harmless.
			assert(area.has_method(&"contact_cause"), "predator %s has no contact_cause()" % area.name)
			hurt(area.contact_cause(), area.global_position)
			return
	for body in _hurtbox.get_overlapping_bodies():
		if not body.is_in_group(&"enemy") or not body.has_method(&"contact_cause") or body.is_queued_for_deletion():
			continue
		# An active pogo swing on this crawler wins over contact damage.
		if _swing_left > 0.0 and _swing_is_pogo and _pogo.overlaps_body(body):
			continue
		hurt(body.contact_cause(), body.global_position)
		return


## The one way damage reaches a player (Story 1.19 D2), for every source. `cause` is a
## Health.CAUSES id; `from` is where the hit came from (knockback away from it), or Vector2.INF for
## none (spikes: World returns the player to safe ground instead). Returns whether it landed: false
## when dead or refused (invulnerable). Lethal first: a lethal hit is a death, so the held embers
## are lost, not banked ("only death loses held embers", GDD Health).
func hurt(cause: StringName, from := Vector2.INF) -> bool:
	if is_dead or health.hit(cause, Game.tuning.f(&"invuln_time")) == 0:
		return false
	if health.is_empty():
		_start_flash()  # a lethal hit flashes too when the gap allows; the flash runs out while dead (AC8)
		die(cause)
		return true
	chain.break_by_hit()  # FR11: held -> carried, and never a bank-heal (D4)
	_end_cling()
	_start_flash()
	_sprite.modulate.a = Fx.blink_alpha(health.invuln)  # from this tick's draw, not the next (steady under reduce flashing)
	if from.is_finite():
		var t := Game.tuning
		_jumping = false
		_dash_left = 0.0
		var away := signf(global_position.x - from.x)
		velocity = Vector2(t.f(&"knockback_x") * (away if away != 0.0 else -_facing), t.f(&"knockback_y"))
	return true


## The hit flash from this tick (Story 1.19 D9): drawn here for the hit tick, then ticked in
## _physics_process by physics frames, so a hit before or after this player's own tick shows the
## same 4 ticks. White at most once per Fx.HIT_FLASH_GAP_TICKS (Q1); Fx owns the gate and the dim.
## A hit inside the gap shows no white, a killing blow included (sonlm, review of Story 1.19: a dim
## or a white there reaches 3.5 flashes per second in a back-to-back death, over NFR8's cap of 3);
## the death card is the killing blow's feedback (Story 1.29).
func _start_flash() -> void:
	var now := Engine.get_physics_frames()
	_flash_white = Fx.white_flash_allowed(last_white_frame, now)
	if _flash_white:
		last_white_frame = now
	_flash_start = now if Fx.hit_flash(_sprite, 0, _flash_white) else -1


func _tick_flash() -> void:
	if _flash_start >= 0 and not Fx.hit_flash(_sprite, Engine.get_physics_frames() - _flash_start, _flash_white):
		_flash_start = -1


## FR12, D4: a chain banked safely (a landing, a Snuff, a cling timeout, a room exit) of
## bank_heal_min links or more heals 1 HP. A hit never does, and a death is no `ended` at all.
func _on_chain_ended(links: int, by_hit: bool) -> void:
	if by_hit or is_dead:
		return
	health.bank_heal(links, int(Game.tuning.f(&"bank_heal_min")))


## The Hurtbox in world space, for World's hazard poll (Story 1.19 D5). The room sits at the world
## origin, so world space is also room-local (World._poll_exits() reads positions the same way).
func hurt_rect() -> Rect2:
	var shape := _hurtbox.get_node("Shape") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	return Rect2(shape.global_position - size / 2.0, size)


## An in-room teleport (World's spike return): still, out of any cling, dash or swing, no coyote
## jump, and never a smear (AR6).
func place_at(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_end_cling()
	_dash_left = 0.0
	_swing_left = 0.0
	_set_swing_visible(false)
	_coyote = 0.0
	_jumping = false
	_kick_left = 0.0  # no wall-kick lockout carried to the new spot
	reset_physics_interpolation()


## `cause`: the Health.CAUSES id that killed (hurt() passes it); &"" for a death with no cause
## (World's tunnelling and failed-room backstops, tests). The death card reads death_cause (1.29).
func die(cause: StringName = &"") -> void:
	if is_dead:
		return
	death_cause = cause
	is_dead = true
	_end_cling()
	Game.clock.clear()  # a death mid-hitstop must not leave the respawn frozen
	var lost := chain.lose()  # unbanked embers die with you
	if lost > 0:
		Fx.popup(_fx_parent(), global_position + Vector2(0, -10), tr("POPUP_LOST") % lost, Color(1, 0.35, 0.3))
	velocity = Vector2.ZERO
	_set_swing_visible(false)
	died.emit()
