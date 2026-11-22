class_name RoomLoader
## Rooms are text (AR21): `res://rooms/<layer>/<room_id>.txt`, a key=value header, `---`, then the
## grid, 1 char = 16 px (format: docs/rooms.md). parse() splits a file; the pure validate() returns
## every content error as "<path>:<row>:<col> <what>"; the loader push_errors them and refuses to
## build (Architecture → Error Handling). Tests inspect validate()'s list and never trigger push_error.

const ROOT := "res://rooms"
const SPINE_WIDTH := 22  ## spine rooms are 22 columns wall to wall (decision log: 352 px in the 360 px play area)
const SINGLE_KEYS: Array[String] = ["id", "zone", "spine", "exits"]
## Keys a header may repeat: `obj=` (a persistent object) and `cling=<from>-<to>` (a narrow cling
## stretch, 0-based grid rows, inclusive; Story 1.10 D6). The build ignores `cling`: only the room
## sweep reads it, to know where a long fall is meant to be clung through.
const REPEAT_KEYS: Array[String] = ["obj", "cling"]
const BACKDROP := Color(0.164706, 0.141176, 0.25098)  ## M1's violet index 1 in every zone until E4 applies the zone palettes to world art (ledger, Story 1.18 D10)
const LEDGE_RIM := Color(0.66, 0.71, 0.76, 0.45)  ## palette 3, dimmed: "you can stand here" (M1 finding 7)

const NO_CELL := Vector2i(-1, -1)

static var _id_re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
# Coordinates are at most 4 digits: a longer number would wrap in Vector2i (or make to_int() print
# an engine ERROR) and pass the bounds checks as the wrong cell.
static var _exit_re := RegEx.create_from_string("^(up|down):([a-z][a-z0-9_]*)@x(\\d{1,4})$")
static var _obj_re := RegEx.create_from_string("^([a-z][a-z0-9_]*)@(\\d{1,4}),(\\d{1,4})$")
static var _cling_re := RegEx.create_from_string("^(\\d{1,4})-(\\d{1,4})$")
# Shared by every room (project-context: cache materials and shared resources as statics).
static var _tileset: TileSet
static var _rim_material: CanvasItemMaterial
static var _index := {}  # room id -> path, built on the first load_room()
static var _indexed := false


## Resolves an id to its file under res://rooms/ (or an added root) and loads it. Null (after
## push_error) when unknown. With `dive`, killable enemies whose cell it marked killed are not
## built (AR24: they stay dead until a rest); without it (tests, the harness) every enemy is,
## so a room still loads standalone.
static func load_room(id: StringName, dive: DiveState = null) -> Room:
	var index := _get_index()
	if not index.has(id):
		push_error("RoomLoader: no room '%s' under %s" % [id, ROOT])
		return null
	return load_room_from_path(index[id], dive)


## Every room id the index knows (rooms/ and any added root), sorted as Strings: a StringName
## array sorts in pointer order, not alphabetically. For DevTools' `--room=` messages (Story 1.11 D5).
static func room_ids() -> Array[StringName]:
	var names := PackedStringArray()
	for id: StringName in _get_index():
		names.append(String(id))
	names.sort()
	var out: Array[StringName] = []
	for n in names:
		out.append(StringName(n))
	return out


