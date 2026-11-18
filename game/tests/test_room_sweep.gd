extends Node
## The pure room sweeps (Story 1.10 D2, D4–D7, D11) on inline grids: each rule has a sample that
## fires and a near-miss that stays quiet, so a sweep that can't fail is caught here, not in E4.
## smoke_rooms runs the same functions over every room file.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_sweep.gd

const RoomSweep := preload("res://tests/room_sweep.gd")
const NO_HAZARDS: Array[String] = []
## A sample hazard char: RoomLegend.HAZARDS is empty until 1.19 adds the spike.
const X_HAZARD: Array[String] = ["x"]
const MAX_ROWS := 19  ## floor(Spec.LEDGE_FALL_MAX 315 / 16): the samples pin the boundary at 19 / 20

var _fail := 0


func run() -> void:
	_test_room_files()
	_test_is_dev()
	_test_record()
	_test_ledge_rows()
	_test_spine_gaps()
	_test_stretch_widths()
	_test_hazard_pits()
	_test_exit_falls()
	_test_duplicate_ids()
	_test_links()
	_test_arrival()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## A spine-width shaft `h` rows tall: a solid ceiling, open rows between 1-tile walls, a 4-cell wall
## ledge (columns 1–4) on each row in `ledges`, and a floor with a hole at columns 1–2.
func _shaft(h: int, ledges: Array) -> Array[String]:
	var g: Array[String] = []
	for r in h:
		if r == 0:
			g.append("#".repeat(22))
		elif r == h - 1:
			g.append("#.." + "#".repeat(19))
		elif r in ledges:
			g.append("#####" + ".".repeat(16) + "#")
		else:
			g.append("#" + ".".repeat(20) + "#")
	return g


func _test_room_files() -> void:
	var files := RoomSweep.room_files("res://tests/rooms")
	var sorted := files.duplicate()
	sorted.sort()
	check(files == sorted, "room_files is sorted by path (got %s)" % [files])
	check("res://tests/rooms/ok_min.txt" in files and "res://tests/rooms/swap/t_swap_a.txt" in files,
			"room_files walks subfolders too (ok_min and swap/t_swap_a are both found)")
	check(files.all(func(f: String) -> bool: return f.get_extension() == "txt"), "room_files lists .txt files only")
	check(RoomSweep.room_files("res://tests/no_such_dir").is_empty(), "a missing root lists nothing (the caller's sentinel names it)")


func _test_is_dev() -> void:
	check(RoomSweep.is_dev("res://rooms/dev/perf_worst.txt"), "a room under rooms/dev/ is a dev room")
	check(not RoomSweep.is_dev("res://rooms/l1/m1_shaft.txt"), "a layer room is not")
	check(not RoomSweep.is_dev("res://rooms/devil/a.txt") and not RoomSweep.is_dev("res://rooms/l1/dev/a.txt"),
			"near misses: rooms/devil/ and a dev/ folder deeper down are not the dev folder")


func _test_record() -> void:
	var text := FileAccess.get_file_as_string("res://tests/rooms/ok_min.txt").replace("zone=dusk", "zone=dusk\nspine=true\ncling=1-3\ncling=x\ncling=2-6\nobj=a@1,1\nobj=b@2,2")
	var rec := RoomSweep.record("res://x/ok_min.txt", RoomLoader.parse(text))
	check(rec.id == "ok_min" and rec.spine and rec.grid.size() == 7, "record: the id is the base name, spine read, grid kept (got %s, %s, %d)" % [rec.id, rec.spine, rec.grid.size()])
	check(rec.exits == [{side = "up", target = "ok_min", col = 2}, {side = "down", target = "ok_min", col = 5}],
			"record: the exits (got %s)" % [rec.exits])
	check(rec.objs == (["a", "b"] as Array[String]), "record: the obj ids (got %s)" % [rec.objs])
	check(rec.clings == ([Vector2i(1, 3), Vector2i(2, 6)] as Array[Vector2i]), "record: the cling stretches, a malformed one skipped (validate() names it) (got %s)" % [rec.clings])


