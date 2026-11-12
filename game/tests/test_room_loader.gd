extends Node
## Rooms as text (Story 1.5, AR21–AR23): the pure validator, the build and the Room API.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd
## Bad rooms are only ever validated, never loaded: load_room_from_path() push_errors each error,
## and any error line fails the runner. Every node a case builds is freed before the case ends.

const DIR := "res://tests/rooms/"

var _fail := 0


func run() -> void:
	_test_bad_fixtures()
	_test_inline_errors()
	await _test_ok_min()
	await _test_spawn_args_before_ready()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _errors_of(path: String) -> Array[String]:
	return RoomLoader.validate(path, RoomLoader.parse(FileAccess.get_file_as_string(path)))


## Each fixture is ok_min with one fault, so its list must be exactly that one message, at the
## file line and column an editor would jump to.
func _test_bad_fixtures() -> void:
	var cases := {
		"bad_unequal_rows": "8:1 row is 6 wide, row 1 is 7",
		"bad_unknown_char": "10:4 unknown char 'x'",
		"bad_duplicate_id": "6:1 duplicate obj id 'a'",
		"bad_edge_hole": "10:1 hole in the room's edge that is not a declared exit",
	}
	for name: String in cases:
		var path := DIR + name + ".txt"
		var want: String = path + ":" + cases[name]
		var got := _errors_of(path)
		check(got == ([want] as Array[String]), "%s gives exactly '%s' (got %s)" % [name, want, got])


## ok_min's text with one change, validated as if it were the file at `path`.
func _inline(text: String, path := "res://x/ok_min.txt") -> Array[String]:
	return RoomLoader.validate(path, RoomLoader.parse(text))


func _has(errors: Array[String], want: String, what: String) -> void:
	check(want in errors, "%s -> '%s' (got %s)" % [what, want, errors])


func _test_inline_errors() -> void:
	var ok := FileAccess.get_file_as_string(DIR + "ok_min.txt")
	var p := "res://x/ok_min.txt"
	check(_inline(ok).is_empty(), "ok_min's text validates clean under any folder (got %s)" % [_inline(ok)])
	check(_inline(ok.replace("\n", "\r\n") + "\n\n").is_empty(), "CRLF line ends and trailing blank lines are ignored")
	_has(_inline(ok.replace("---\n", "")), p + ":1:1 no '---' line between the header and the grid", "no ---")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\ncolour=red")), p + ":4:1 unknown key 'colour'", "an unknown key")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nzone=umber")), p + ":4:1 key 'zone' repeated (first on line 3)", "a repeated key")
	_has(_inline(ok.replace("zone=dusk", "zone=teal")), p + ":3:1 zone 'teal' is not one of dusk, umber, violet", "a bad zone")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nspine=yes")), p + ":4:1 spine 'yes' is not true or false", "a bad spine value")
	_has(_inline(ok.replace("zone=dusk\n", "")), p + ":1:1 missing 'zone='", "a missing zone")
	_has(_inline(ok, "res://x/other.txt"), "res://x/other.txt:2:1 id 'ok_min' is not the file name 'other.txt'", "id != file name")
	_has(_inline(ok.replace("#.....#\n#c", "#..P..#\n#c")), p + ":10:4 second 'P' (one spawn per room)", "two Ps")
	_has(_inline(ok.replace("#.P.h.#\n###", "#.P.h.#\n#..")), p + ":8:3 'P' has nothing solid below it", "P in mid-air")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nspine=true")), p + ":7:1 spine room is 7 wide, must be 22", "a spine room not 22 wide")
	var exits := "exits=up:ok_min@x2, down:ok_min@x5"
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x3, down:ok_min@x5")), p + ":4:1 up exit column 3 is a solid cell", "an exit on a solid cell")
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x9, down:ok_min@x5")), p + ":4:1 up exit column 9 is outside the grid (0..6)", "an exit outside the grid")
	_has(_inline(ok.replace(exits, exits + ", up:ok_min@x2")), p + ":4:1 two 'up' exits", "two up exits")
	_has(_inline(ok.replace(exits, "exits=left:ok_min@y2")), p + ":4:1 exit 'left:ok_min@y2' is not <up|down>:<room_id>@x<col>", "a left exit (E4)")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nobj=a@9,1")), p + ":4:1 obj cell (9, 1) is outside the 7 x 7 grid", "an obj outside the grid")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nobj=a@1")), p + ":4:1 obj 'a@1' is not <id>@<col>,<row>", "a malformed obj")
	# The up exit's opening is col 2 only; removing the exit turns it into a hole.
	_has(_inline(ok.replace(exits, "exits=down:ok_min@x5")), p + ":6:3 hole in the room's edge that is not a declared exit", "an undeclared top opening")
	# M1's in-wall rule looked only at the neighbours; with 1-tile walls the edge counts too (D5).
	check(_inline(ok.replace("###...L", "###...#")).is_empty(), "an edge L counts as solid, like the wall it replaces")
	var errs := _inline(ok.replace("zone=dusk", "zone=teal\ncolour=red"))
	check(errs.size() == 2, "every error is reported, not just the first (got %s)" % [errs])