## What a room offers, without building it or pushing an error (DevTools' `--room=`, Story 1.11 D5):
## {known, entries, errors}. `known` is false for an id the index doesn't have; `errors` is
## validate()'s list; `entries` is empty unless the file is valid, and then holds `spawn` when the
## grid has a `P` plus each exit side, sorted as Strings (m1_shaft: down, spawn, up).
static func inspect(id: StringName) -> Dictionary:
	var entries: Array[StringName] = []
	var errors: Array[String] = []
	var index := _get_index()
	if not index.has(id):
		return {known = false, entries = entries, errors = errors}
	var path: String = index[id]
	if not FileAccess.file_exists(path):  # gone since it was indexed; get_file_as_string() would print an ERROR
		errors.append("%s:0:0 file not found" % path)
		return {known = true, entries = entries, errors = errors}
	var parsed := parse(FileAccess.get_file_as_string(path))
	errors = validate(path, parsed)
	if not errors.is_empty():
		return {known = true, entries = entries, errors = errors}
	var names := PackedStringArray()
	for row: String in parsed.grid:
		if row.contains(RoomLegend.SPAWN):
			names.append("spawn")
			break
	for h: Dictionary in parsed.header:
		if h.key == "exits":
			for part in String(h.value).split(",", false):
				names.append(_exit_re.search(part.strip_edges()).get_string(1))  # valid, so it matches
	names.sort()
	for n in names:
		entries.append(StringName(n))
	return {known = true, entries = entries, errors = errors}


## Tests only (release exports exclude tests/*): indexes the rooms under `dir_path` too, so
## enter_room() can reach test rooms by id (Story 1.7 D6). Ids stay unique across all roots.
static func add_root(dir_path: String) -> void:
	_scan(dir_path, _get_index())


static func load_room_from_path(path: String, dive: DiveState = null) -> Room:
	# get_file_as_string() on a missing file prints an engine error of its own.
	if not FileAccess.file_exists(path):
		push_error("%s:0:0 file not found" % path)
		return null
	var parsed := parse(FileAccess.get_file_as_string(path))
	var errors := validate(path, parsed)
	for e in errors:
		push_error(e)
	if not errors.is_empty():
		return null
	return _build(parsed, dive)


## Splits a room file into header entries ({key, value, line, ok}) and grid rows. No checks here.
## `grid_line` is the 1-based file line of grid row 0, or 0 when there is no `---` line.
static func parse(text: String) -> Dictionary:
	var header: Array[Dictionary] = []
	var grid: Array[String] = []
	var grid_line := 0
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges(false, true)  # drops \r and trailing spaces
		if grid_line > 0:
			grid.append(line)
		elif line == "---":
			grid_line = i + 2
		elif line != "" and not line.begins_with(";"):
			var eq := line.find("=")
			header.append({key = line.left(eq).strip_edges() if eq >= 0 else line,
					value = line.substr(eq + 1).strip_edges() if eq >= 0 else "", line = i + 1, ok = eq > 0})
	while not grid.is_empty() and grid[-1] == "":
		grid.pop_back()
	return {header = header, grid = grid, grid_line = grid_line}