func _test_ledge_rows() -> void:
	var g := _shaft(30, [5, 24])
	check(RoomSweep.ledge_rows(g, NO_HAZARDS) == ([5, 24, 29] as Array[int]), "ledge rows: the two wall ledges and the floor (got %s)" % [RoomSweep.ledge_rows(g, NO_HAZARDS)])
	# A floor whose every open-topped cell is under a hazard is no place to land.
	var spiked := _shaft(30, [5, 24])
	spiked[23] = "#xxxx" + ".".repeat(16) + "#"
	check(RoomSweep.ledge_rows(spiked, X_HAZARD) == ([5, 29] as Array[int]), "a ledge covered by hazards is not a ledge (got %s)" % [RoomSweep.ledge_rows(spiked, X_HAZARD)])
	check(RoomSweep.ledge_rows(spiked, NO_HAZARDS) == ([5, 24, 29] as Array[int]), "control: the same grid with no hazard chars keeps the ledge (got %s)" % [RoomSweep.ledge_rows(spiked, NO_HAZARDS)])
	var half := _shaft(30, [5, 24])
	half[23] = "#xxx." + ".".repeat(16) + "#"
	check(24 in RoomSweep.ledge_rows(half, X_HAZARD), "near miss: one open-topped cell beside the hazards still makes it a ledge")
	# The side walls are never ledges, even with open cells above (column 0 / 21 under an opening).
	var side := _shaft(30, [])
	side[10] = "." + ".".repeat(20) + "#"
	check(not 11 in RoomSweep.ledge_rows(side, NO_HAZARDS), "the outer wall columns never make a ledge")


func _test_spine_gaps() -> void:
	var none: Array[Vector2i] = []
	check(RoomSweep.spine_gap_errors("s", _shaft(30, [5, 24]), none, NO_HAZARDS, MAX_ROWS).is_empty(),
			"near miss: a 19-row gap (304 px) is legal")
	var errs := RoomSweep.spine_gap_errors("s", _shaft(30, [4, 24]), none, NO_HAZARDS, MAX_ROWS)
	check(errs == (["s: the fall from row 4 to row 24 is 20 rows, over 19 (no ledge or cling stretch between)"] as Array[String]),
			"a 20-row gap is the one error, naming both rows (got %s)" % [errs])
	# D14 #4: a 25-row gap fails uncovered and passes when a cling stretch covers it.
	var long := _shaft(40, [5, 30])
	check(RoomSweep.spine_gap_errors("s", long, none, NO_HAZARDS, MAX_ROWS).size() == 1, "a 25-row gap with no stretch fails")
	check(RoomSweep.spine_gap_errors("s", long, [Vector2i(8, 20)] as Array[Vector2i], NO_HAZARDS, MAX_ROWS).is_empty(),
			"the same gap with a cling stretch (rows 8–20) inside it passes")
	var flat: Array[String] = ["#".repeat(22)]
	for r in 8:
		flat.append("#" + ".".repeat(20) + "#")
	flat.append("#.." + ".".repeat(19))
	check(RoomSweep.spine_gap_errors("s", flat, none, NO_HAZARDS, MAX_ROWS) == (["s: a spine room with no ledge or cling stretch to land on"] as Array[String]),
			"a spine room with nowhere to land fails, rather than passing with no gaps to measure (got %s)" % [RoomSweep.spine_gap_errors("s", flat, none, NO_HAZARDS, MAX_ROWS)])
	check(RoomSweep.spine_gap_errors("s", flat, [Vector2i(2, 5)] as Array[Vector2i], NO_HAZARDS, MAX_ROWS).is_empty(), "near miss: a cling stretch alone is somewhere to land")
	var part := RoomSweep.spine_gap_errors("s", _shaft(60, [5, 50]), [Vector2i(10, 20)] as Array[Vector2i], NO_HAZARDS, MAX_ROWS)
	check(part == (["s: the fall from row 20 to row 50 is 30 rows, over 19 (no ledge or cling stretch between)"] as Array[String]),
			"a stretch covering only part of a gap leaves the rest to fail, from the stretch's last row (got %s)" % [part])


func _test_stretch_widths() -> void:
	var g := _shaft(30, [5, 24])
	for r in range(8, 12):
		g[r] = "#".repeat(7) + ".".repeat(8) + "#".repeat(7)  # 8 open: narrow
	var at := func(r: int, row: String) -> Array[String]:
		var copy := g.duplicate()
		copy[r] = row
		return RoomSweep.stretch_width_errors("s", copy, [Vector2i(8, 11)] as Array[Vector2i])
	check(at.call(9, g[9]).is_empty(), "a stretch whose rows are 8 open cells wide is narrow")
	check(at.call(9, "#".repeat(6) + ".".repeat(10) + "#".repeat(6)).is_empty(), "near miss: 10 open cells is still narrow")
	check(at.call(9, "#".repeat(8) + ".".repeat(6) + "#".repeat(8)).is_empty(), "near miss: 6 open cells is still narrow")
	var wide: Array[String] = at.call(9, "#".repeat(5) + ".".repeat(11) + "#".repeat(6))
	check(wide == (["s: cling row 9 has an open run 11 wide at columns 5-15; a narrow stretch is 6-10 wide"] as Array[String]),
			"an 11-wide row is the one error, naming the row, width and columns (got %s)" % [wide])
	check(at.call(10, "#".repeat(8) + ".".repeat(5) + "#".repeat(9)).size() == 1, "a 5-wide row is too narrow to fall through")
	var two: Array[String] = at.call(11, "#" + ".".repeat(8) + "####" + ".".repeat(3) + "#".repeat(6))
	check(two.size() == 1 and two[0].contains("3 wide at columns 13-15"), "every open run in a row counts, not just the first (got %s)" % [two])
	check(RoomSweep.stretch_width_errors("s", _shaft(30, [5, 24]), [Vector2i(8, 9)] as Array[Vector2i]).size() == 2,
			"a declared stretch over the full 20-wide shaft fails on each of its rows")


