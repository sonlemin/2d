class_name CameraRig
extends Camera2D
## The one camera (AR27): follows the body World gives it, leads downward while it falls (FR3),
## owns the screen shake and knows where the play area sits between the HUD gutters (AR20).
## A direct child of World, never of the player, so a respawned player keeps the same camera.
## AR6: with physics interpolation on, the engine runs a Camera2D on the physics tick and only
## updates its screen centre there, so its own smoothing and reset can't cut on a teleport
## (Story 1.7 D8, probed on 4.7.2). The rig therefore smooths and clamps itself on the physics
## tick, the engine smoothing is off, and play_rect() never reads the engine camera.
## The lead and the shake decay run on real time, so they keep going during a hitstop, as in M1.

const GUTTER_WIDTH := 60.0  ## px each HUD gutter takes from the 480 px view (UX DESIGN.md Layout & Spacing, UX-DR18)
const PLAY_WIDTH := 360.0  ## px of play area between the two gutters (UX DESIGN.md Layout & Spacing, UX-DR18)
const LOOK_AHEAD := 70.0  ## px the camera leads downward while falling, to see ledges sooner (GDD Movement "Camera", FR3; was player.LOOK_AHEAD).
const LEAD_SPEED := 140.0  ## px/s the lead eases in and out; presentation (M1 value, was inline in player.gd).
const SHAKE_DECAY := 20.0  ## px/s the shake dies down; presentation (M1 value, was inline in player.gd).
const POGO_SHAKE := 2.5  ## px camera kick on a pogo hit; presentation (was player.SHAKE, M1 player.shake).
const SMOOTH_SPEED := 8.0  ## 1/s follow smoothing, the engine's formula; presentation (was world.tscn position_smoothing_speed).

var target: CharacterBody2D
var _lead := 0.0
var _shake := 0.0
var _smoothed := Vector2.ZERO  # the follow point, unclamped, as the engine smoothing kept it
var _centre := Vector2.ZERO  # the view centre: _smoothed clamped to the limits
var _view := Vector2.ZERO  # viewport size, read once in the tree


func _init() -> void:
	# Before the tree: the engine would otherwise override IDLE with a WARNING (D8).
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false


func _enter_tree() -> void:
	_view = get_viewport_rect().size


## `body` drives the lead through its `velocity` and `is_on_floor()`: any CharacterBody2D works,
## so the test harness needs no Player.
func follow(body: CharacterBody2D) -> void:
	target = body
	_smoothed = body.global_position  # never slide in from (0, 0) if no snap() follows


## On the target at once, with no lead or shake left: a (re)spawn or a room cut never slides
## across the room, and play_rect() is right in the same frame.
func snap() -> void:
	_lead = 0.0
	_shake = 0.0
	offset = Vector2.ZERO
	if _has_target():
		_smoothed = target.global_position
	_centre = _clamp(_smoothed)
	global_position = _centre
	reset_physics_interpolation()


## The only way to shake the screen: Story 1.16 gates it on Settings.shake here.
func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Top and bottom from the room. A room no wider than the play area sits centred in the view and
## never scrolls sideways (m1_shaft: -64 / 416); a wider one (the arena, the hub) may scroll until
## each edge reaches its gutter. The rig clamps to these itself; the engine's copy then agrees.
func apply_limits(bounds: Rect2) -> void:
	var view_w := _view_size().x
	if bounds.size.x <= PLAY_WIDTH:
		limit_left = int(bounds.position.x - (view_w - bounds.size.x) / 2.0)
		limit_right = limit_left + int(view_w)
	else:
		limit_left = int(bounds.position.x - GUTTER_WIDTH)
		limit_right = int(bounds.end.x + GUTTER_WIDTH)
	limit_top = int(bounds.position.y)
	limit_bottom = int(bounds.end.y)


## AR20: "on screen" is the play area inside the gutters, in world coordinates, never the viewport.
## Built from the rig's own centre: deterministic, never shaken ("no randomness in level
## behaviour"), and right the same frame as a snap.
func play_rect() -> Rect2:
	var h := _view_size().y
	return Rect2(Vector2(_centre.x - PLAY_WIDTH / 2.0, _centre.y - h / 2.0), Vector2(PLAY_WIDTH, h))


## After the player has moved this tick: the rig comes after the Player in World's tree.
func _physics_process(delta: float) -> void:
	if not _has_target():
		offset = Vector2.ZERO  # never leave the last random shake frozen on screen
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_shake = move_toward(_shake, 0.0, SHAKE_DECAY * real)
	var want_lead := LOOK_AHEAD if target.velocity.y > 40.0 and not target.is_on_floor() else 0.0
	_lead = move_toward(_lead, want_lead, LEAD_SPEED * real)
	# Scaled delta, as the engine smoothing used: a hitstop slows the follow, as in M1.
	var want := target.global_position + Vector2(0.0, _lead)
	_smoothed += (want - _smoothed) * minf(SMOOTH_SPEED * delta, 1.0)
	_centre = _clamp(_smoothed)
	global_position = _centre
	# The only randf under scripts/: camera shake is presentation, never level behaviour.
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


## The view centre that keeps the view inside the limits. A span smaller than the view centres
## on it (a room shorter than the view is the deferred Story 2.1 item).
func _clamp(p: Vector2) -> Vector2:
	var half := _view_size() / 2.0
	return Vector2(_clamp_axis(p.x, limit_left + half.x, limit_right - half.x),
			_clamp_axis(p.y, limit_top + half.y, limit_bottom - half.y))


static func _clamp_axis(v: float, lo: float, hi: float) -> float:
	return (lo + hi) / 2.0 if lo > hi else clampf(v, lo, hi)


func _view_size() -> Vector2:
	if _view == Vector2.ZERO and is_inside_tree():
		_view = get_viewport_rect().size
	return _view


func _has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()
