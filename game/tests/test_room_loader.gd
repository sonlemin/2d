extends Node
## Rooms as text (Story 1.5, AR21–AR23): the pure validator, the build and the Room API.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd
## Bad rooms are only ever validated, never loaded: load_room_from_path() push_errors each error,
## and any error line fails the runner. Every node a case builds is freed before the case ends.

const DIR := "res://tests/rooms/"
const M1_SHAFT := "res://rooms/l1/m1_shaft.txt"

var _fail := 0


func run() -> void:
	_test_bad_fixtures()
	_test_inline_errors()
	await _test_ok_min()
	await _test_spawn_args_before_ready()
	await _test_m1_shaft()
	await _test_killed_cells()
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
	var three_p := _inline(ok.replace("#.....#\n#c", "#..P..#\n#c").replace("#.....#\n#.P", "#...P.#\n#.P"))
	_has(three_p, p + ":8:3 second 'P' (one spawn per room)", "three Ps: the first extra (grid order: the new row-1 P comes first)")
	_has(three_p, p + ":10:4 second 'P' (one spawn per room)", "three Ps: the second extra")
	_has(_inline(ok.replace("#.P.h.#\n###", "#.P.h.#\n#..")), p + ":8:3 'P' has nothing solid below it", "P in mid-air")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nspine=true")), p + ":7:1 spine room is 7 wide, must be 22", "a spine room not 22 wide")
	var exits := "exits=up:ok_min@x2, down:ok_min@x5"
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x3, down:ok_min@x5")), p + ":4:1 up exit column 3 is a solid cell", "an exit on a solid cell")
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x9, down:ok_min@x5")), p + ":4:1 up exit column 9 is outside the inner columns (1..5)", "an exit outside the grid")
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x0, down:ok_min@x5")), p + ":4:1 up exit column 0 is outside the inner columns (1..5)", "an exit on a corner column")
	# The opening stops before the corner, so an open corner is still a hole in the side wall.
	_has(_inline(ok.replace("##.####", "##.....")), p + ":6:7 hole in the room's edge that is not a declared exit", "an opening through the corner")
	_has(_inline(ok.replace("#.....#\n#.P", "#.#...#\n#.P")), p + ":4:1 up exit's entry cell (2, 1) is solid", "a wall in the up exit's entry cell")
	# Story 1.7 D3: an opening that runs wall to wall leaves no floor beside it to arrive on.
	var wide := ok.replace("down:ok_min@x5", "down:ok_min@x1").replace("#####.#", "#.....#")
	check(_inline(wide) == ([p + ":4:1 down exit has no floor beside its opening to arrive on"] as Array[String]),
			"a bottom opening with no floor beside it is the one error (got %s)" % [_inline(wide)])
	var walled := ok.replace("#c....#\n#####.#", "#c..#.#\n#####.#")
	check(_inline(walled).is_empty(), "a floor beside the opening is enough, whatever is above the opening (got %s)" % [_inline(walled)])
	var low := ok.replace("###...L\n#.....#", "###...L\n#####.#")
	check(_inline(low) == ([p + ":4:1 down exit has no floor beside its opening to arrive on"] as Array[String]),
			"a stand cell with a wall right above it has no headroom: the one error (got %s)" % [_inline(low)])
	_has(_inline(ok.replace(exits, "exits=up:ok_min@x4294967298, down:ok_min@x5")), p + ":4:1 exit 'up:ok_min@x4294967298' is not <up|down>:<room_id>@x<col>", "an exit column too long to be a cell")
	_has(_inline(ok.replace("zone=dusk", "zone=dusk\nobj=a@4294967297,1")), p + ":4:1 obj 'a@4294967297,1' is not <id>@<col>,<row>", "an obj cell too long to be a cell")
	_has(_inline(ok.replace("---\n", "---\n\n")), p + ":6:1 row 1 is empty (a blank line right after '---'?)", "a blank line after ---")
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
	_test_cling_key(ok, p)


## Story 1.10 D6: `cling=<from>-<to>` declares a narrow cling stretch, 0-based grid rows,
## inclusive, repeatable like obj (overlaps allowed). ok_min's grid is 7 rows (0..6).
func _test_cling_key(ok: String, p: String) -> void:
	var cling := func(lines: String) -> Array[String]:
		return _inline(ok.replace("zone=dusk", "zone=dusk\n" + lines))
	check(cling.call("cling=1-5").is_empty(), "a cling stretch inside the grid validates clean (got %s)" % [cling.call("cling=1-5")])
	check(cling.call("cling=1-3\ncling=2-6").is_empty(), "cling repeats, and stretches may overlap; the last row (6) is inside (got %s)" % [cling.call("cling=1-3\ncling=2-6")])
	_has(cling.call("cling=1to5"), p + ":4:1 cling '1to5' is not <from>-<to>", "a malformed cling")
	_has(cling.call("cling=-1-5"), p + ":4:1 cling '-1-5' is not <from>-<to>", "a negative cling row")
	_has(cling.call("cling=12345-2"), p + ":4:1 cling '12345-2' is not <from>-<to>", "a cling row too long to be a row")
	_has(cling.call("cling=5-1"), p + ":4:1 cling rows 5-1: <from> must be less than <to>", "a reversed cling")
	_has(cling.call("cling=3-3"), p + ":4:1 cling rows 3-3: <from> must be less than <to>", "a one-row cling (from == to)")
	_has(cling.call("cling=2-7"), p + ":4:1 cling rows 2-7 are outside the 7-row grid", "a cling past the last row")
	var two: Array[String] = cling.call("cling=1-3\ncling=x\ncling=4-9")
	check(two == ([p + ":5:1 cling 'x' is not <from>-<to>", p + ":6:1 cling rows 4-9 are outside the 7-row grid"] as Array[String]),
			"each bad cling line is reported on its own line, the good one is not (got %s)" % [two])


