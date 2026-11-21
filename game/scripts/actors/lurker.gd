class_name Lurker
extends Area2D
## A predator drawn to light. It waits inside the walls of the dark, unseen.
##
## It senses the player only when their Chain-Light is big (radius >= NOTICE_MIN_RADIUS)
## AND the lurker sits inside that light's reach (distance <= radius * NOTICE_FACTOR).
## A bigger light reaches farther into the dark.
##
## Pillar 2 (every death teaches): it always telegraphs. Its eyes open and pulse for the
## telegraph time (Tuning lurker_telegraph_time) before it moves. Landing or Snuff shrinks the
## light, and it loses track.

enum State { IDLE, TELEGRAPH, HUNT, RETURN }

# Telegraph, hunt and return numbers are Game.tuning keys (lurker_*, AR15); the telegraph's
# >= 0.75 s floor (Pillar 2) moves from an editor range to Spec.TELEGRAPH_MIN in 1.9.
# The sensing rule stays here until Story 1.20 moves it into rules/sensing.gd:
const NOTICE_MIN_RADIUS := 80.0  ## px of light before it can notice you, chain ~4 with the default curve (GDD Lurker); Sensing in 1.20 (M1 lurker.notice_min_radius).
const NOTICE_FACTOR := 1.6  ## × the light radius it senses from (GDD Lurker "radius × 1.6"); Sensing in 1.20 (M1 lurker.notice_factor).
const SCREEN_MARGIN := 8.0  ## px: only notice this far inside the play rect (between the gutters), so the telegraph is seen; Sensing in 1.20 (M1 lurker.screen_margin).
# Presentation, which no system bends:
const GLOW_ENERGY := 1.3  ## red light the eyes cast on the wall around them; presentation (M1 lurker.glow_energy).
const EYE_OPEN_TIME := 0.2  ## s for the eyes to open (squash -> full) at the start of the telegraph; presentation (M1 lurker.eye_open_time).

var state: State = State.IDLE
var _timer := 0.0
var _unsensed := 0.0
var _velocity := Vector2.ZERO
var _home := Vector2.ZERO
var _t := 0.0
var _player: Node2D

@onready var _eyes: Sprite2D = $Eyes
@onready var _body_sprite: Sprite2D = $Sprite
@onready var _glow: PointLight2D = $Glow


func _ready() -> void:
	add_to_group("predator")
	_home = global_position
	_eyes.modulate.a = 0.0
	monitorable = false  # harmless until it hunts: contact kills only after a telegraph


func senses(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player) or player.get("is_dead"):
		return false
	var r: float = player.light_radius()
	if r < NOTICE_MIN_RADIUS or global_position.distance_to(player.global_position) > r * NOTICE_FACTOR:
		return false
	return _on_screen()


## Pillar 2 beats off-screen ambushes: a lurker only notices when its telegraph will be seen.
## AR20: "seen" means inside World.play_rect(), never the viewport, since a gutter hides what
## is behind it. No World (or a `world` node with no play rect) means no screen, so it never notices.
func _on_screen() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method(&"play_rect"):
		return false
	return world.play_rect().grow(-SCREEN_MARGIN).has_point(global_position)


func _physics_process(delta: float) -> void:
	var t := Game.tuning
	_t += delta
	# D6, Pillar 2: a hunt never carries over a death. The old player stays in the tree until the
	# respawn; without this a lurker could refetch the new one and keep HUNT (and monitorable) on
	# a target that never saw a telegraph.
	var gone := _player == null or not is_instance_valid(_player)
	if (state == State.TELEGRAPH or state == State.HUNT) and (gone or _player.get("is_dead")):
		_enter(State.RETURN)
	if gone:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var sensed := senses(_player)
	match state:
		State.IDLE:
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta * 2.0)
			if sensed:
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			_timer -= delta
			# The rate is declared in Fx.EFFECTS and held to the 2 Hz pulse cap there (NFR8).
			_eyes.modulate.a = 0.1 + 0.9 * Fx.pulse(_t, Fx.EYE_PULSE_HZ)
			_body_sprite.position.x = sin(_t * 40.0) * 0.5  # a small shiver
			if not sensed:
				_enter(State.IDLE if global_position.distance_to(_home) < 1.0 else State.RETURN)
			elif _timer <= 0.0:
				_enter(State.HUNT)
		State.HUNT:
			_eyes.modulate.a = 1.0
			_unsensed = 0.0 if sensed else _unsensed + delta
			monitorable = sensed  # lost the scent -> harmless at once: a Snuff or landing in time always saves you
			if _unsensed >= t.f(&"lurker_lose_track_time"):
				_enter(State.RETURN)
			else:
				# Lost the scent: stop closing in at once (landing / Snuff must feel safe), then give up.
				var want := Vector2.ZERO
				if sensed:
					want = global_position.direction_to(_player.global_position) * t.f(&"lurker_hunt_speed")
				var accel := t.f(&"lurker_hunt_accel")
				_velocity = _velocity.move_toward(want, accel * 2.0 * delta if not sensed else accel * delta)
				global_position += _velocity * delta
		State.RETURN:
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta)
			global_position = global_position.move_toward(_home, t.f(&"lurker_return_speed") * delta)
			if sensed:
				_enter(State.TELEGRAPH)
			elif global_position.distance_to(_home) < 1.0:
				_enter(State.IDLE)
	_update_look()


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
	monitorable = next == State.HUNT
	match next:
		State.TELEGRAPH:
			_timer = Game.tuning.f(&"lurker_telegraph_time")
		State.HUNT:
			_unsensed = 0.0
		State.RETURN:
			_velocity = Vector2.ZERO
