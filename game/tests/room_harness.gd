extends RefCounted
## Loads a room standalone for a test, the way World holds it (Story 1.6): the room, a test player
## and a CameraRig side by side under `parent`, the room at the origin (so room-local = global),
## plus a stub in group `world` that provides play_rect() and current_room() like World does.
## Not run by the runner (its name matches neither test_* nor smoke_*); tests preload it.
##   var h := RoomHarness.build(self, &"m1_shaft")   # {room, player, camera, world}
##   ...
##   RoomHarness.free_all(h)

const PlayerScene := preload("res://scenes/actors/player.tscn")


## World's two queries, without World's spawn and respawn: the lurkers read play_rect() and the
## player parents its popups to current_room().
class WorldStub extends Node2D:
	var camera: CameraRig
	var room: Room

	func play_rect() -> Rect2:
		return camera.play_rect()

	func current_room() -> Room:
		return room


## `entry`: where the player starts. Most rooms have no `P`, so pass &"up" (or a later anchor) there.
static func build(parent: Node, room_id: StringName, entry := &"spawn") -> Dictionary:
	var room := RoomLoader.load_room(room_id)
	assert(room != null, "RoomHarness: room '%s' failed to load (errors above)" % room_id)
	parent.add_child(room)
	var player: Player = PlayerScene.instantiate()
	player.position = room.entry_position(entry)
	parent.add_child(player)
	var cam := CameraRig.new()
	cam.name = "CameraRig"
	cam.position_smoothing_enabled = true  # as in world.tscn
	cam.position_smoothing_speed = 8.0
	parent.add_child(cam)
	cam.apply_limits(room.bounds())
	cam.follow(player)
	cam.snap()
	var world := WorldStub.new()
	world.name = "WorldStub"
	world.camera = cam
	world.room = room
	world.add_to_group("world")
	parent.add_child(world)
	return {room = room, player = player, camera = cam, world = world}


static func free_all(parts: Dictionary) -> void:
	for key: String in ["room", "player", "camera", "world"]:
		if is_instance_valid(parts.get(key)):
			parts[key].queue_free()
