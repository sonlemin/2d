class_name World
extends Node2D
## The game scene (AR19): holds the current room, the player, the camera, the darkness and the UI
## layer. Rooms change only through one swap path (AR24), for the first room, an exit and a
## respawn alike: always deferred, the old room out of the tree before it is freed. A death never
## reloads the scene (AR25): World waits RESPAWN_DELAY, rebuilds the respawn room (so enemies
## killed this dive stay dead) and spawns a fresh Player, then emits `player_spawned`, so anything
## bound to the player rebinds there.
## World also polls hazards like exits (Story 1.19 D5) and tracks the life's safe ground: the last
## floor tick that touched no hazard, seeded below the entry at every build (D6). A spike returns the
## player there; the Ember Cache drops at Room.floor_spot() of it (Story 1.22).
## A death's cost is applied here (Story 1.22 D3): the rule is SlotState.apply_death(), but the drop
## spot needs the room and the tracker, so a room without World (RoomHarness) costs nothing. Every
## build spawns the slot's cache when it lies in the new room (RoomLoader stays slot-free, D7).
## World also counts the slot's play time (real seconds, `_process`) and its depth record (the
## player's screen row, each tick), and checks a loaded respawn point before the first build
## (Story 1.21).

## Every (re)spawn, including the first: bind to `player.chain` / the player here, never once.
signal player_spawned(player: Player)
## Every room entry, including the first and a respawn's rebuild, after the player is placed.
signal room_entered(room_id: StringName)

const PlayerScene := preload("res://scenes/actors/player.tscn")
const EmberCacheScene := preload("res://scenes/objects/ember_cache.tscn")
## Applies the ≤ 6 light budget each physics tick, after the actors (Story 1.12 D5).
const LightBudgetNode := preload("res://scripts/world/light_budget.gd")
## The dive starts here unless the dive holds a respawn point: a loaded slot's resume point
## (Story 1.21), from Story 1.24 an anchor or a station.
const START_ROOM := &"m1_shaft"
## s: the most one frame adds to the slot's play time (Story 1.21 D8): a stalled or backgrounded
## frame is not play.
const PLAY_TIME_STEP_MAX := 0.25
## s between a death and the respawn, the M1 value; the death card replaces this wait in 1.29.
const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). `Settings.brightness` picks the level;
## until Options (1.36) it changes only through DevTools' `--set=brightness:N`, for one session.
## Lower = more tension; too low and darkness turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # the violet cast of the Edge palette in every zone until E4 applies the zone palettes to world art (ledger, Story 1.18 D10)

## Where a dive with no respawn point starts, and at which entry. Tests set them before add_child;
## DevTools' --room= sets them from inside _ready, before the first room is built (Story 1.11 D5).
var start_room: StringName = START_ROOM
var start_entry: StringName = &"spawn"

var _room: Room
var _player: Player
var _swap_pending := false
var _safe_pos := Vector2.ZERO  # room-local (the room and World both sit at the origin, so it is the player's `position`); see last_safe_position()
var _last_white_frame := -1  # the retired Player's last_white_frame, for the next life (Q1)
var _play_clock_usec := 0  # Time.get_ticks_usec() at the last frame counted as play; 0 = none since the start or a pause
var _last_death := {}  # the last death's SlotState.apply_death() report; see last_death_cost()

@onready var _darkness: CanvasModulate = $Darkness
@onready var _room_holder: Node2D = $RoomHolder
@onready var _camera: CameraRig = $Camera


func _ready() -> void:
	if OS.is_debug_build():
		add_child(load("res://scripts/dev/dev_tools.gd").new())  # path string, never preload: release presets exclude scripts/dev/ (1.13)
	add_to_group("world")
	var budget := LightBudgetNode.new()
	budget.world = self
	add_child(budget)
	# The entry scene boots Game once: it loads settings.json and the active slot and arms their
	# writes (Stories 1.4 D6, 1.21). A test adds World by hand and is never the current scene, so
	# tests can't touch the player's real files even through World. After DevTools above: an arg
	# that detaches the slot must be applied before the boot loads one (1.21 D12).
	if get_tree().current_scene == self:
		Game.boot()
	_apply_ambient()
	# A method, not a lambda: the connection drops when World is freed.
	Game.settings.changed.connect(_on_setting_changed)
	_check_respawn_point()
	var point := _respawn_point()
	# Not a physics callback, so the first room needn't wait for the end of the frame.
	_swap_room(point[0], point[1], true)


