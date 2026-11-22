extends Node
## Headless smoke test of the active zone (Story 1.18 AC2, AC3; UX-DR4, UX-DR5, UX-DR15): World
## sets Game.palette from each room it builds (boot, exit, respawn), the gutter strips and the clear
## colour follow it, and a popup made in a room is outlined in that zone's surface. Expected colours
## are DESIGN.md literals, never read back from Palettes.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_palettes.gd
## A (dusk): P on a ledge, a floor hole at cols 1-2 down to B. B (umber): a ceiling gap up to A.

const WorldScene := preload("res://scenes/world/world.tscn")
const TMP := "user://smoke_palettes_tmp"
const A := &"t_zone_a"
const B := &"t_zone_b"
## DESIGN colors: gutter-dusk, gutter-umber, zone-dusk-0 and zone-umber-0 (the two surfaces),
## chain-amber (the warm-up label's glyph colour, Fx.SPARK).
const GUTTER_DUSK := "18100b"
const GUTTER_UMBER := "110d0b"
const SURFACE_DUSK := Color("#2b1d14")
const SURFACE_UMBER := Color("#1e1714")
const AMBER := Color("#ffd27a")

var _fail := 0
var _world: World
var _changed := 0
var _warm: LabelSettings  # the warm-up label's settings, read as each room is entered


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	Game.store.dir = TMP
	RoomLoader.add_root("res://tests/rooms/zones")
	# A session that last showed violet (a menu, an earlier dive): boot must set the start room's zone,
	# not keep the last one, and the strips Gutters painted first must follow before the first frame.
	Game.palette.set_zone(&"violet")
	Game.palette.changed.connect(_on_changed)
	_world = WorldScene.instantiate()
	_world.start_room = A
	_world.room_entered.connect(_on_room_entered)  # before the boot build, which emits it
	add_child(_world)
	await frames(2)
	test_boot()
	await test_exit()
	test_popup()
	await test_respawn()
	await test_same_zone()
	Game.palette.changed.disconnect(_on_changed)
	_world.queue_free()
	await frames(1)
	Game.reset_for_tests()
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


func _on_changed() -> void:
	_changed += 1


## Fx.warm_up()'s label ("x") is freed three frames after the build, so it is read here, on the
## signal the build ends with (code review of 1.18).
func _on_room_entered(_room_id: StringName) -> void:
	_warm = null
	for n in _world.current_room().get_children():
		if n is Label and (n as Label).text == "x":
			_warm = (n as Label).label_settings


## AC3 (D8): a popup made in the current room is outlined in `surface`.
func _popup_outlined_in(surface: Color) -> bool:
	var room := _world.current_room()
	Fx.popup(room, Vector2(40, 40), "+1", Color.WHITE)
	var label: Label
	for n in room.get_children():
		if n is Label and (n as Label).text == "+1":
			label = n
	return label != null and label.label_settings == TextStyle.play_text(Color.WHITE, surface)


## The two gutter strips, picked by x (0 and 420), and the clear colour, as hex.
func _gutter_colours() -> Array[String]:
	var out: Array[String] = ["", "", RenderingServer.get_default_clear_color().to_html(false)]
	for n in _world.get_node("UI/Gutters").get_children():
		var strip := n as ColorRect
		if strip == null:
			continue
		if strip.position.x == 0.0:
			out[0] = strip.color.to_html(false)
		elif strip.position.x == 420.0:
			out[1] = strip.color.to_html(false)
	return out


## AC2/AC3: World's first room build sets the zone; the strips and the clear colour are its gutter.
func test_boot() -> void:
	check(_world.current_room().id == A and Game.palette.zone() == &"dusk" and _changed == 1, "boot in t_zone_a from violet: the zone is dusk, one changed (got %s, %d)" % [Game.palette.zone(), _changed])
	var got := _gutter_colours()
	check(got == ([GUTTER_DUSK, GUTTER_DUSK, GUTTER_DUSK] as Array[String]), "...both strips (x 0, x 420) and the clear colour are gutter-dusk #18100b (got %s)" % [got])
	check(_warm != null and _warm == TextStyle.play_text(AMBER, SURFACE_DUSK), "...and the room's warm-up label was outlined in zone-dusk-0 #2b1d14, not the last zone's surface")


## AC2/AC3: an exit into an umber room repaints the strips and the clear colour, with one changed.
func test_exit() -> void:
	_changed = 0
	_world.enter_room(B, &"up")
	await frames(3)
	check(_world.current_room().id == B and Game.palette.zone() == &"umber", "enter_room(t_zone_b): the zone is umber (room %s, zone %s)" % [_world.current_room().id, Game.palette.zone()])
	var got := _gutter_colours()
	check(got == ([GUTTER_UMBER, GUTTER_UMBER, GUTTER_UMBER] as Array[String]), "...both strips and the clear colour are gutter-umber #110d0b (got %s)" % [got])
	check(_changed == 1, "...and changed fired exactly once for the swap (got %d)" % _changed)
	check(_warm != null and _warm == TextStyle.play_text(AMBER, SURFACE_UMBER), "...and t_zone_b's warm-up label was outlined in zone-umber-0 #1e1714")


## AC3 (D8): a popup made in the umber room is outlined in the umber surface.
func test_popup() -> void:
	check(_popup_outlined_in(SURFACE_UMBER), "Fx.popup in t_zone_b is play_text outlined in zone-umber-0 #1e1714")


## AC2: a death in B respawns in A, the start room, so the zone is dusk again.
func test_respawn() -> void:
	_changed = 0
	(get_tree().get_first_node_in_group("player") as Player).die()
	await frames(int(ceil((World.RESPAWN_DELAY + 0.1) * Engine.physics_ticks_per_second)))
	check(_world.current_room().id == A and Game.palette.zone() == &"dusk", "a death in t_zone_b respawns in t_zone_a, back on dusk (room %s, zone %s)" % [_world.current_room().id, Game.palette.zone()])
	var got := _gutter_colours()
	check(got == ([GUTTER_DUSK, GUTTER_DUSK, GUTTER_DUSK] as Array[String]), "...and the strips and the clear colour are dusk again (got %s)" % [got])
	check(_changed == 1, "...with exactly one changed for the respawn: no other zone is shown on the way (got %d)" % _changed)
	check(_popup_outlined_in(SURFACE_DUSK), "...and Fx.popup in t_zone_a is outlined in zone-dusk-0 #2b1d14")


## D2: a room of the same zone redraws nothing.
func test_same_zone() -> void:
	var before := _world.current_room()
	var n := _changed
	_world.enter_room(A, &"down")
	await frames(3)
	check(_world.current_room() != before and _world.current_room().id == A, "enter_room(t_zone_a) from t_zone_a builds a new room")
	check(_changed == n and Game.palette.zone() == &"dusk", "...and a same-zone swap emits no changed (got %d more)" % (_changed - n))
