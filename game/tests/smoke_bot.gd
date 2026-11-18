extends Node
## The reachability bot (Story 1.10 D10, AR50): plays every spine room (outside rooms/dev/) from
## its top entry down to its down exit, with plain movement and no dash, lurkers paused. It must
## reach a chain of Spec.BOT_MIN_CHAIN (GDD Level Progression: "an automated bot must reach a chain
## of ≥ 5 in every spine shaft"), never cross an exit with a live chain (the World backstop would
## fire on its line), and reach the down exit alive. This checks the layout, not survival or feel.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_bot.gd

const RoomHarness := preload("res://tests/room_harness.gd")
const RoomSweep := preload("res://tests/room_sweep.gd")
const Spec := preload("res://tests/spec.gd")
const M1_SHAFT := "res://rooms/l1/m1_shaft.txt"
const MAX_SECONDS := 60.0  ## D10: a room the bot can't finish in a minute of play is stuck
const STUCK_SECONDS := 5.0  ## D10: no new depth for this long ends the run
const BLOCKED_FRAMES := 20  ## D10: pressing toward the target with x unchanged this long -> one hop
const HOP_FRAMES := 12  ## a held jump, high enough to clear a walker
const SLASH_REACH := 24.0  ## px: a walker this close on the same floor is slashed (the slash reaches ~25 px)
const SLASH_EVERY := 15  ## frames between floor slashes, over the 0.22 s attack cooldown

var _fail := 0
var _parts: Dictionary
var _room: Room
var _player: Player


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	var rooms := _spine_rooms()
	check(not rooms.is_empty(), "found %d spine rooms to play under %s" % [rooms.size(), RoomSweep.ROOT])
	check(rooms.any(func(r: Dictionary) -> bool: return r.path == M1_SHAFT), "sentinel: %s is among them" % M1_SHAFT)
	for rec in rooms:
		await _play(rec)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


## D10: every spine room outside rooms/dev/, sorted by path. A file that doesn't validate is never
## built (smoke_rooms names its errors); here it is one FAIL, since the bot can't vouch for it.
func _spine_rooms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path in RoomSweep.room_files():
		if RoomSweep.is_dev(path):
			continue
		var parsed := RoomLoader.parse(FileAccess.get_file_as_string(path))
		var rec := RoomSweep.record(path, parsed)
		if not rec.spine:
			continue
		if not RoomLoader.validate(path, parsed).is_empty():
			check(false, "%s: can't play it, it doesn't validate (smoke_rooms names the errors)" % path)
			continue
		out.append(rec)
	return out


