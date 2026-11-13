class_name CameraRig
extends Camera2D
## The one camera (AR27): follows the body World gives it, leads downward while it falls (FR3),
## owns the screen shake and knows where the play area sits between the HUD gutters (AR20).
## A direct child of World, never of the player, so a respawned player keeps the same camera.
## Visuals only: it moves in `_process`, on real time, so the lead and the shake decay keep going
## during a hitstop, as in M1.

const GUTTER_WIDTH := 60.0  ## px each HUD gutter takes from the 480 px view (UX DESIGN.md Layout & Spacing, UX-DR18)
const PLAY_WIDTH := 360.0  ## px of play area between the two gutters (UX DESIGN.md Layout & Spacing, UX-DR18)
const LOOK_AHEAD := 70.0  ## px the camera leads downward while falling, to see ledges sooner (GDD Movement "Camera", FR3; was player.LOOK_AHEAD).
const LEAD_SPEED := 140.0  ## px/s the lead eases in and out; presentation (M1 value, was inline in player.gd).
const SHAKE_DECAY := 20.0  ## px/s the shake dies down; presentation (M1 value, was inline in player.gd).
const POGO_SHAKE := 2.5  ## px camera kick on a pogo hit; presentation (was player.SHAKE, M1 player.shake).

var target: CharacterBody2D
var _lead := 0.0
var _shake := 0.0


## `body` drives the lead through its `velocity` and `is_on_floor()`: any CharacterBody2D works,
## so the test harness needs no Player.
func follow(body: CharacterBody2D) -> void:
	target = body


## On the target at once, with no lead or shake left: a (re)spawn cuts instead of sliding across
## the room.
func snap() -> void:
	_lead = 0.0
	_shake = 0.0
	offset = Vector2.ZERO
	if _has_target():
		global_position = target.global_position
	reset_smoothing()
	# Without this the screen centre (so play_rect()) keeps the old position until next frame.
	force_update_scroll()


## The only way to shake the screen: Story 1.16 gates it on Settings.shake here.
func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Top and bottom from the room. A room no wider than the play area sits centred in the view and
## never scrolls sideways (m1_shaft: -64 / 416); a wider one (the arena, the hub) may scroll until
## each edge reaches its gutter.
func apply_limits(bounds: Rect2) -> void:
	var view_w := get_viewport_rect().size.x
	if bounds.size.x <= PLAY_WIDTH:
		limit_left = int(bounds.position.x - (view_w - bounds.size.x) / 2.0)
		limit_right = limit_left + int(view_w)
	else:
		limit_left = int(bounds.position.x - GUTTER_WIDTH)
		limit_right = int(bounds.end.x + GUTTER_WIDTH)
	limit_top = int(bounds.position.y)
	limit_bottom = int(bounds.end.y)


## AR20: "on screen" is the play area inside the gutters, in world coordinates, never the viewport.
## Without the shake: the offset is added after the limit clamp, so subtracting it gives the steady
## centre, and what a lurker notices never depends on randf ("no randomness in level behaviour").
func play_rect() -> Rect2:
	var size := Vector2(PLAY_WIDTH, get_viewport_rect().size.y)
	return Rect2(get_screen_center_position() - offset - size / 2.0, size)


func _process(delta: float) -> void:
	if not _has_target():
		offset = Vector2.ZERO  # never leave the last random shake frozen on screen
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_shake = move_toward(_shake, 0.0, SHAKE_DECAY * real)
	# The only randf under scripts/: camera shake is presentation, never level behaviour.
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	var want := LOOK_AHEAD if target.velocity.y > 40.0 and not target.is_on_floor() else 0.0
	_lead = move_toward(_lead, want, LEAD_SPEED * real)
	global_position = target.global_position + Vector2(0.0, _lead)


func _has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()
