extends RefCounted
## Loads a room standalone for a test, the way World will hold it from Story 1.6: the room and a
## test player side by side under `parent`, the room at the origin (so room-local = global), plus
## a stub in group `world` that provides play_rect(). Not run by the runner (its name matches
## neither test_* nor smoke_*); tests preload it.
##   var h := RoomHarness.build(self, &"m1_shaft")   # {room, player, world}
##   ...
##   RoomHarness.free_all(h)

const PlayerScene := preload("res://scenes/actors/player.tscn")
const PLAY_WIDTH := 360.0  ## the play area inside the two 60 px gutters (UX DESIGN.md, Layout & Spacing)


## The 360 px play area centred on what the camera shows. Game code calls World.play_rect() from
## 1.6; until then only tests reach this stub.
class WorldStub extends Node2D:
	var camera: Camera2D

	func play_rect() -> Rect2:
		var size := Vector2(PLAY_WIDTH, camera.get_viewport_rect().size.y)
		return Rect2(camera.get_screen_center_position() - size / 2.0, size)


static func build(parent: Node, room_id: StringName) -> Dictionary:
	var room := RoomLoader.load_room(room_id)
	assert(room != null, "RoomHarness: room '%s' failed to load (errors above)" % room_id)
	parent.add_child(room)
	var player: Player = PlayerScene.instantiate()
	player.position = room.entry_position(&"spawn")
	parent.add_child(player)
	var cam: Camera2D = player.get_node("Camera")
	centre_camera(cam, room)
	var world := WorldStub.new()
	world.name = "WorldStub"
	world.camera = cam
	world.add_to_group("world")
	parent.add_child(world)
	return {room = room, player = player, world = world}


## Shaft.gd's interim framing (Story 1.5 D2): the room centred in the view, the side bands left
## for the gutters. camera_rig.gd replaces it in 1.6.
static func centre_camera(cam: Camera2D, room: Room) -> void:
	var b := room.bounds()
	var view_w := cam.get_viewport_rect().size.x
	cam.limit_left = int(b.position.x - (view_w - b.size.x) / 2.0)
	cam.limit_right = cam.limit_left + int(view_w)
	cam.limit_top = int(b.position.y)
	cam.limit_bottom = int(b.end.y)
	cam.reset_smoothing()


static func free_all(parts: Dictionary) -> void:
	for key: String in ["room", "player", "world"]:
		if is_instance_valid(parts.get(key)):
			parts[key].queue_free()
