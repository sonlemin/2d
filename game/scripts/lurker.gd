class_name Lurker
extends Area2D
## A predator drawn to light. It waits inside the walls of the dark, unseen.
##
## It senses the player only when their Chain-Light is big (radius >= notice_min_radius)
## AND the lurker sits inside that light's reach (distance <= radius * notice_factor).
## A bigger light reaches farther into the dark.
##
## Pillar 2 (every death teaches): it always telegraphs. Its eyes open and pulse for
## telegraph_time before it moves. Landing or Snuff shrinks the light, and it loses track.

enum State { IDLE, TELEGRAPH, HUNT, RETURN }

@export var notice_min_radius := 80.0   ## chain ~4 with the default curve
@export var notice_factor := 1.6
@export_range(0.75, 3.0) var telegraph_time := 0.9  ## spec: >= 0.75 s
@export var lose_track_time := 0.6      ## spec: loses track within ~1 s
@export var hunt_speed := 95.0
@export var hunt_accel := 220.0
@export var return_speed := 40.0
@export var eye_pulse_hz := 2.0         ## smooth sine, under the 3 flashes/s cap
@export var screen_margin := 8.0        ## px: only notice when this far inside the visible screen
@export var glow_energy := 1.3          ## red light the eyes cast on the wall around them
@export var eye_open_time := 0.2        ## eyes "open" (squash -> full) at the start of the telegraph

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
	if r < notice_min_radius or global_position.distance_to(player.global_position) > r * notice_factor:
		return false
	return _on_screen()


## Pillar 2 beats off-screen ambushes: a lurker only notices when its telegraph will be seen.
func _on_screen() -> bool:
	var rect := get_viewport_rect().grow(-screen_margin)
	return rect.has_point(get_global_transform_with_canvas().origin)


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var sensed := senses(_player)
	match state:
		State.IDLE:
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta * 2.0)
			if sensed:
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			_timer -= delta
			_eyes.modulate.a = 0.55 + 0.45 * sin(_t * TAU * eye_pulse_hz)
			_body_sprite.position.x = sin(_t * 40.0) * 0.5  # a small shiver
			if not sensed:
				_enter(State.IDLE if global_position.distance_to(_home) < 1.0 else State.RETURN)
			elif _timer <= 0.0:
				_enter(State.HUNT)
		State.HUNT:
			_eyes.modulate.a = 1.0
			_unsensed = 0.0 if sensed else _unsensed + delta
			if _unsensed >= lose_track_time:
				_enter(State.RETURN)
			else:
				# Lost the scent: stop closing in at once (landing / Snuff must feel safe), then give up.
				var want := Vector2.ZERO
				if sensed:
					want = global_position.direction_to(_player.global_position) * hunt_speed
				_velocity = _velocity.move_toward(want, hunt_accel * 2.0 * delta if not sensed else hunt_accel * delta)
				global_position += _velocity * delta
		State.RETURN:
			_eyes.modulate.a = move_toward(_eyes.modulate.a, 0.0, delta)
			global_position = global_position.move_toward(_home, return_speed * delta)
			if sensed:
				_enter(State.TELEGRAPH)
			elif global_position.distance_to(_home) < 1.0:
				_enter(State.IDLE)
	_update_look()


## Readability: the eyes cast red light on the wall (and on the lurker's own body while it hunts),
## and they open from a slit to full at the start of the telegraph.
func _update_look() -> void:
	_glow.energy = _eyes.modulate.a * glow_energy
	_glow.visible = _glow.energy > 0.01
	if state == State.TELEGRAPH:
		_eyes.scale.y = clampf((telegraph_time - _timer) / eye_open_time, 0.25, 1.0)
	else:
		_eyes.scale.y = 1.0


func _enter(next: State) -> void:
	state = next
	_body_sprite.position.x = 0.0
	monitorable = next == State.HUNT
	match next:
		State.TELEGRAPH:
			_timer = telegraph_time
		State.HUNT:
			_unsensed = 0.0
		State.RETURN:
			_velocity = Vector2.ZERO
