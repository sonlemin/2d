class_name World
extends Node2D
## The game scene (AR19): holds the current room, the player, the camera, the darkness and the UI
## layer. A death never reloads the scene (AR25): World waits RESPAWN_DELAY, spawns a fresh Player
## at the respawn point and emits `player_spawned`, so anything bound to the player rebinds there.
## Room swaps, exits and the rebuild on death arrive in Story 1.7; until then the room stays as it
## is, so an enemy killed this dive stays dead (D4).

## Every (re)spawn, including the first: bind to `player.chain` / the player here, never once.
signal player_spawned(player: Player)

const PlayerScene := preload("res://scenes/actors/player.tscn")
## The dive starts here until the slot's resume point replaces it (Stories 1.21 and 1.38).
const START_ROOM := &"m1_shaft"
## s between a death and the respawn, the M1 value; the death card replaces this wait in 1.29.
const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). `Settings.brightness` picks the level;
## DevTools sets it from 1.11 until Options (1.36). Lower = more tension; too low and darkness
## turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # keeps the violet cast of the Edge palette

var _room: Room
var _player: Player

@onready var _darkness: CanvasModulate = $Darkness
@onready var _room_holder: Node2D = $RoomHolder
@onready var _camera: CameraRig = $Camera


func _ready() -> void:
	add_to_group("world")
	# The entry scene boots Game once: it loads settings.json and arms its writes (Story 1.4 D6).
	# A test adds World by hand and is never the current scene, so tests can't touch the real
	# settings.json even through World.
	if get_tree().current_scene == self:
		Game.boot()
	_apply_ambient()
	# A method, not a lambda: the connection drops when World is freed.
	Game.settings.changed.connect(_on_setting_changed)
	_room = RoomLoader.load_room(START_ROOM)
	assert(_room != null, "%s failed to load: its content errors are above" % START_ROOM)
	_room_holder.add_child(_room)
	_camera.apply_limits(_room.bounds())
	_spawn_player()


## AR20: what counts as "on screen", in world coordinates: the play area inside the gutters.
func play_rect() -> Rect2:
	return _camera.play_rect()


func current_room() -> Room:
	return _room


func _physics_process(_delta: float) -> void:
	# Falling out of the room kills until 1.7 wires the bottom exit (R16 loop).
	if _player != null and not _player.is_dead and _player.position.y > _room.bounds().end.y + 32:
		_player.die()


## First spawn and respawn are one path, so both emit player_spawned.
func _spawn_player() -> void:
	if _player != null and is_instance_valid(_player):
		remove_child(_player)  # leaves group `player` now, not at the end of the frame
		_player.queue_free()
	var room_id := Game.dive.respawn_room if Game.dive.respawn_room != &"" else _room.id
	var entry := Game.dive.respawn_entry if Game.dive.respawn_entry != &"" else &"spawn"
	assert(room_id == _room.id, "cross-room respawn goes through enter_room() from Story 1.7")
	assert(_room.has_entry(entry), "%s has no entry '%s'" % [_room.id, entry])
	_player = PlayerScene.instantiate()
	_player.position = _room.entry_position(entry)  # 1.7: reset_physics_interpolation() here
	add_child(_player)
	move_child(_player, _room_holder.get_index() + 1)  # the player draws on top of the room
	# Methods and bound callables, never lambdas capturing the player (a captured RefCounted leaks).
	_player.died.connect(_on_player_died)
	_player.chain.banked.connect(Game.dive.add_carried)  # M1's banked embers are M2's carried ones
	_player.chain.changed.connect(Game.slot.record_chain)
	_player.pogo_hit.connect(_camera.kick.bind(CameraRig.POGO_SHAKE))
	_camera.follow(_player)
	_camera.snap()
	player_spawned.emit(_player)


func _on_player_died() -> void:
	Game.slot.record_death()
	# Pauses with the tree (AR36) and ignores the time scale. A method, not an await, so the
	# connection dies with World if a test frees it first.
	get_tree().create_timer(RESPAWN_DELAY, false, false, true).timeout.connect(_respawn)


func _respawn() -> void:
	Game.clock.clear()  # AC3; player.die() already cleared at the moment of death
	_spawn_player()


func _on_setting_changed(key: StringName) -> void:
	if key == &"brightness":
		_apply_ambient()


func _apply_ambient() -> void:
	var v := AMBIENT_LEVELS[Game.settings.brightness]
	_darkness.color = Color(v * AMBIENT_TINT.r, v * AMBIENT_TINT.g, minf(v * AMBIENT_TINT.b, 1.0))