func _test_hazard_pits() -> void:
	var none: Array[Vector2i] = []
	# D14 #5: a hazard 25 rows below the last ledge, then with a ledge 10 rows above it.
	var g := _shaft(40, [5])
	g[30] = "#" + ".".repeat(10) + "xx" + ".".repeat(8) + "#"
	var errs := RoomSweep.hazard_pit_errors("s", g, none, X_HAZARD, MAX_ROWS)
	check(errs == (["s: the hazard at (11, 30) has no ledge or cling stretch in the 19 rows above it",
			"s: the hazard at (12, 30) has no ledge or cling stretch in the 19 rows above it"] as Array[String]),
			"a hazard 25 rows below the last ledge fails, each cell named (got %s)" % [errs])
	var near := g.duplicate()
	near[20] = "#####" + ".".repeat(16) + "#"
	check(RoomSweep.hazard_pit_errors("s", near, none, X_HAZARD, MAX_ROWS).is_empty(), "with a ledge 10 rows above it, quiet")
	var edge := g.duplicate()
	edge[11] = "#####" + ".".repeat(16) + "#"
	check(RoomSweep.hazard_pit_errors("s", edge, none, X_HAZARD, MAX_ROWS).is_empty(), "near miss: a ledge exactly 19 rows above is in reach")
	var far := g.duplicate()
	far[10] = "#####" + ".".repeat(16) + "#"
	check(RoomSweep.hazard_pit_errors("s", far, none, X_HAZARD, MAX_ROWS).size() == 2, "a ledge 20 rows above is out of reach")
	check(RoomSweep.hazard_pit_errors("s", g, [Vector2i(15, 22)] as Array[Vector2i], X_HAZARD, MAX_ROWS).is_empty(),
			"a cling stretch above the pit is a save too")
	check(RoomSweep.hazard_pit_errors("s", g, none, NO_HAZARDS, MAX_ROWS).is_empty(), "control: with no hazard chars, 'x' is nothing")
	var roofed := g.duplicate()
	roofed[29] = "#" + ".".repeat(10) + "##" + ".".repeat(8) + "#"
	check(RoomSweep.hazard_pit_errors("s", roofed, none, X_HAZARD, MAX_ROWS).is_empty(), "a hazard with a wall right above it can't be fallen onto")


func _test_exit_falls() -> void:
	var rooms := {
		"a": {id = "a", spine = true, grid = _shaft(30, [5, 25]), clings = [] as Array[Vector2i], exits = [{side = "down", target = "b", col = 1}]},
		"b": {id = "b", spine = true, grid = _shaft(40, [14]), clings = [] as Array[Vector2i], exits = [{side = "up", target = "a", col = 3}]},
	}
	# a's last safe row is its floor (29); it has 1 row to its exit, so b's first safe row may be 18.
	rooms.b.grid = _shaft(40, [18])
	check(RoomSweep.exit_fall_errors(rooms, NO_HAZARDS, MAX_ROWS).is_empty(), "near miss: 1 row out of a + 18 into b = 19 rows is legal")
	rooms.b.grid = _shaft(40, [19])
	var errs := RoomSweep.exit_fall_errors(rooms, NO_HAZARDS, MAX_ROWS)
	check(errs == (["a: the fall from row 29 out of the down exit into b's row 19 is 20 rows, over 19"] as Array[String]),
			"1 + 19 = 20 rows through the exit is the one error (got %s)" % [errs])
	rooms.b.clings = [Vector2i(10, 15)] as Array[Vector2i]
	check(RoomSweep.exit_fall_errors(rooms, NO_HAZARDS, MAX_ROWS).is_empty(), "a cling stretch at the top of b is a save too")
	rooms.b.clings = [] as Array[Vector2i]
	rooms.b.spine = false
	check(RoomSweep.exit_fall_errors(rooms, NO_HAZARDS, MAX_ROWS).is_empty(), "a non-spine target is not swept (D5)")
	rooms.b.spine = true
	rooms.a.exits = [{side = "down", target = "nope", col = 1}]
	check(RoomSweep.exit_fall_errors(rooms, NO_HAZARDS, MAX_ROWS).is_empty(), "a missing target is link_errors' to report, not this sweep's")


