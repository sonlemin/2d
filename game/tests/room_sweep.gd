extends RefCounted
## The pure room sweeps (Story 1.10 D2): fairness and link checks over parsed room files, so a
## layout change can never quietly break a guarantee (AR50). Every function is static and pure
## over a grid (Array[String], RoomLoader.parse()'s rows) and header facts, and returns errors as
## "<id>: <what>" with 0-based grid rows and columns. smoke_rooms and smoke_bot run them over
## every file under res://rooms; test_room_sweep proves each one on inline grids.
## A helper, not a test (no test_/smoke_ prefix), and no class_name, like spec.gd:
##   const RoomSweep := preload("res://tests/room_sweep.gd")

const ROOT := "res://rooms"
## D11, the 1.7 review ("arriving from below can land next to an enemy"): no enemy spawns within
## this many cells (Chebyshev) of a down entry's stand cell. 3 cells is 48 px, about 1.9 s of
## walker travel at 25 px/s: time to see it and step or slash before it reaches you.
const ARRIVAL_CLEAR_CELLS := 3
## GDD Level Types, Narrow stretch: "6–10 tiles wide; no ledges; walls always within reach".
## Every open run in a declared cling stretch's rows must be this wide (D6).
const NARROW_MIN := 6
const NARROW_MAX := 10

static var _exit_re := RegEx.create_from_string("^(up|down):([a-z][a-z0-9_]*)@x(\\d{1,4})$")
static var _obj_re := RegEx.create_from_string("^([a-z][a-z0-9_]*)@(\\d{1,4}),(\\d{1,4})$")
static var _cling_re := RegEx.create_from_string("^(\\d{1,4})-(\\d{1,4})$")


## Every *.txt under `root`, subfolders included, sorted by path. Empty when `root` can't be
## opened: the caller's sentinels (at least one file, m1_shaft among them) turn that into a FAIL.
static func room_files(root := ROOT) -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	out.sort()
	return out