func _test_ok_min() -> void:
	var path := DIR + "ok_min.txt"
	check(_errors_of(path).is_empty(), "ok_min validates clean (got %s)" % [_errors_of(path)])
	var room := RoomLoader.load_room_from_path(path)
	check(room != null, "ok_min builds")
	if room == null:
		return
	add_child(room)
	check(room.id == &"ok_min" and room.zone == &"dusk" and not room.spine, "the header sets id, zone and spine")
	check(room.exits == ([{side = &"up", target = &"ok_min", col = 2, entry_cell = Vector2i(2, 1)},
			{side = &"down", target = &"ok_min", col = 5, entry_cell = Vector2i(4, 5)}] as Array[Dictionary]),
			"the exits are up@2 and down@5, arriving at (2, 1) and on the floor beside the hole at (4, 5) (got %s)" % [room.exits])
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
	check(room.entry_position(&"down") == Vector2(72, 84), "down: standing on the floor beside the bottom opening, never over it (got %s)" % room.entry_position(&"down"))
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


## The real room: M1's shaft at 22 columns, as sonlm approved it after playing it (Story 1.5 D1).
func _test_m1_shaft() -> void:
	check(_errors_of(M1_SHAFT).is_empty(), "m1_shaft validates clean (got %s)" % [_errors_of(M1_SHAFT)])
	var room := RoomLoader.load_room(&"m1_shaft")
	check(room != null, "load_room(&\"m1_shaft\") resolves through the index and builds")
	if room == null:
		return
	add_child(room)
	check(room.spine and room.zone == &"violet" and room.bounds() == Rect2(0, 0, 352, 1680),
			"a violet spine room, 352 x 1680 (got %s)" % room.bounds())
	var hovers := 0
	var walkers := 0
	var lurkers := 0
	for n in room.get_children():
		if n is Crawler:
			if n.hover:
				hovers += 1
			else:
				walkers += 1
		elif n is Lurker:
			lurkers += 1
	check(hovers == 36 and walkers == 5 and lurkers == 4, "36 hoverers, 5 walkers, 4 lurkers (got %d, %d, %d)" % [hovers, walkers, lurkers])
	# Ledge rows: a solid cell inside the outer walls with an open cell above it.
	var ledges: Array[int] = []
	for r in range(1, room.size_cells.y):
		for c in range(1, room.size_cells.x - 1):
			if room.is_solid(Vector2i(c, r)) and not room.is_solid(Vector2i(c, r - 1)):
				ledges.append(r)
				break
	# This pins the layout sonlm approved; FR57's gap rule is smoke_rooms' sweep, for every spine room (1.10).
	check(ledges == ([6, 24, 41, 57, 72, 85, 103] as Array[int]), "ledge rows 6, 24, 41, 57, 72, 85, 103 (got %s)" % [ledges])
	check(room.exits == ([{side = &"up", target = &"m1_shaft", col = 3, entry_cell = Vector2i(3, 1)},
			{side = &"down", target = &"m1_shaft", col = 1, entry_cell = Vector2i(3, 102)}] as Array[Dictionary]),
			"R16: the exits are up@3 and down@1, both to m1_shaft; arrival from below stands at (3, 102) (got %s)" % [room.exits])
	check(not room.is_solid(Vector2i(1, 104)) and not room.is_solid(Vector2i(2, 104)) and room.is_solid(Vector2i(3, 104)),
			"the floor hole is cols 1-2")
	room.queue_free()
	await get_tree().process_frame


## Story 1.7 D5: killable enemies carry their room and cell, and a dive's killed cells are skipped.
func _test_killed_cells() -> void:
	var all := RoomLoader.load_room_from_path(DIR + "ok_min.txt")
	add_child(all)
	var walker: Crawler = null
	var hover: Crawler = null
	var lurker: Lurker = null
	for n in all.get_children():
		if n is Crawler:
			if n.hover:
				hover = n
			else:
				walker = n
		elif n is Lurker:
			lurker = n
	check(walker != null and walker.room_id == &"ok_min" and walker.cell == Vector2i(1, 5), "the walker knows its room and cell (got %s)" % [str([walker.room_id, walker.cell]) if walker else "none"])
	check(hover != null and hover.cell == Vector2i(4, 2), "...and so does the hoverer (got %s)" % (hover.cell if hover else "none"))
	check(lurker != null and not ("cell" in lurker), "a lurker is not killable, so it has no cell")
	var dive := DiveState.new()
	dive.mark_killed(&"ok_min", Vector2i(1, 5))
	var some := RoomLoader.load_room_from_path(DIR + "ok_min.txt", dive)
	add_child(some)
	var cells := some.get_children().filter(func(n: Node) -> bool: return n is Crawler).map(func(c: Crawler) -> Vector2i: return c.cell)
	check(cells == [Vector2i(4, 2)], "with that cell marked killed, the walker is skipped and the hoverer still built (got %s)" % [cells])
	check(some.get_children().any(func(n: Node) -> bool: return n is Lurker), "...and the lurker is still built")
	all.queue_free()
	some.queue_free()
	await get_tree().process_frame