## AR20: what counts as "on screen", in world coordinates: the play area inside the gutters.
func play_rect() -> Rect2:
	return _camera.play_rect()


## The rect the light budget counts as on screen (D2): the whole view, gutters included. A cost
## rule (the engine draws and culls lights against the viewport), not AR20's fairness rule.
func light_rect() -> Rect2:
	return _camera.view_rect()


func current_room() -> Room:
	return _room


## D6: where the player last stood on the floor touching no hazard, room-local, recorded exactly (so
## a return never lands in a spike). Every build seeds it with Room.ground_below(entry), so it is
## per life and per room, and an `up` arrival has clean floor before its first floor tick. The Ember
## Cache drops at Room.floor_spot() of it (Story 1.22 D6), so never in mid-air or over a hazard.
func last_safe_position() -> Vector2:
	return _safe_pos


## The last death's cost, SlotState.apply_death()'s report ({} before any death this session): the
## death card reads what was lost, dropped or destroyed (Story 1.29).
func last_death_cost() -> Dictionary:
	return _last_death


## AR24: the one way into another room for an exit (and later a station or a scripted moment).
## Deferred, so it never runs inside a physics callback; a second call before it runs is dropped.
## Ignored while the player is dead: the respawn rebuilds the respawn room anyway.
func enter_room(room_id: StringName, entry: StringName) -> void:
	if _swap_pending or not _player_alive():
		return
	_swap_pending = true
	_swap_room.call_deferred(room_id, entry, false)


## Play time (Story 1.21 D8): real seconds while World processes, so it stops with
## `SceneTree.paused` (World is pausable) and counts through the death wait. Wall time between
## frames, never `delta / Engine.time_scale`: that misreads on the frame a Clock request lands (the
## delta was scaled before the request), which is every pogo hit's hitstop. Probed on 4.7.2: 12
## hits in 4.00 s counted 5.59 s. Bookkeeping only; nothing here moves.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _play_clock_usec > 0:
		_count_play_time((now - _play_clock_usec) / 1000000.0)
	_play_clock_usec = now


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_play_clock_usec = 0  # the pause is not play: the first frame after it starts the clock again


## One frame's real seconds onto the slot, capped at PLAY_TIME_STEP_MAX. Its own method so a test
## can count a known step.
func _count_play_time(real_seconds: float) -> void:
	Game.slot.add_play_time(minf(real_seconds, PLAY_TIME_STEP_MAX))


## Exits are polled here, not overlapped (D2, as crawler contact is): the body centre past the
## floor or the ceiling crosses that side's exit. Then, on every tick that crossed nothing, the
## depth record (Story 1.21), the safe-ground tracker and the hazard poll (Story 1.19). World runs
## before its children, so all three read the player's last tick.
func _physics_process(_delta: float) -> void:
	if _swap_pending or not _player_alive():
		return
	if _poll_exits():
		return
	# D9: the deepest screen row reached, 0 = the top screen. The room's own row in E1 (the bottom
	# loop adds none); E4 adds the room's `map=` row to it.
	Game.slot.record_depth(maxi(floori(_player.position.y / Display.BASE.y), 0))
	var hurt_rect := _player.hurt_rect()
	var touching := _room.touches_hazard(hurt_rect)
	if _player.is_on_floor() and not touching:
		_safe_pos = _player.position
	if touching:
		_on_hazard()


## True when the player crossed an edge this tick (a swap is pending, or the backstop killed them).
func _poll_exits() -> bool:
	var side := &""
	if _player.position.y > _room.bounds().end.y:
		side = &"down"
	elif _player.position.y < 0.0:
		side = &"up"
	if side == &"":
		return false
	var exit := _room.exit(side)
	if exit.is_empty():
		_player.die()  # a closed edge was crossed (tunnelling): never fall forever
		return true
	# Crossing a floor opening arrives at the target's top entry, a ceiling opening at its bottom.
	_on_exit_reached(exit.target, &"up" if side == &"down" else &"down")
	return true