static func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_walk(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.get_extension() == "txt":
			out.append(dir_path.path_join(file))


## D3: rooms under <root>/dev/ (the perf scene, 1.12) are validated only: never swept, never
## botted, never in the fairness checks. They still count for unique ids and links.
static func is_dev(path: String, root := ROOT) -> bool:
	return path.begins_with(root.path_join("dev") + "/")


## The header facts the sweeps read, from RoomLoader.parse(). Lenient: a malformed exit, obj or
## cling line is skipped here, since validate() has already reported it as a FAIL.
## {id, path, grid, spine, exits: [{side, target, col}], objs: Array[String], clings: Array[Vector2i]}
static func record(path: String, parsed: Dictionary) -> Dictionary:
	var exits := []
	var objs: Array[String] = []
	var spine := false
	for h: Dictionary in parsed.header:
		match h.key:
			"spine":
				spine = h.value == "true"
			"exits":
				for part: String in h.value.split(",", false):
					var m := _exit_re.search(part.strip_edges())
					if m != null:
						exits.append({side = m.get_string(1), target = m.get_string(2), col = m.get_string(3).to_int()})
			"obj":
				var m := _obj_re.search(h.value)
				if m != null:
					objs.append(m.get_string(1))
	return {id = path.get_file().get_basename(), path = path, grid = parsed.grid, spine = spine,
			exits = exits, objs = objs, clings = cling_stretches(parsed.header)}


## The `cling=<from>-<to>` stretches (D6) as Vector2i(from, to), rows inclusive, in header order.
static func cling_stretches(header: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Dictionary in header:
		if h.key != "cling":
			continue
		var m := _cling_re.search(h.value)
		if m != null and m.get_string(1).to_int() < m.get_string(2).to_int():
			out.append(Vector2i(m.get_string(1).to_int(), m.get_string(2).to_int()))
	return out


## D5: a row r in 1..h−1 where some inner column (1..w−2) is solid, is not a hazard, and has a cell
## above it that is neither solid nor a hazard: somewhere to land. test_room_loader's definition,
## plus the hazards, so a floor covered in spikes is never a ledge.
static func ledge_rows(grid: Array[String], hazards: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for r in range(1, grid.size()):
		for c in range(1, grid[r].length() - 1):
			var cell := Vector2i(c, r)
			var above := Vector2i(c, r - 1)
			if RoomLoader.solid_at(grid, cell) and not _is_hazard(grid, cell, hazards) \
					and not RoomLoader.solid_at(grid, above) and not _is_hazard(grid, above, hazards):
				out.append(r)
				break
	return out


## D5: the rows a fall can end safely on: every ledge row, and every row of a declared cling
## stretch (you can cling anywhere in one). Sorted, no repeats.
static func safe_rows(grid: Array[String], stretches: Array[Vector2i], hazards: Array[String]) -> Array[int]:
	var seen := {}
	for r in ledge_rows(grid, hazards):
		seen[r] = true
	for s in stretches:
		for r in range(s.x, s.y + 1):
			seen[r] = true
	var out: Array[int] = []
	out.assign(seen.keys())
	out.sort()
	return out


## D5, FR57: in a spine room, no fall between consecutive safe rows is over `max_rows`
## (Spec.LEDGE_FALL_MAX in rows: 1.5 s at 210 px/s).
static func spine_gap_errors(id: String, grid: Array[String], stretches: Array[Vector2i], hazards: Array[String], max_rows: int) -> Array[String]:
	var errors: Array[String] = []
	var rows := safe_rows(grid, stretches, hazards)
	if rows.is_empty():
		# A sentinel: with no safe row there is no gap to measure, and nothing to land on.
		errors.append("%s: a spine room with no ledge or cling stretch to land on" % id)
	for i in range(1, rows.size()):
		var gap := rows[i] - rows[i - 1]
		if gap > max_rows:
			errors.append("%s: the fall from row %d to row %d is %d rows, over %d (no ledge or cling stretch between)" % [id, rows[i - 1], rows[i], gap, max_rows])
	return errors


## D5: the fall out of a spine room's down exit into a spine target counts too: from the last safe
## row to the floor (h − row), plus the target's first safe row. A missing target is
## link_errors()'s to report. `rooms_by_id`: id -> record() (the swept rooms only).
static func exit_fall_errors(rooms_by_id: Dictionary, hazards: Array[String], max_rows: int) -> Array[String]:
	var errors: Array[String] = []
	var ids := rooms_by_id.keys()
	ids.sort()
	for id: String in ids:
		var rec: Dictionary = rooms_by_id[id]
		if not rec.spine:
			continue
		for e: Dictionary in rec.exits:
			if e.side != "down" or not rooms_by_id.has(e.target) or not rooms_by_id[e.target].spine:
				continue
			var target: Dictionary = rooms_by_id[e.target]
			var mine := safe_rows(rec.grid, rec.clings, hazards)
			var theirs := safe_rows(target.grid, target.clings, hazards)
			if mine.is_empty() or theirs.is_empty():
				continue  # a spine room with nowhere to land fails spine_gap_errors' sentinel
			var gap: int = (rec.grid.size() - mine[-1]) + theirs[0]
			if gap > max_rows:
				errors.append("%s: the fall from row %d out of the down exit into %s's row %d is %d rows, over %d" % [id, mine[-1], e.target, theirs[0], gap, max_rows])
	return errors


## D6, GDD Narrow stretch: in every row of a declared cling stretch, every maximal run of open
## (non-solid) cells is NARROW_MIN..NARROW_MAX wide, so the walls are always in reach.
static func stretch_width_errors(id: String, grid: Array[String], stretches: Array[Vector2i]) -> Array[String]:
	var errors: Array[String] = []
	for s in stretches:
		for r in range(s.x, mini(s.y, grid.size() - 1) + 1):
			var c := 0
			var w := grid[r].length()
			while c < w:
				if RoomLoader.solid_at(grid, Vector2i(c, r)):
					c += 1
					continue
				var start := c
				while c < w and not RoomLoader.solid_at(grid, Vector2i(c, r)):
					c += 1
				var run := c - start
				if run < NARROW_MIN or run > NARROW_MAX:
					errors.append("%s: cling row %d has an open run %d wide at columns %d-%d; a narrow stretch is %d-%d wide" % [id, r, run, start, c - 1, NARROW_MIN, NARROW_MAX])
	return errors


## D7, GDD Sequence Breaking ("every pit of hazards has a ledge or wall to cling to within a
## 210 px/s fall of 1.5 s"): every hazard cell that can be fallen onto (the cell above it is not
## solid) has a safe row in the `max_rows` rows above it.
static func hazard_pit_errors(id: String, grid: Array[String], stretches: Array[Vector2i], hazards: Array[String], max_rows: int) -> Array[String]:
	var errors: Array[String] = []
	if hazards.is_empty():
		return errors
	var rows := safe_rows(grid, stretches, hazards)
	for r in grid.size():
		for c in grid[r].length():
			if not grid[r][c] in hazards or (r > 0 and RoomLoader.solid_at(grid, Vector2i(c, r - 1))):
				continue
			if not rows.any(func(s: int) -> bool: return s >= r - max_rows and s <= r - 1):
				errors.append("%s: the hazard at (%d, %d) has no ledge or cling stretch in the %d rows above it" % [id, c, r, max_rows])
	return errors


## D4: room ids (file base names) and obj ids are unique across files. `files`: [{path, objs}],
## every file including dev rooms. An obj id repeated inside one file is validate()'s error.
static func duplicate_id_errors(files: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var room_at := {}  # id -> first path
	var obj_at := {}  # obj id -> first path
	for f in files:
		var path: String = f.path
		var id := path.get_file().get_basename()
		if room_at.has(id):
			errors.append("room id '%s' is in both %s and %s" % [id, room_at[id], path])
		else:
			room_at[id] = path
		var mine := {}
		for o: String in f.objs:
			if mine.has(o):
				continue
			mine[o] = true
			if obj_at.has(o):
				errors.append("obj id '%s' is in both %s and %s" % [o, obj_at[o], path])
			else:
				obj_at[o] = path
	return errors


## D4: every exit target is a room, and has the entry the crossing arrives at: a down exit arrives
## at the target's up entry, an up exit at its down entry (World._on_exit_reached; a swap into a
## room without it push_errors and cancels). `rooms_by_id`: id -> {exits}, every file.
static func link_errors(rooms_by_id: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids := rooms_by_id.keys()
	ids.sort()
	for id: String in ids:
		for e: Dictionary in rooms_by_id[id].exits:
			if not rooms_by_id.has(e.target):
				errors.append("%s: %s exit targets '%s', which is no room" % [id, e.side, e.target])
				continue
			var entry := "up" if e.side == "down" else "down"
			if not rooms_by_id[e.target].exits.any(func(t: Dictionary) -> bool: return t.side == entry):
				errors.append("%s: %s exit arrives at %s's %s entry, but %s has no %s exit" % [id, e.side, e.target, entry, e.target, entry])
	return errors


## D11 (option A, sonlm 2026-11-18): no enemy spawns within `clear_cells` (Chebyshev) of the cell a
## player arriving from below stands on (RoomLoader.down_entry_cell), so nothing walks into them
## before they can act. A room with no down exit has no such arrival.
static func arrival_errors(id: String, grid: Array[String], exits: Array, clear_cells: int) -> Array[String]:
	var errors: Array[String] = []
	for e: Dictionary in exits:
		if e.side != "down":
			continue
		var stand := RoomLoader.down_entry_cell(grid, e.col)
		if stand == RoomLoader.NO_CELL:
			continue  # validate() reports a down exit with no floor beside it
		for r in range(maxi(stand.y - clear_cells, 0), mini(stand.y + clear_cells, grid.size() - 1) + 1):
			for c in range(maxi(stand.x - clear_cells, 0), mini(stand.x + clear_cells, grid[r].length() - 1) + 1):
				if _is_enemy(grid[r][c]):
					errors.append("%s: arriving from below at (%d, %d), a '%s' spawns at (%d, %d), within %d cells" % [id, stand.x, stand.y, grid[r][c], c, r, clear_cells])
	return errors


## Every spawn char is an enemy today (c, h, L). A persistent kind (the anchor `A`, 1.24) is not.
static func _is_enemy(ch: String) -> bool:
	return RoomLegend.SPAWNS.has(ch) and not RoomLegend.SPAWNS[ch].get("persistent", false)


static func _is_hazard(grid: Array[String], cell: Vector2i, hazards: Array[String]) -> bool:
	return cell.y >= 0 and cell.y < grid.size() and cell.x >= 0 and cell.x < grid[cell.y].length() \
			and grid[cell.y][cell.x] in hazards
