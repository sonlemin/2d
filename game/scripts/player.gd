class_name Player
extends CharacterBody2D
## The descender. Runs, jumps, dashes, slashes on the ground and pogos (Attack in the air).
## Pogo hits feed the ChainState, which drives Blade Bloom (hitbox scale) and Chain-Light (light radius).
## Landing or holding Light (Snuff) breaks the chain. Touching a predator kills.

signal died
signal chain_changed(count: int)

# --- Movement tuning ---
@export var run_speed := 110.0
@export var run_accel := 900.0
@export var air_accel := 1500.0          ## snappier steering in the air, to line up the next pogo
@export var gravity := 900.0
@export var max_fall := 210.0            ## was 330; slowed for the first playtests
@export var fall_gravity_scale := 0.6   ## gravity multiplier while falling (rising is unchanged)
@export var jump_velocity := -330.0       ## apex ~60 px (~3.8 tiles); was -270 (~40 px)
@export var jump_cut := 0.45            ## velocity multiplier when Jump is released early
@export var coyote_time := 0.08
@export var jump_buffer := 0.10
@export var dash_speed := 260.0
@export var dash_time := 0.12
# --- Combat tuning ---
@export var pogo_velocity := -300.0      ## apex ~50 px: hang time to steer to the next target (was -260)
@export var swing_active := 0.12
@export var air_swing_active := 0.22    ## a pogo stays armed longer: pressing X a bit early still hits
@export var swing_cooldown := 0.22
@export var hitstop := 0.075            ## freeze frame on pogo hit (seconds, real time; was 0.045)
@export var shake := 2.5                ## px camera kick on a pogo hit
@export var look_ahead := 70.0          ## px the camera leads downward while falling (see ledges sooner)
@export var light_kick := 18.0          ## px the light flares on a pogo hit
@export var knockback := Vector2(150, -150)
@export var invuln_time := 0.6
@export var snuff_hold := 0.12         ## Light must be HELD this long to Snuff: a tap or brush never breaks the chain
@export var light_lerp := 10.0          ## how fast the visible light eases to its target radius

const LIGHT_TEXTURE_HALF := 64.0        ## light.png is 128 px

var chain := ChainState.new()
var is_dead := false

var _facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _dash_left := 0.0
var _dash_dir := 1
var _jumping := false                   ## only a real jump may be cut short by releasing Jump
var _can_dash := true
var _swing_left := 0.0
var _swing_cd := 0.0
var _swing_is_pogo := false
var _swing_hit := false                 ## a swing connects at most once for the chain
var _invuln := 0.0
var _shown_radius := ChainState.BASE_RADIUS
var _shake := 0.0
var _light_held := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $Light
@onready var _slash: Area2D = $Slash
@onready var _pogo: Area2D = $Pogo
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("player")
	chain.changed.connect(_on_chain_changed)
	chain.banked.connect(_on_banked)
	_hurtbox.area_entered.connect(_on_hurt_area)
	_set_swing_visible(false)
	_apply_bloom()


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leave the world frozen if we vanish mid-hitstop


func light_radius() -> float:
	return chain.light_radius()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	_handle_snuff(delta)
	_handle_horizontal(delta)
	_handle_vertical(delta)
	_handle_attack()
	move_and_slide()
	if is_on_floor():
		_coyote = coyote_time
		_can_dash = true
		_jumping = false
		chain.break_chain()  # Landing breaks the chain; the ground is a sanctuary.
	_process_swing()
	_check_contact()
	_update_light(delta)


## Real-time juice (runs during hitstop too): squash recovers, camera kick decays.
func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	_sprite.scale = _sprite.scale.lerp(Vector2.ONE, clampf(12.0 * real, 0.0, 1.0))
	_shake = move_toward(_shake, 0.0, 20.0 * real)
	_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	# Lead the view downward while falling; ease back when standing or rising.
	var lead := look_ahead if velocity.y > 40.0 and not is_on_floor() else 0.0
	_camera.position.y = move_toward(_camera.position.y, lead, 140.0 * real)