## Pure: every content error in the file, or [] when it builds. `path` names the file in messages
## and must end in "<id>.txt". Rows and columns are 1-based file positions, so an editor jumps there.
static func validate(path: String, parsed: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var err := func(row: int, col: int, what: String) -> void:
		errors.append("%s:%d:%d %s" % [path, row, col, what])
	if parsed.grid_line == 0:
		err.call(1, 1, "no '---' line between the header and the grid")
		return errors
	# Header.
	var seen := {}
	var values := {}
	var exit_lines := {}  # side -> header line
	var exits: Array[Dictionary] = []
	var objs := {}  # obj id -> true
	var obj_cells: Array[Dictionary] = []  # {cell, line}
	var clings: Array[Dictionary] = []  # {from, to, line}
	for h: Dictionary in parsed.header:
		var key: String = h.key
		if not h.ok:
			err.call(h.line, 1, "header line is not key=value")
			continue
		if not key in SINGLE_KEYS and not key in REPEAT_KEYS:
			err.call(h.line, 1, "unknown key '%s'" % key)
			continue
		if key in SINGLE_KEYS:
			if seen.has(key):
				err.call(h.line, 1, "key '%s' repeated (first on line %d)" % [key, seen[key]])
				continue
			seen[key] = h.line
			values[key] = h.value
		match key:
			"id":
				if _id_re.search(h.value) == null:
					err.call(h.line, 1, "id '%s' is not snake_case" % h.value)
				elif h.value != path.get_file().get_basename():
					err.call(h.line, 1, "id '%s' is not the file name '%s'" % [h.value, path.get_file()])
			"zone":
				if not Palettes.has_zone(StringName(h.value)):  # D9: zone ids have one home
					err.call(h.line, 1, "zone '%s' is not one of %s" % [h.value, ", ".join(Palettes.zones())])
			"spine":
				if h.value != "true" and h.value != "false":
					err.call(h.line, 1, "spine '%s' is not true or false" % h.value)
			"exits":
				for part in h.value.split(",", false):
					var m := _exit_re.search(part.strip_edges())
					if m == null:
						err.call(h.line, 1, "exit '%s' is not <up|down>:<room_id>@x<col>" % part.strip_edges())
					elif exit_lines.has(m.get_string(1)):
						err.call(h.line, 1, "two '%s' exits" % m.get_string(1))
					else:
						exit_lines[m.get_string(1)] = h.line
						exits.append({side = m.get_string(1), col = m.get_string(3).to_int(), line = h.line})
			"obj":
				var m := _obj_re.search(h.value)
				if m == null:
					err.call(h.line, 1, "obj '%s' is not <id>@<col>,<row>" % h.value)
				elif objs.has(m.get_string(1)):
					err.call(h.line, 1, "duplicate obj id '%s'" % m.get_string(1))
				else:
					objs[m.get_string(1)] = true
					obj_cells.append({cell = Vector2i(m.get_string(2).to_int(), m.get_string(3).to_int()), line = h.line})
			"cling":
				var m := _cling_re.search(h.value)
				if m == null:
					err.call(h.line, 1, "cling '%s' is not <from>-<to>" % h.value)
					continue
				var from := m.get_string(1).to_int()
				var to := m.get_string(2).to_int()
				if from >= to:
					err.call(h.line, 1, "cling rows %d-%d: <from> must be less than <to>" % [from, to])
				else:
					clings.append({from = from, to = to, line = h.line})
	for key in ["id", "zone"]:
		if not seen.has(key):
			err.call(1, 1, "missing '%s='" % key)
	# Grid shape and chars.
	var grid: Array[String] = parsed.grid
	var top: int = parsed.grid_line
	if not grid.is_empty() and grid[0].is_empty():
		err.call(top, 1, "row 1 is empty (a blank line right after '---'?)")
		return errors
	if grid.size() < 3 or grid[0].length() < 3:
		err.call(top, 1, "grid is smaller than 3 x 3")
		return errors
	var w := grid[0].length()
	var even := true
	var spawns: Array[Vector2i] = []
	for r in grid.size():
		if grid[r].length() != w:
			err.call(top + r, 1, "row is %d wide, row 1 is %d" % [grid[r].length(), w])
			even = false
		for c in grid[r].length():
			var ch := grid[r][c]
			if not RoomLegend.is_known(ch):
				err.call(top + r, c + 1, "unknown char '%s'" % ch)
			elif ch == RoomLegend.SPAWN:
				spawns.append(Vector2i(c, r))
	if values.get("spine", "false") == "true" and w != SPINE_WIDTH:
		err.call(top, 1, "spine room is %d wide, must be %d" % [w, SPINE_WIDTH])
	for i in range(1, spawns.size()):
		err.call(top + spawns[i].y, spawns[i].x + 1, "second 'P' (one spawn per room)")
	# Only the row count matters here, so this holds even when a row is the wrong width.
	for cl: Dictionary in clings:
		if cl.to >= grid.size():
			err.call(cl.line, 1, "cling rows %d-%d are outside the %d-row grid" % [cl.from, cl.to, grid.size()])
	# The cell checks need a rectangle; an unequal row has been reported above.
	if not even:
		return errors
	var h_rows := grid.size()
	for s in spawns:
		if not solid_at(grid, s + Vector2i.DOWN):
			err.call(top + s.y, s.x + 1, "'P' has nothing solid below it")
	for o: Dictionary in obj_cells:
		if o.cell.x >= w or o.cell.y >= h_rows:
			err.call(o.line, 1, "obj cell %s is outside the %d x %d grid" % [o.cell, w, h_rows])
	# Exit openings: the named cell plus the open cells right of it in the edge row (D3).
	var opening := {}  # Vector2i -> true
	for e: Dictionary in exits:
		var row := 0 if e.side == "up" else h_rows - 1
		# Columns 0 and w-1 are corners: an opening there would also open the side wall.
		if e.col < 1 or e.col > w - 2:
			err.call(e.line, 1, "%s exit column %d is outside the inner columns (1..%d)" % [e.side, e.col, w - 2])
			continue
		if solid_at(grid, Vector2i(e.col, row)):
			err.call(e.line, 1, "%s exit column %d is a solid cell" % [e.side, e.col])
			continue
		# Room.entry_position() puts a player arriving from above one cell inside the top opening,
		# and one arriving from below on the floor beside the bottom opening (D3).
		if e.side == "up":
			var inside := Vector2i(e.col, 1)
			if solid_at(grid, inside):
				err.call(e.line, 1, "%s exit's entry cell %s is solid" % [e.side, inside])
		elif down_entry_cell(grid, e.col) == NO_CELL:
			err.call(e.line, 1, "%s exit has no floor beside its opening to arrive on" % e.side)
		var c: int = e.col
		while c < w - 1 and not solid_at(grid, Vector2i(c, row)):
			opening[Vector2i(c, row)] = true
			c += 1
	# The edge rule: a hole in the room's edge that isn't an exit would let the player leave.
	for r in h_rows:
		for c in w:
			var edge := r == 0 or r == h_rows - 1 or c == 0 or c == w - 1
			var cell := Vector2i(c, r)
			if edge and not solid_at(grid, cell) and not opening.has(cell):
				err.call(top + r, c + 1, "hole in the room's edge that is not a declared exit")
	return errors


## Where a player arriving from below stands (Story 1.7 D3): on the floor beside the bottom
## opening that starts at `col`, never over it (over it they would fall straight back out and two
## rooms could loop). Tries the column right of the opening, then the one left of it, skipping
## the side-edge columns; the stand cell is the first open cell above that column's solid run
## from the bottom row, with an open cell above it for the body. NO_CELL when neither side has one. Shared by validate() and the build.
static func down_entry_cell(grid: Array[String], col: int) -> Vector2i:
	var h := grid.size()
	var w := grid[0].length()
	var end_col := col
	while end_col + 1 < w - 1 and not solid_at(grid, Vector2i(end_col + 1, h - 1)):
		end_col += 1
	for c in [end_col + 1, col - 1]:
		if c < 1 or c > w - 2:
			continue
		var r := h - 1
		while r >= 0 and solid_at(grid, Vector2i(c, r)):
			r -= 1
		# Feet on the solid run, with the cell above open too: the body reaches ~6 px into it.
		if r >= 1 and r < h - 1 and not solid_at(grid, Vector2i(c, r - 1)):
			return Vector2i(c, r)
	return NO_CELL


## Solid = a wall, or an in-wall char (L) whose left or right neighbour is a wall or the room edge
## (D5: with 1-tile walls a lurker sits in the edge column). False outside the grid.
static func solid_at(grid: Array[String], cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].length():
		return false
	var row := grid[cell.y]
	var ch := row[cell.x]
	if ch == RoomLegend.WALL:
		return true
	if not RoomLegend.is_in_wall(ch):
		return false
	return cell.x == 0 or cell.x == row.length() - 1 \
			or row[cell.x - 1] == RoomLegend.WALL or row[cell.x + 1] == RoomLegend.WALL


## Builds a validated room. Entities spawn in grid order (row, then column), so it is deterministic.
static func _build(parsed: Dictionary, dive: DiveState = null) -> Room:
	var grid: Array[String] = parsed.grid
	var room := Room.new()
	room.size_cells = Vector2i(grid[0].length(), grid.size())
	for h: Dictionary in parsed.header:
		match h.key:
			"id":
				room.id = StringName(h.value)
			"zone":
				room.zone = StringName(h.value)
			"spine":
				room.spine = h.value == "true"
			"exits":
				for part in h.value.split(",", false):
					var m := _exit_re.search(part.strip_edges())
					var side := StringName(m.get_string(1))
					var col := m.get_string(3).to_int()
					var entry := Vector2i(col, 1) if side == &"up" else down_entry_cell(grid, col)
					room.exits.append({side = side, target = StringName(m.get_string(2)), col = col,
							entry_cell = entry})
			"obj":
				var m := _obj_re.search(h.value)
				room.objects[StringName(m.get_string(1))] = Vector2i(m.get_string(2).to_int(), m.get_string(3).to_int())
	room.name = String(room.id)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.z_index = -10
	backdrop.size = room.bounds().size
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(backdrop)
	room.walls = TileMapLayer.new()
	room.walls.name = "Walls"
	room.walls.tile_set = _get_tileset()
	room.add_child(room.walls)
	var rims := Node2D.new()
	rims.name = "Rims"
	room.add_child(rims)
	var tile := Room.TILE
	for r in grid.size():
		for c in grid[r].length():
			var cell := Vector2i(c, r)
			var ch := grid[r][c]
			if solid_at(grid, cell):
				room.walls.set_cell(cell, 0, Vector2i.ZERO)
				# A rim on every floor surface, so places to land read in the dark (M1 finding 7).
				var above := cell + Vector2i.UP
				if r > 0 and not solid_at(grid, above) and not RoomLegend.is_in_wall(grid[r - 1][c]):
					rims.add_child(_rim(cell))
			if ch == RoomLegend.SPAWN:
				room.spawn_cell = cell
			elif RoomLegend.SPAWNS.has(ch):
				var kind: Dictionary = RoomLegend.SPAWNS[ch]
				var args: Dictionary = kind.args
				if kind.get("killable", false):
					# AR24: killed this dive, so not built until a rest (the header set room.id).
					if dive != null and dive.is_killed(room.id, cell):
						continue
					args = args.merged({room_id = room.id, cell = cell})  # never the shared const
				room.spawn(kind.scene, room.cell_centre(cell), args)
	# 1.24: persistent objects (header ids) skip here by their SlotState flag.
	# 1.22: spawn the Ember Cache here when Game.slot's cache is in this room.
	return room


static func _rim(cell: Vector2i) -> ColorRect:
	if _rim_material == null:
		_rim_material = CanvasItemMaterial.new()
		_rim_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # must read in the dark
	var rim := ColorRect.new()
	rim.material = _rim_material
	rim.color = LEDGE_RIM
	rim.position = Vector2(cell * Room.TILE)
	rim.size = Vector2(Room.TILE, 1)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rim


## One wall tile with a full-square collision on world layer 1 (M1's shaft tileset, built in code: no .tres).
static func _get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var t := Room.TILE
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(t, t)
	_tileset.add_physics_layer()
	_tileset.set_physics_layer_collision_layer(0, 1)  # world
	var src := TileSetAtlasSource.new()
	src.texture = preload("res://art/tile.png")
	src.texture_region_size = Vector2i(t, t)
	src.create_tile(Vector2i.ZERO)
	_tileset.add_source(src, 0)
	var h := t / 2.0
	var data := src.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return _tileset


## id -> path for every *.txt under ROOT, walked once. An id found twice is a content error.
static func _get_index() -> Dictionary:
	if not _indexed:
		_indexed = true
		_scan(ROOT, _index)
	return _index


static func _scan(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("RoomLoader: can't open %s (%s)" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), into)
	for file in dir.get_files():
		if file.get_extension() != "txt":
			continue
		var id := StringName(file.get_basename())
		var path := dir_path.path_join(file)
		if into.has(id):
			push_error("RoomLoader: room id '%s' in both %s and %s" % [id, into[id], path])
			continue
		into[id] = path
