class_name World
extends Node2D
## The game scene (AR19): holds the current room, the player, the camera, the darkness and the UI
## layer. Rooms change only through one swap path (AR24), for the first room, an exit and a
## respawn alike: always deferred, the old room out of the tree before it is freed. A death never
## reloads the scene (AR25): World waits RESPAWN_DELAY, rebuilds the respawn room (so enemies
## killed this dive stay dead) and spawns a fresh Player, then emits `player_spawned`, so anything
## bound to the player rebinds there.

## Every (re)spawn, including the first: bind to `player.chain` / the player here, never once.
signal player_spawned(player: Player)
## Every room entry, including the first and a respawn's rebuild, after the player is placed.
signal room_entered(room_id: StringName)

const PlayerScene := preload("res://scenes/actors/player.tscn")
## Applies the ≤ 6 light budget each physics tick, after the actors (Story 1.12 D5).
const LightBudgetNode := preload("res://scripts/world/light_budget.gd")
## The dive starts here until the slot's resume point replaces it (Stories 1.21 and 1.38).
const START_ROOM := &"m1_shaft"
## s between a death and the respawn, the M1 value; the death card replaces this wait in 1.29.
const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). `Settings.brightness` picks the level;
## until Options (1.36) it changes only through DevTools' `--set=brightness:N`, for one session.
## Lower = more tension; too low and darkness turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # keeps the violet cast of the Edge palette

## Where a dive with no respawn point starts, and at which entry. Tests set them before add_child;
## DevTools' --room= sets them from inside _ready, before the first room is built (Story 1.11 D5).
var start_room: StringName = START_ROOM
var start_entry: StringName = &"spawn"

var _room: Room
var _player: Player
var _swap_pending := false

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
	# The entry scene boots Game once: it loads settings.json and arms its writes (Story 1.4 D6).
	# A test adds World by hand and is never the current scene, so tests can't touch the real
	# settings.json even through World.
	if get_tree().current_scene == self:
		Game.boot()
	_apply_ambient()
	# A method, not a lambda: the connection drops when World is freed.
	Game.settings.changed.connect(_on_setting_changed)
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


## AR24: the one way into another room for an exit (and later a station or a scripted moment).
## Deferred, so it never runs inside a physics callback; a second call before it runs is dropped.
## Ignored while the player is dead: the respawn rebuilds the respawn room anyway.
func enter_room(room_id: StringName, entry: StringName) -> void:
	if _swap_pending or not _player_alive():
		return
	_swap_pending = true
	_swap_room.call_deferred(room_id, entry, false)


## Exits are polled here, not overlapped (D2, as crawler contact is): the body centre past the
## floor or the ceiling crosses that side's exit.
func _physics_process(_delta: float) -> void:
	if _swap_pending or not _player_alive():
		return
	var side := &""
	if _player.position.y > _room.bounds().end.y:
		side = &"down"
	elif _player.position.y < 0.0:
		side = &"up"
	if side == &"":
		return
	var exit := _room.exit(side)
	if exit.is_empty():
		_player.die()  # a closed edge was crossed (tunnelling): never fall forever
		return
	# Crossing a floor opening arrives at the target's top entry, a ceiling opening at its bottom.
	_on_exit_reached(exit.target, &"up" if side == &"down" else &"down")


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
			# A bad respawn point (save data from 1.21): the dive's start instead. DevTools checks
			# --room= before it sets the start, so this never runs for a dev room.
			_swap_room(start_room, start_entry, true)
		else:
			assert(false, "World: the start room '%s' failed to load (errors above)" % start_room)
		return
	if respawn and is_instance_valid(_player):
		# Out of groups `player` / `light_source` before the new room's predators run _ready.
		remove_child(_player)
		_player.queue_free()
		_player = null
	if _room != null:
		_room_holder.remove_child(_room)  # its predators and lights leave their groups now
		_room.queue_free()
	_room_holder.add_child(room)
	_room = room
	Fx.warm_up(room, room.entry_position(entry))  # AR46, Story 1.16 D10: each shared material's first draw is paid at the load
	if respawn:
		_spawn_player(entry)
	else:
		_player.position = room.entry_position(entry)
		# D3: from above the fall carries on across the cut; any other arrival starts still.
		if entry != &"up":
			_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()  # AR6: a teleport, never a smear
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


## A fresh Player at `entry` in the current room; the old one, if any, goes first.
func _spawn_player(entry: StringName) -> void:
	if is_instance_valid(_player):
		remove_child(_player)  # leaves group `player` now, not at the end of the frame
		_player.queue_free()
	_player = PlayerScene.instantiate()
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