func _test_ok_min() -> void:
	var path := DIR + "ok_min.txt"
	check(_errors_of(path).is_empty(), "ok_min validates clean (got %s)" % [_errors_of(path)])
	var room := RoomLoader.load_room_from_path(path)
	check(room != null, "ok_min builds")
	if room == null:
		return
	add_child(room)
	check(room.id == &"ok_min" and room.zone == &"dusk" and not room.spine, "the header sets id, zone and spine")
	check(room.exits == ([{side = &"up", target = &"ok_min", col = 2}, {side = &"down", target = &"ok_min", col = 5}] as Array[Dictionary]),
			"the exits are up@2 and down@5 (got %s)" % [room.exits])
	var walkers := 0
	var hovers := 0
	var lurkers := 0
	for n in room.get_children():
		if n is Crawler:
			if n.hover:
				hovers += 1
			else:
				walkers += 1
		elif n is Lurker:
			lurkers += 1
	check(walkers == 1 and hovers == 1 and lurkers == 1, "one c (hover false), one h (hover true), one L (got %d, %d, %d)" % [walkers, hovers, lurkers])
	check(room.is_solid(Vector2i(6, 3)), "the edge lurker's cell is a wall tile")
	check(not room.is_solid(Vector2i(2, 0)) and room.is_solid(Vector2i(3, 0)), "the up exit's cell is open, its neighbour is wall")
	var rims: Array = room.get_node("Rims").get_children().map(func(r: ColorRect) -> Vector2: return r.position)
	rims.sort()
	var want_rims := [Vector2(16, 48), Vector2(16, 96), Vector2(32, 48), Vector2(32, 96), Vector2(48, 96), Vector2(64, 96)]
	check(rims == want_rims, "a rim on every solid cell under an open one, and nowhere else (got %s)" % [rims])
	check(room.bounds() == Rect2(0, 0, 112, 112), "bounds() is 7 x 7 tiles (got %s)" % room.bounds())
	check(room.entry_position(&"spawn") == Vector2(40, 36), "spawn: the P cell, feet on the tile below (got %s)" % room.entry_position(&"spawn"))
	check(room.entry_position(&"up") == Vector2(40, 20), "up: one cell inside the top opening (got %s)" % room.entry_position(&"up"))
	check(room.entry_position(&"down") == Vector2(88, 84), "down: one cell inside the bottom opening (got %s)" % room.entry_position(&"down"))
	check(room.has_entry(&"spawn") and room.has_entry(&"up") and not room.has_entry(&"nope"), "has_entry knows spawn and up, not nope")
	check(room.cell_centre(Vector2i(1, 5)) == Vector2(24, 88), "cell_centre is the tile's middle")
	room.queue_free()
	await get_tree().process_frame


## AR23: a spawned node's _ready() already sees its args.
func _test_spawn_args_before_ready() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar flag := false\nvar seen := false\nfunc _ready() -> void:\n\tseen = flag\n"
	script.reload()
	var proto := Node2D.new()
	proto.set_script(script)
	var scene := PackedScene.new()
	scene.pack(proto)
	proto.queue_free()
	var room := Room.new()
	add_child(room)
	var node := room.spawn(scene, Vector2(5, 7), {flag = true})
	check(node.get(&"seen") == true and node.position == Vector2(5, 7) and node.get_parent() == room,
			"spawn() sets the args before add_child, so _ready sees them, and the room owns the node")
	room.queue_free()
	await get_tree().process_frame