func _tick_timers(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_swing_cd = maxf(_swing_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_sprite.visible = _invuln <= 0.0 or fmod(_invuln, 0.4) < 0.25  # 2.5 Hz blink stays under the 3 flashes/s cap


## Hold = Snuff (the design's tap on Light is reserved for Flare Toss, later).
func _handle_snuff(delta: float) -> void:
	_light_held = _light_held + delta if Input.is_action_pressed("light") else 0.0
	var snuff := _light_held >= snuff_hold
	if snuff != chain.snuffed:
		chain.set_snuffed(snuff)


func _handle_horizontal(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_facing = int(signf(dir))
		_sprite.flip_h = _facing < 0
		_slash.scale.x = absf(_slash.scale.x) * _facing
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = dash_speed * _dash_dir  # direction is locked when the dash starts
		return
	if Input.is_action_just_pressed("dash") and _can_dash and not is_on_floor():
		_can_dash = false
		_dash_left = dash_time
		_dash_dir = _facing
		_jumping = false
		velocity = Vector2(dash_speed * _dash_dir, 0.0)
		return
	var accel := run_accel if is_on_floor() else air_accel
	velocity.x = move_toward(velocity.x, dir * run_speed, accel * delta)


func _handle_vertical(delta: float) -> void:
	if _dash_left > 0.0:
		return  # dash ignores gravity
	var g := gravity * (fall_gravity_scale if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall)
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jumping = true
		_buffer = 0.0
		_coyote = 0.0
	if Input.is_action_just_released("jump") and _jumping and velocity.y < 0.0:
		velocity.y *= jump_cut


func _handle_attack() -> void:
	if not Input.is_action_just_pressed("attack") or _swing_cd > 0.0:
		return
	_swing_is_pogo = not is_on_floor()  # in the air, Attack always pogoes (one key, still timed)
	_swing_left = air_swing_active if _swing_is_pogo else swing_active
	_swing_cd = swing_cooldown
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
	velocity.y = pogo_velocity
	_jumping = false
	_dash_left = 0.0
	_can_dash = true  # pogo refreshes the air dash: keeps the chain steerable
	chain.add_hit()
	_shown_radius += light_kick
	_shake = shake
	_sprite.scale = Vector2(0.75, 1.3)  # stretch up out of the bounce
	Fx.chain_popup(get_parent(), global_position, chain.count, ChainState.ember_value(chain.count))
	_freeze_frame()


func _freeze_frame() -> void:
	if hitstop <= 0.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(hitstop, true, false, true).timeout
	Engine.time_scale = 1.0


func _set_swing_visible(on: bool) -> void:
	_slash.visible = on and not _swing_is_pogo
	_pogo.visible = on and _swing_is_pogo


func _on_banked(amount: int) -> void:
	if not is_dead:
		Fx.popup(get_parent(), global_position + Vector2(0, -10), "+%d banked" % amount, Color(1, 0.93, 0.7), 10)


func _on_chain_changed(count: int) -> void:
	_apply_bloom()
	chain_changed.emit(count)


func _apply_bloom() -> void:
	var s := chain.bloom_scale()
	_slash.scale = Vector2(s * _facing, s)
	_pogo.scale = Vector2(s, s)


func _update_light(delta: float) -> void:
	var target := chain.light_radius()
	_shown_radius = lerpf(_shown_radius, target, clampf(light_lerp * delta, 0.0, 1.0))
	_light.texture_scale = _shown_radius / LIGHT_TEXTURE_HALF


## Crawler contact: knockback and break the chain, but don't kill. Only predators kill in M1.
## Polled every frame (not body_entered) so a crawler still overlapping after invulnerability hurts.
func _check_contact() -> void:
	if is_dead or _invuln > 0.0:
		return
	for body in _hurtbox.get_overlapping_bodies():
		if not body.is_in_group("enemy") or body.is_queued_for_deletion():
			continue
		# An active pogo swing on this crawler wins over contact damage.
		if _swing_left > 0.0 and _swing_is_pogo and _pogo.overlaps_body(body):
			continue
		_take_knockback(body)
		return


func _take_knockback(body: Node2D) -> void:
	_invuln = invuln_time
	_jumping = false
	var away := signf(global_position.x - body.global_position.x)
	velocity = Vector2(knockback.x * (away if away != 0.0 else -_facing), knockback.y)
	_dash_left = 0.0
	chain.break_chain()


func _on_hurt_area(area: Area2D) -> void:
	if is_dead or not area.is_in_group("predator"):
		return
	die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	Engine.time_scale = 1.0
	var lost := chain.lose()  # unbanked embers die with you
	if lost > 0:
		Fx.popup(get_parent(), global_position + Vector2(0, -10), "-%d lost" % lost, Color(1, 0.35, 0.3), 10)
	velocity = Vector2.ZERO
	_set_swing_visible(false)
	died.emit()