## D5: a spike costs 1 HP with no knockback (the GDD's row is a return, not a push) and, if the
## player lives, returns them to the last safe ground. Q2 (sonlm, 2026-11-22): while invulnerable
## there is no damage, but they are still returned, never left standing in spikes.
func _on_hazard() -> void:
	_player.hurt(&"spikes")
	if not _player_alive():
		return
	_player.place_at(_safe_pos)
	_camera.snap()


func _on_exit_reached(target: StringName, entry: StringName) -> void:
	var chain: ChainState = _player.chain
	if chain.count > 0:
		chain.break_chain()  # FR6, ADR-2 backstop: a cut never lands mid-chain; banks like a landing
	enter_room(target, entry)


## The only place a room is built (D1). `respawn`: a fresh Player at `entry` (boot and death);
## otherwise the living player is carried over and placed (an exit).
func _swap_room(room_id: StringName, entry: StringName, respawn: bool) -> void:
	if not respawn and not _player_alive():
		# Died between the crossing and the end of the frame: never build, visit or announce a room
		# the player didn't reach; the pending respawn rebuilds the respawn room.
		_swap_pending = false
		return
	var room := RoomLoader.load_room(room_id, Game.dive)
	if room != null and not room.has_entry(entry):
		push_error("World: room '%s' has no entry '%s'" % [room_id, entry])
		room.queue_free()
		room = null
	if room == null:  # a content error, already pushed
		_swap_pending = false
		if not respawn:
			_player.die()  # outside the room with nowhere to go: never fall forever
		elif room_id != start_room or entry != start_entry:
			# A respawn point that failed to build: the dive's start instead. A loaded point is
			# checked before the first build (_check_respawn_point()), and DevTools checks --room=
			# before it sets the start, so this is the backstop for a point set in play. The point
			# is cleared, or every later death would try the same room and push the same error.
			Game.dive.set_respawn(&"", &"")
			_swap_room(start_room, start_entry, true)
		else:
			assert(false, "World: the start room '%s' failed to load (errors above)" % start_room)
		return
	if respawn and is_instance_valid(_player):
		_retire_player()  # before the new room's predators run _ready
	if _room != null:
		_room_holder.remove_child(_room)  # its predators and lights leave their groups now
		_room.queue_free()
	_room_holder.add_child(room)
	_room = room
	# Story 1.22 D7: the slot's cache, on every build of its room (the first, an exit, a respawn's
	# rebuild). Here, not in RoomLoader, so rooms still load standalone without a save; the room owns
	# and frees it (AR23). floor_spot() again: a save may be hand-edited or the room edited since.
	if Game.slot.has_cache() and Game.slot.cache_room == room_id:
		room.spawn(EmberCacheScene, room.floor_spot(Game.slot.cache_pos))
	# UX-DR5, Story 1.18 D2: the zone is the room's until E4 adds in-room boundaries and the cross-fade.
	# Before the warm-up, which outlines its label in the active zone's surface (code review of 1.18:
	# set after the camera snap, the warm-up drew the previous zone's). The room's own nodes ran
	# _ready above, on the old zone: whatever reads the palette there re-reads on `changed`.
	Game.palette.set_zone(room.zone)
	Fx.warm_up(room, room.entry_position(entry))  # AR46, Story 1.16 D10: each shared material's first draw is paid at the load
	if respawn:
		_spawn_player(entry)
	else:
		_player.position = room.entry_position(entry)
		# D3: from above the fall carries on across the cut; any other arrival starts still.
		if entry != &"up":
			_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()  # AR6: a teleport, never a smear
	_safe_pos = room.ground_below(entry)  # D6: seeded at every build, so per life and per room
	_camera.apply_limits(room.bounds())
	_camera.snap()
	# Before the signals: a handler may call enter_room() again (a scripted moment, a station).
	_swap_pending = false
	if respawn:
		player_spawned.emit(_player)
	Game.slot.visit(room_id)
	room_entered.emit(room_id)


func _player_alive() -> bool:
	return is_instance_valid(_player) and not _player.is_dead