func _test_duplicate_ids() -> void:
	var files: Array[Dictionary] = [
		{path = "res://rooms/l1/a.txt", objs = ["anchor_1"]},
		{path = "res://rooms/l1/b.txt", objs = ["anchor_2"]},
	]
	check(RoomSweep.duplicate_id_errors(files).is_empty(), "distinct room and obj ids are quiet")
	files.append({path = "res://rooms/dev/a.txt", objs = ["anchor_1", "anchor_1"]})
	var errs := RoomSweep.duplicate_id_errors(files)
	check(errs == (["room id 'a' is in both res://rooms/l1/a.txt and res://rooms/dev/a.txt",
			"obj id 'anchor_1' is in both res://rooms/l1/a.txt and res://rooms/dev/a.txt"] as Array[String]),
			"a room id and an obj id repeated in another file each name both paths, once (got %s)" % [errs])
	var within: Array[Dictionary] = [{path = "res://rooms/l1/c.txt", objs = ["x", "x"]}]
	check(RoomSweep.duplicate_id_errors(within).is_empty(), "an obj id repeated inside one file is validate()'s error, not repeated here")


func _test_links() -> void:
	var rooms := {
		"a": {exits = [{side = "down", target = "b", col = 1}]},
		"b": {exits = [{side = "up", target = "a", col = 3}]},
	}
	check(RoomSweep.link_errors(rooms).is_empty(), "a down exit into a room with an up exit, and back, is quiet")
	rooms.a.exits = [{side = "down", target = "bb", col = 1}]
	check(RoomSweep.link_errors(rooms) == (["a: down exit targets 'bb', which is no room"] as Array[String]),
			"a typo'd target is named (got %s)" % [RoomSweep.link_errors(rooms)])
	rooms.a.exits = [{side = "down", target = "b", col = 1}]
	rooms.b.exits = [{side = "down", target = "a", col = 3}]
	check(RoomSweep.link_errors(rooms) == (["a: down exit arrives at b's up entry, but b has no up exit",
			"b: down exit arrives at a's up entry, but a has no up exit"] as Array[String]),
			"a down exit into a room with no up exit fails (got %s)" % [RoomSweep.link_errors(rooms)])
	rooms.a.exits = [{side = "up", target = "b", col = 1}]
	check(RoomSweep.link_errors(rooms).is_empty(), "near miss: an up exit into a room with a down exit, and that down exit back into the up exit, is quiet (got %s)" % [RoomSweep.link_errors(rooms)])
	rooms.b.exits = [] as Array
	check(RoomSweep.link_errors(rooms) == (["a: up exit arrives at b's down entry, but b has no down exit"] as Array[String]),
			"an up exit into a room with no down exit fails (got %s)" % [RoomSweep.link_errors(rooms)])


func _test_arrival() -> void:
	# m1_shaft's bottom: the hole at columns 1–2, arrival standing at (3, h-3) on the floor.
	var base := _shaft(12, [])
	base[10] = "#.." + "#".repeat(19)
	base[11] = "#.." + "#".repeat(19)
	var exits := [{side = "down", target = "x", col = 1}]
	var at := func(cell: Vector2i, ch: String) -> Array[String]:
		var g := base.duplicate()
		g[cell.y] = g[cell.y].substr(0, cell.x) + ch + g[cell.y].substr(cell.x + 1)
		return RoomSweep.arrival_errors("s", g, exits, 3)
	check(RoomLoader.down_entry_cell(base, 1) == Vector2i(3, 9), "setup: the arrival from below stands at (3, 9)")
	check(at.call(Vector2i(4, 9), "c") == (["s: arriving from below at (3, 9), a 'c' spawns at (4, 9), within 3 cells"] as Array[String]),
			"a walker beside the arrival cell fails (m1_shaft's old (4, 102)) (got %s)" % [at.call(Vector2i(4, 9), "c")])
	check(at.call(Vector2i(6, 9), "c").size() == 1, "3 cells away is still too close")
	check(at.call(Vector2i(7, 9), "c").is_empty(), "near miss: 4 cells away is clear (m1_shaft's walker moves to 5 away)")
	check(at.call(Vector2i(6, 6), "h").size() == 1 and at.call(Vector2i(6, 5), "h").is_empty(), "the distance is Chebyshev: (6, 6) is 3 away, (6, 5) is 4")
	check(at.call(Vector2i(5, 8), "L").size() == 1, "a lurker counts too")
	check(at.call(Vector2i(5, 8), "#").is_empty() and at.call(Vector2i(5, 8), "P").is_empty(), "walls and the spawn char are not enemies")
	check(RoomSweep.arrival_errors("s", base, [{side = "up", target = "x", col = 3}], 3).is_empty(), "a room with no down exit has no arrival from below")