func _play(rec: Dictionary) -> void:
	var id: String = rec.id
	var has_up: bool = rec.exits.any(func(e: Dictionary) -> bool: return e.side == "up")
	var down: Array = rec.exits.filter(func(e: Dictionary) -> bool: return e.side == "down")
	# Where a diver arrives: the top entry, falling (else P, the start of the game).
	_parts = RoomHarness.build_from_path(self, rec.path, &"up" if has_up else &"spawn")
	_room = _parts.room
	_player = _parts.player
	Game.clock.clear()
	for n in _room.get_children():
		if n is Lurker:
			n.set_physics_process(false)  # reachability, not survival
		elif n is Crawler and n.hover:
			n.reset_phase()  # the same drift every run, whatever ran before
	_player.chain.break_chain()
	var bottom := _room.bounds().end.y
	var exit_x: float = (down[0].col * Room.TILE + Room.TILE / 2.0) if not down.is_empty() else 0.0
	var ledges := RoomSweep.ledge_rows(rec.grid, RoomLegend.HAZARDS)
	var floor_row: int = ledges[-1] if not ledges.is_empty() else -1
	var max_frames := int(MAX_SECONDS * Engine.physics_ticks_per_second)
	var stuck_frames := int(STUCK_SECONDS * Engine.physics_ticks_per_second)
	var best := 0
	var swung_for: Node2D = null
	var last_row_y := -INF  # a hit crawler is freed, so its row is kept as a number
	var max_y := _player.global_position.y
	var progress_at := 0
	var last_x := _player.global_position.x
	var blocked := 0
	var hop_left := 0
	var slash_at := 0
	var crossed := ""
	var chain_at_cross := -1
	var ending := "timeout"
	var frame := 0
	while frame < max_frames:
		var pos := _player.global_position
		if _player.is_dead:
			ending = "dead"
			break
		if pos.y > bottom or pos.y < 0.0:
			# World polls the same thing (body centre past the floor or the ceiling) and would bank a
			# live chain here (FR6 backstop): on the bot's line it must never have to.
			crossed = "down" if pos.y > bottom else "up"
			chain_at_cross = _player.chain.count
			ending = "exit"
			break
		if pos.y > max_y + 0.5:
			max_y = pos.y
			progress_at = frame
		elif frame - progress_at > stuck_frames:
			ending = "stuck"
			break
		var on_floor := _player.is_on_floor()
		if down.is_empty() and on_floor and frame > 5 and floori((pos.y + 12.0) / Room.TILE) == floor_row:
			ending = "floor"
			break
		# Like a player: aim for the nearest crawler in a row below the one just swung at.
		var target := _target(maxf(pos.y + 4.0, last_row_y + 8.0))
		var aim := Vector2(exit_x, bottom) if target == null else target.global_position
		if on_floor:
			# Off the ledge first, at the edge nearest the target: a target under the ledge itself is
			# reached around it, never by standing on top of it.
			aim.x = _drop_x(rec.grid, pos, aim.x)
		var walker := _walker_ahead() if on_floor else null
		if walker != null:
			aim = walker.global_position  # face it: the slash swings the way you face
		var dx := aim.x - pos.x
		for a in ["move_left", "move_right"]:
			Input.action_release(a)
		if absf(dx) > 3.0:
			Input.action_press("move_right" if dx > 0.0 else "move_left")
		# A hop when pressing into something that won't move.
		if hop_left > 0:
			hop_left -= 1
			if hop_left == 0:
				Input.action_release("jump")
		elif on_floor and absf(dx) > 3.0 and absf(pos.x - last_x) < 0.5:
			blocked += 1
			if blocked >= BLOCKED_FRAMES:
				blocked = 0
				hop_left = HOP_FRAMES
				Input.action_press("jump")
		else:
			blocked = 0
		last_x = pos.x
		var swing := false
		if walker != null and frame >= slash_at:
			swing = true  # on the floor, Attack slashes
			slash_at = frame + SLASH_EVERY
		elif target != null and not on_floor:
			var dy := target.global_position.y - pos.y
			if dy < 28.0 and absf(dx) < 12.0 and _player.velocity.y > 0.0 and swung_for != target:
				swung_for = target
				last_row_y = target.global_position.y
				swing = true  # in the air, Attack pogoes
		if swing:
			Input.action_press("attack")
			await frames(1)
			frame += 1
			Input.action_release("attack")
		await frames(1)
		frame += 1
		best = maxi(best, _player.chain.count)
	for a in ["move_left", "move_right", "attack", "jump"]:
		Input.action_release(a)
	print("     bot %s: frame %d, best %d, %s, y=%d" % [id, frame, best, ending if crossed == "" else "exit " + crossed, int(_player.global_position.y / Room.TILE)])
	check(best >= Spec.BOT_MIN_CHAIN, "%s: the bot chains %d+ pogos with plain movement, no dash (Spec.BOT_MIN_CHAIN; best %d)" % [id, Spec.BOT_MIN_CHAIN, best])
	check(crossed == "" or chain_at_cross == 0, "%s: the chain is 0 when the bot crosses an exit, so the backstop never fires on its line (chain %d)" % [id, maxi(chain_at_cross, 0)])
	if not down.is_empty():
		check(crossed == "down", "%s: the bot reaches the down exit (ended: %s, row %d)" % [id, ending, int(_player.global_position.y / Room.TILE)])
	else:
		check(ending == "floor", "%s: with no down exit, the bot reaches the bottom ledge, row %d (ended: %s)" % [id, floor_row, ending])
	check(not _player.is_dead, "%s: the bot is alive at the end (lurkers paused)" % id)
	RoomHarness.free_all(_parts)
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(1)


## The nearest crawler (hoverer or walker) below `floor_y`, by distance, or null. Freed crawlers
## and ones queued for deletion are skipped; ties keep the first in tree order (grid order).
func _target(floor_y: float) -> Node2D:
	var best: Node2D = null
	var here := _player.global_position
	for n in _room.get_children():
		if not n is Crawler or n.is_queued_for_deletion() or n.global_position.y <= floor_y:
			continue
		if best == null or n.global_position.distance_to(here) < best.global_position.distance_to(here):
			best = n
	return best


## Standing: the centre x of the open column nearest `goal_x` that the player can walk to along
## this floor and drop through (the cell under the feet open, the body's row clear on the way).
## `goal_x` itself when no such column is reachable (a hop may get past what blocks it).
func _drop_x(grid: Array[String], pos: Vector2, goal_x: float) -> float:
	var row := floori((pos.y + 13.0) / Room.TILE)  # the floor under the feet (body bottom = +12)
	var here := floori(pos.x / Room.TILE)
	var best := goal_x
	var best_d := INF
	for dir in [-1, 1]:
		var c: int = here
		while c >= 0 and c < grid[0].length():
			if RoomLoader.solid_at(grid, Vector2i(c, row - 1)):
				break  # a wall on the way
			if not RoomLoader.solid_at(grid, Vector2i(c, row)):
				var x := c * Room.TILE + Room.TILE / 2.0
				if absf(x - goal_x) < best_d:
					best = x
					best_d = absf(x - goal_x)
				break
			c += dir
	return best


## A walker on the player's floor within SLASH_REACH, either side, or null.
func _walker_ahead() -> Node2D:
	var here := _player.global_position
	for n in _room.get_children():
		if n is Crawler and not n.hover and not n.is_queued_for_deletion() \
				and absf(n.global_position.y - here.y) < Room.TILE and absf(n.global_position.x - here.x) <= SLASH_REACH:
			return n
	return null