## The dive's respawn point, or the dive's start while none is set (DiveState's rule; anchors
## and stations set it from Story 1.24).
func _respawn_point() -> Array[StringName]:
	var room_id := Game.dive.respawn_room if Game.dive.respawn_room != &"" else start_room
	var entry := Game.dive.respawn_entry if Game.dive.respawn_entry != &"" else start_entry
	return [room_id, entry]


## Story 1.21 D13: a respawn point from a save that World can't use (a room that is gone or broken,
## an entry the room doesn't list) is an environment error: one warning, and the dive starts and
## respawns at the start room. Checked before the first build, so it never reaches RoomLoader's
## or `_swap_room()`'s push_error. `inspect().entries` lists `spawn` and the exit sides today;
## Story 1.24 adds anchor and station ids to it.
func _check_respawn_point() -> void:
	var room_id := Game.dive.respawn_room
	var entry := Game.dive.respawn_entry
	if room_id == &"" and entry == &"":
		return
	var info := RoomLoader.inspect(room_id)
	if info.known and info.errors.is_empty() and entry in info.entries:
		return
	push_warning("World: the saved respawn point '%s' / '%s' can't be used (%s); starting in %s" % [room_id, entry,
			"no such room" if not info.known else "the room is invalid" if not info.errors.is_empty() else "the room has no such entry", start_room])
	Game.dive.set_respawn(&"", &"")


## The old Player leaves: out of groups `player` / `light_source` now, not at the end of the frame.
## Its last white hit flash goes to the next life, so "white at most once per second" (Q1) holds
## across a death: per life, a lethal white and a hit just after the respawn were 37 ticks apart
## (review of Story 1.19).
func _retire_player() -> void:
	_last_white_frame = _player.last_white_frame
	remove_child(_player)
	_player.queue_free()
	_player = null


## A fresh Player at `entry` in the current room; the old one, if any, goes first.
func _spawn_player(entry: StringName) -> void:
	if is_instance_valid(_player):
		_retire_player()
	_player = PlayerScene.instantiate()
	_player.last_white_frame = _last_white_frame
	_player.position = _room.entry_position(entry)
	add_child(_player)
	move_child(_player, _room_holder.get_index() + 1)  # the player draws on top of the room
	_player.reset_physics_interpolation()  # AR6: a teleport, never a smear
	# Methods and bound callables, never lambdas capturing the player (a captured RefCounted leaks).
	_player.died.connect(_on_player_died)
	_player.chain.banked.connect(Game.dive.add_carried)  # M1's banked embers are M2's carried ones
	_player.chain.changed.connect(Game.slot.record_chain)
	_player.pogo_hit.connect(_camera.kick.bind(CameraRig.POGO_SHAKE))
	_camera.follow(_player)


func _on_player_died() -> void:
	# D3: the tier turns the held embers and the carried ones into carried, a cache or nothing.
	_last_death = Game.slot.apply_death(Game.dive, _player.held_at_death, _room.id, _room.floor_spot(_safe_pos))
	var lost: int = _last_death.held_lost + _last_death.carried_lost
	if lost > 0:
		_player.popup_lost(lost)  # Easy loses nothing; Normal's carried went to the cache, not lost
	Game.slot.record_death()
	# Pauses with the tree (AR36) and ignores the time scale. A method, not an await, so the
	# connection dies with World if a test frees it first.
	get_tree().create_timer(RESPAWN_DELAY, false, false, true).timeout.connect(_respawn)


## AR25: the respawn room is always rebuilt, even when it is the current room: that is what keeps
## enemies killed this dive dead while the others return to their cells.
func _respawn() -> void:
	Game.clock.clear()  # AC3; player.die() already cleared at the moment of death
	var point := _respawn_point()
	_swap_pending = true
	_swap_room.call_deferred(point[0], point[1], true)


func _on_setting_changed(key: StringName) -> void:
	if key == &"brightness":
		_apply_ambient()


func _apply_ambient() -> void:
	var v := AMBIENT_LEVELS[Game.settings.brightness]
	_darkness.color = Color(v * AMBIENT_TINT.r, v * AMBIENT_TINT.g, minf(v * AMBIENT_TINT.b, 1.0))
