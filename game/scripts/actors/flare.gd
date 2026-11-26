class_name Flare
extends CharacterBody2D
## A tossed flare (FR14–FR16, Story 1.23): half the chain, thrown as a light. It flies an arc, sticks
## to the first surface it meets, burns for Tuning's flare_burn from the throw and fades over its
## last second. Its light is the chain's own radius before the toss, and predators sense it like any
## other light (AR28, AR29: a LightSource of kind `flare`, judged by Sensing), so lurkers that can
## sense it go for it instead of you; hunting it is harmless (Lurker._harmful()).
## It can touch nothing and nothing can touch it: collision layer 0, mask 1 (the world only). No
## damage, no pogo, no contact_cause(); it passes through creatures, spikes, the player and other
## flares. It never looks for the player (lint light_query) and never writes `enabled` on its light
## (the budget's; rank ALWAYS, AR46: a flare keeps its PointLight2D).
## The room owns it (room.spawn(), AR23): a room swap or a respawn's rebuild frees it with the room.

enum State { FLYING, STUCK }

const GROUP := &"flare"
const FADE_TIME := 1.0  ## s; the light and the sprite fall in a straight line to nothing over the last second of the burn; presentation only: the sensed radius stays whole until the flare is out (GDD Flare Toss "In its last 1.0 s it fades out smoothly"; the guarantee is Spec.FLARE_FADE; Story 1.23 D8).

## px: the chain's light before the toss (ChainState.toss_flare()). Set by room.spawn() args before
## add_child, with the body's own `velocity` (the throw).
var radius := 0.0
var state := State.FLYING

var _left := 0.0  # s of burn left, counted from the throw on game time: it pauses with the tree and stretches with a hitstop, like every gameplay timer
var _out := false  # burn_out() ran: nothing more happens to this node
var _full_energy := 0.0  # the scene's energy: the fade scales it

@onready var light_source: LightSource = $LightSource
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	assert(radius > 0.0, "Flare: radius is set by room.spawn() args before add_child; without it the light has no size and still holds a cap slot")
	add_to_group(GROUP)
	# Shared and already drawn by Fx.warm_up() (AR46): it reads in the dark like every small glow.
	_sprite.material = Fx.unshaded()
	light_source.fixed_radius = radius  # children are ready before the parent, as on the player
	# Sized here as well as on LightSource's first tick, so the first drawn frame is never the
	# scene's default size.
	var light := light_source.light
	_full_energy = light.energy
	light.texture_scale = radius / (light.texture.get_width() / 2.0)
	_left = Game.tuning.f(&"flare_burn")  # AR15: a countdown may start from the current value
	reset_physics_interpolation()  # AR6: a spawn is a teleport


func _physics_process(delta: float) -> void:
	if _out:
		return
	if state == State.FLYING:
		_fly(delta)
		if _out:
			return
	_left -= delta
	if _left <= 0.0:
		burn_out()
		return
	# A straight line down over the last FADE_TIME, never up: a fade, not a flash (NFR8; Fx.EFFECTS
	# flare_fade). The rule radius doesn't fade (D8): lurkers leave on the tick it goes out.
	var k := clampf(_left / FADE_TIME, 0.0, 1.0)
	light_source.light.energy = _full_energy * k
	_sprite.modulate.a = k


## The arc (Q3, sonlm 2026-11-26): the throw's sideways speed never changes; the fall is the full
## gravity, never the player's floaty fall, capped at the terminal fall so a flare thrown in a dive
## never falls away from the diver: it reaches the diver's speed 25 ticks on, about 73 px above
## (probed at the 1.23 review; the throw does not add the thrower's own speed).
## move_and_collide() sweeps the shape, so a fast flare can't tunnel a 16 px wall, and the first
## collision is the first surface (D6).
func _fly(delta: float) -> void:
	var t := Game.tuning
	velocity.y = minf(velocity.y + t.f(&"gravity") * delta, t.f(&"max_fall"))
	if move_and_collide(velocity * delta) != null:
		_enter(State.STUCK)
		return
	# Out through an open exit (m1_shaft's floor hole): nothing below to stick to, so it goes out
	# rather than fall forever as a light nobody sees.
	var room := get_parent() as Room
	if room != null and not room.bounds().grow(Room.TILE).has_point(position):
		burn_out()


func _enter(next: State) -> void:
	state = next
	match next:
		State.FLYING:
			pass
		State.STUCK:
			velocity = Vector2.ZERO  # it never moves again


## The seam for the perf run and tests: it sticks where it is.
func stick() -> void:
	_enter(State.STUCK)


## s of burn left.
func burn_left() -> float:
	return _left


## Out, once: predators lose it at once (a lurker hunting it heads home on its next tick, row H1),
## and it is hidden and out of group `flare` before it is freed. queue_free() alone leaves the node
## in the tree until the frame ends, and the budget's pass (after the player's tick) would still
## count its light on the tick the cap swapped it for a new one: hidden, it wants no light.
func burn_out() -> void:
	if _out:
		return
	_out = true
	light_source.extinguish()
	visible = false
	remove_from_group(GROUP)
	queue_free()


## The cap (Story 1.23 Q2; Tuning flare_max): burns flares out until at most `keep` are left, the
## one with the least burn left first (the oldest; a tie goes to the earlier in group order). The
## player calls it with flare_max - 1 before a toss spawns its flare, so the toss is never refused.
static func trim(tree: SceneTree, keep: int) -> void:
	var live: Array[Flare] = []
	for n in tree.get_nodes_in_group(GROUP):
		var flare := n as Flare
		if flare != null and not flare.is_queued_for_deletion():
			live.append(flare)
	while live.size() > maxi(keep, 0):
		var pick := 0
		for i in range(1, live.size()):
			if live[i].burn_left() < live[pick].burn_left():
				pick = i
		live[pick].burn_out()
		live.remove_at(pick)
