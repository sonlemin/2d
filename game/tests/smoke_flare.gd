extends Node
## Flare Toss (Story 1.23, FR14–FR16, FR21): a real Light tap spends half the chain on a real flare.
## - the toss: the GDD's 8 → 4 and 5 → 2, the held split, nothing under 2 links, a Snuff is no toss,
##   a tap never Snuffs, the throw follows the facing;
## - the flight: the arc, the capped fall, sticking to a wall, a floor and a ceiling, a throw from a
##   spot hugging a wall, passing through a crawler and a lurker, burning out past an open exit;
## - the burn: Spec.FLARE_BURN from the throw, the fade over the last Spec.FLARE_FADE, the sensed
##   radius whole until the end; Long Wick's 6 s through the gear seam;
## - no damage, and no bank-heal from a toss (the chain that is left heals when it lands);
## - the lure, end to end on tests/rooms/sensing/t_sensing.txt (its lurker at (8, 200)): a hunt of
##   the player goes to the flare with no telegraph and harmless, a burnt-out flare costs a full
##   telegraph before the player can be hurt, a telegraph keeps its timer, the 80 px floor;
## - the toss from a cling (Q1), the cap (Q2), and the real World (carried, popup, a death).
## RoomHarness unless a case says World. Frame maths (development-guide.md; probed for this story):
## a read after an await sees the last tick; a change made after an await is seen by the tick about
## to run, so a flare spawned by the test ticks at once, while one the player tosses inside its own
## tick first moves on the next. Counts take ± 1 only where a float sum decides the last tick.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_flare.gd

const RoomHarness := preload("res://tests/room_harness.gd")
const Spec := preload("res://tests/spec.gd")
const WorldScene := preload("res://scenes/world/world.tscn")
const FlareScene := preload("res://scenes/actors/flare.tscn")
const CrawlerScene := preload("res://scenes/actors/crawler.tscn")
const LurkerScene := preload("res://scenes/actors/lurker.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"dash", &"light"]
## Ticks Light is held for a tap: 0.05 s, inside the shortest tap window (0.12 s).
const TAP_TICKS := 3
## t_sensing, written out: the lurker's cell centre; the player 100 px to its right, level with it
## (as smoke_lurker's BESIDE); open air high in the room, with over two seconds of fall below it.
const LURKER_AT := Vector2(8, 200)
const BESIDE := Vector2(108, 200)
const AIR := Vector2(176, 40)
## GDD Movement: "max fall 210 px/s", read from Spec's ledge rule (315 px in 1.5 s).
const FALL_MAX := Spec.LEDGE_FALL_MAX / Spec.LEDGE_FALL_TIME
## GDD Flare Toss + Movement: −160 px/s up under 900 px/s² rises 160² / (2 × 900) = 14.2 px.
const APEX := 14.0
## The flare's body, written out (flare.tscn's Shape): 4 × 4 px.
const FLARE_HALF := Vector2(2, 2)

var _fail := 0
var _h: Dictionary
var _room: Room
var _p: Player
var _l: Lurker
var _world: World
var _spawned: Array[Player] = []


## Reads the light budget inside the physics tick itself, after the actors and where World's
## LightBudget would run (priority 50), so a count is taken on the tick of a toss, before anything
## queued is freed.
class Sampler extends Node:
	var camera: CameraRig
	var room: Room
	var log: Array[Dictionary] = []

	func _init() -> void:
		process_physics_priority = 60

	func _physics_process(_delta: float) -> void:
		var c := BudgetLight.counts(get_tree().get_nodes_in_group(BudgetLight.GROUP), camera.view_rect())
		var queued := room.get_children().filter(func(n: Node) -> bool: return n is Flare and n.is_queued_for_deletion()).size()
		log.append({flares = get_tree().get_nodes_in_group(Flare.GROUP).size(), queued = queued, lit = c.lit, over = c.over})


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	RoomLoader.add_root("res://tests/rooms/sensing")
	RoomLoader.add_root("res://tests/rooms/input")
	RoomLoader.add_root("res://tests/rooms/embers")
	await test_toss()
	await test_no_toss()
	await test_facing()
	await test_flight()
	await test_through_creatures()
	await test_open_exit()
	await test_burn()
	await test_no_damage()
	await test_no_bank_heal()
	await test_lure_hunt()
	await test_lure_telegraph()
	await test_lure_floor()
	await test_cling_toss()
	await test_cap()
	await test_world()
	_release_all()
	Game.clock.clear()
	Game.tuning.apply_gear([])
	Game.reset_for_tests()
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Helpers ------------------------------------------------------------------------------------

## The harness on `id`. The player ticks unless `still`; the room's lurker (t_sensing has one) is
## held still unless `lurker_on`.
func _build(id := &"t_sensing", entry := &"spawn", still := false, lurker_on := false) -> void:
	_h = RoomHarness.build(self, id, entry)
	_room = _h.room
	_p = _h.player
	Game.clock.clear()
	await frames(2)
	_p.set_physics_process(not still)
	var lurkers := _lurkers()
	_l = lurkers[0] if not lurkers.is_empty() else null
	if _l != null:
		_l.set_physics_process(lurker_on)


func _free() -> void:
	_release_all()
	RoomHarness.free_all(_h)
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(1)


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


## The room's lurkers by position (row, then column), never by group order.
func _lurkers() -> Array[Lurker]:
	var out: Array[Lurker] = []
	for n in _room.get_children():
		if n is Lurker:
			out.append(n)
	out.sort_custom(func(a: Lurker, b: Lurker) -> bool:
		return a.global_position.y < b.global_position.y or (a.global_position.y == b.global_position.y and a.global_position.x < b.global_position.x))
	return out


## Every burning flare (group `flare`, none queued for deletion), oldest first: tree order is spawn order.
func _flares() -> Array[Flare]:
	var out: Array[Flare] = []
	for n in get_tree().get_nodes_in_group(Flare.GROUP):
		if n is Flare and not n.is_queued_for_deletion():
			out.append(n)
	return out


## D14: no flare outlives the part of a case that made it.
func _burn_all() -> void:
	get_tree().call_group(Flare.GROUP, &"burn_out")
	await frames(1)


func place(pos: Vector2) -> void:
	_p.global_position = pos
	_p.velocity = Vector2.ZERO
	_p.reset_physics_interpolation()
	if _h.has("camera"):
		_h.camera.snap()


func _chain(n: int) -> void:
	_p.chain.break_chain()
	for i in n:
		_p.chain.add_hit()


## The ticking player in open air at `at` with a chain of `links`.
func _air(links: int, at := AIR) -> void:
	_release_all()
	_p.chain.break_chain()
	place(at)
	await frames(1)
	for i in links:
		_p.chain.add_hit()


## A real tap: Light pressed and released inside the tap window. Returns on the tick the player
## sampled the tap (so the caller reads the toss tick), or after `watch` ticks with none.
## {taps, snuff}: taps seen, and whether a Snuff showed on any tick from the press on.
func _tap(watch := 6) -> Dictionary:
	var seen := {taps = 0, snuff = false}
	Input.action_press("light")
	for i in TAP_TICKS:
		await frames(1)
		seen.snuff = seen.snuff or _p.input.snuff_active or _p.chain.snuffed
	Input.action_release("light")
	for i in watch:
		await frames(1)
		seen.snuff = seen.snuff or _p.input.snuff_active or _p.chain.snuffed
		if _p.input.light_tap:
			seen.taps += 1
			break
	return seen


## A flare as the player spawns one, made by the test: it ticks on the tick about to run.
func _spawn(pos: Vector2, velocity: Vector2, radius := 100.0) -> Flare:
	return _room.spawn(FlareScene, pos, {radius = radius, velocity = velocity}) as Flare


func _rect(flare: Flare) -> Rect2:
	return Rect2(flare.position - FLARE_HALF, FLARE_HALF * 2.0)


## Whether any cell `rect` reaches into is solid, by the room's own cells (never the flare's rule).
func _any_solid(rect: Rect2) -> bool:
	var first := Vector2i((rect.position / Room.TILE).floor())
	var last := Vector2i((rect.end / Room.TILE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if _room.is_solid(Vector2i(x, y)):
				return true
	return false


## A stuck flare rests on a surface without being in it: its body, less the engine's safe margin
## (0.08 px; probed: it rests within 0.03 px of the face, either side), lies in open cells, and a
## solid cell is within 1 px of it.
func _rests_on_surface(flare: Flare) -> bool:
	return not _any_solid(_rect(flare).grow(-0.1)) and _any_solid(_rect(flare).grow(1.0))


func _name(s: int) -> String:
	return Lurker.State.keys()[s]


func _floor_ticks() -> int:
	return int(ceil(Spec.TELEGRAPH_MIN * Engine.physics_ticks_per_second))


# --- 1. The toss (AC3) ----------------------------------------------------------------------------

## The GDD's two examples with a real tap: links, the held split, one flare in the room at the
## pre-toss radius, the player's light following the new chain, no Snuff and no chain end.
func test_toss() -> void:
	await _build()
	var banked := []
	var ends := []
	_p.chain.banked.connect(func(a: int) -> void: banked.append(a))
	_p.chain.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	var ls := _p.light_source
	for row: Array in [[8, 4, 36, 18, 18], [5, 2, 15, 9, 6]]:
		var links: int = row[0]
		await _air(links)
		await frames(30)  # the shown light settles at the chain's radius
		banked.clear()
		ends.clear()
		var shown_before := ls.shown_radius()
		check(_flares().is_empty() and _p.chain.count == links and _p.chain.held == row[2] and absf(shown_before - ChainState.radius_for(links)) < 1.0 and not _p.is_on_floor(),
				"(premise) in the air at chain %d with %d held, the light shown at its %.1f px, no flare burning" % [links, row[2], ChainState.radius_for(links)])
		var seen := await _tap()
		var flares := _flares()
		check(seen.taps == 1 and _p.chain.count == row[1], "a Light tap at chain %d leaves %d (GDD Flare Toss; taps %d, chain %d)" % [links, row[1], seen.taps, _p.chain.count])
		check(banked == [row[3]] and _p.chain.held == row[4], "...it banks %d of the %d held and keeps %d (got %s, held %d)" % [row[3], row[2], row[4], banked, _p.chain.held])
		check(flares.size() == 1 and flares[0].get_parent() == _room, "...one flare burns, a child of the room (AR23; %d in group flare)" % flares.size())
		if flares.size() == 1:
			var flare := flares[0]
			check(is_equal_approx(flare.radius, ChainState.radius_for(links)) and flare.light_source.radius() == flare.radius and flare.light_source.kind == Sensing.KIND_FLARE,
					"...at the chain's radius before the toss, %.1f px, a light of kind flare (got %.1f)" % [ChainState.radius_for(links), flare.radius])
			check(flare.position.distance_to(_p.global_position) < 6.0, "...thrown from the player's centre, never a point ahead of it (%.1f px off after the player's own tick)" % flare.position.distance_to(_p.global_position))
		check(ls.radius() == ChainState.radius_for(row[1]), "...and on that tick the player's light is the new chain's, %.1f px (got %.1f)" % [ChainState.radius_for(row[1]), ls.radius()])
		check(ls.shown_radius() < shown_before and ls.shown_radius() > ls.radius(), "...its shown radius has begun to ease down (%.1f, from %.1f toward %.1f)" % [ls.shown_radius(), shown_before, ls.radius()])
		var prev := ls.shown_radius()
		var rises := 0
		var under := 0
		for i in 30:
			await frames(1)
			rises += int(ls.shown_radius() > prev + 0.001)
			under += int(ls.shown_radius() < ls.radius() - 0.001)
			prev = ls.shown_radius()
		check(rises == 0 and under == 0 and absf(prev - ls.radius()) < 1.0, "...and eases to it over the next 30 ticks, never up and never under (rises %d, under %d, shown %.1f)" % [rises, under, prev])
		check(not seen.snuff and not _p.chain.snuffed and ends.is_empty() and _p.chain.count == row[1],
				"...a tap never Snuffs and never ends the chain: no Snuff on any tick, no `ended`, the chain still %d (FR9; ends %s)" % [row[1], ends])
		await _burn_all()
	await _free()


## Under 2 links a tap does nothing at all, in the air and on the ground; a hold past the window is
## still a Snuff, and neither it nor its release throws.
func test_no_toss() -> void:
	await _build()
	var banked := []
	var ends := []
	_p.chain.banked.connect(func(a: int) -> void: banked.append(a))
	_p.chain.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	for links in [1, 0]:
		await _air(links)
		banked.clear()
		var held := _p.chain.held
		var seen := await _tap()
		check(seen.taps == 1 and _flares().is_empty() and _p.chain.count == links and _p.chain.held == held and banked.is_empty() and not seen.snuff,
				"a tap in the air at chain %d does nothing: no flare, chain and held untouched, nothing banked (flares %d, chain %d, held %d, banked %s)" % [links, _flares().size(), _p.chain.count, _p.chain.held, banked])
	_release_all()
	place(_room.entry_position(&"spawn"))
	for i in 30:
		if _p.is_on_floor():
			break
		await frames(1)
	await frames(2)
	var on_ground := await _tap()
	check(_p.is_on_floor() and on_ground.taps == 1 and _flares().is_empty() and _p.chain.count == 0,
			"a tap on the ground does nothing: the chain there is always 0 (on floor %s, taps %d, flares %d)" % [_p.is_on_floor(), on_ground.taps, _flares().size()])
	# Snuff is unchanged: held past the window with chain 5.
	await _air(5)
	ends.clear()
	Input.action_press("light")
	var snuffed := false
	for i in 12:
		await frames(1)
		snuffed = snuffed or _p.chain.snuffed
	check(snuffed and _p.chain.count == 0 and ends == [[5, false]] and _flares().is_empty(),
			"Light held past the window at chain 5 is a Snuff: chain 0, ended(5, false), no flare (snuffed %s, chain %d, ends %s, flares %d)" % [snuffed, _p.chain.count, ends, _flares().size()])
	Input.action_release("light")
	var taps := 0
	for i in 6:
		await frames(1)
		taps += int(_p.input.light_tap)
	check(taps == 0 and _flares().is_empty(), "...and its release is no tap and throws nothing (taps %d, flares %d)" % [taps, _flares().size()])
	await _free()


## The throw follows the facing: Spec.FLARE_THROW, mirrored to the left.
func test_facing() -> void:
	await _build()
	for dir: int in [-1, 1]:
		await _air(4)
		Input.action_press("move_left" if dir < 0 else "move_right")
		await frames(3)
		await _tap()
		var flares := _flares()
		check(flares.size() == 1, "(premise) a tap at chain 4 while steering %s throws a flare" % ("left" if dir < 0 else "right"))
		if flares.size() == 1:
			var flare := flares[0]
			check(flare.velocity == Vector2(dir * Spec.FLARE_THROW.x, Spec.FLARE_THROW.y), "facing %s, the throw is (%s, %s) px/s (got %s)" % ["left" if dir < 0 else "right", dir * Spec.FLARE_THROW.x, Spec.FLARE_THROW.y, flare.velocity])
			var x0 := flare.position.x
			await frames(1)
			check(signf(flare.position.x - x0) == dir and flare.velocity.x == dir * Spec.FLARE_THROW.x, "...and its first tick moves it that way (%.1f px)" % (flare.position.x - x0))
		_release_all()
		await _burn_all()
	await _free()


# --- 2. The flight (AC4) --------------------------------------------------------------------------

## The arc and the three surfaces, on flares spawned as the player spawns them. t_sensing's open
## air is x 16–336; its ceiling ends at y 16, its right wall starts at x 336, and under column 11
## the bottom floor's top is y 624.
func test_flight() -> void:
	await _build(&"t_sensing", &"spawn", true)
	check(_flares().is_empty(), "(premise) no flare burns at the start")
	var tps := Engine.physics_ticks_per_second
	# The arc, then the right wall.
	var arc := _spawn(Vector2(176, 300), Spec.FLARE_THROW, 60.0)
	var xs: Array[float] = [arc.position.x]
	var top := arc.position.y
	var fastest := -INF
	var over := 0
	var stuck_at := -1
	for k in range(1, 121):
		await frames(1)
		xs.append(arc.position.x)
		top = minf(top, arc.position.y)
		fastest = maxf(fastest, arc.velocity.y)
		over += int(arc.velocity.y > FALL_MAX + 0.001)
		if arc.state == Flare.State.STUCK:
			stuck_at = k
			break
	var step_ok := true
	for k in range(1, 11):
		step_ok = step_ok and absf(xs[k] - xs[k - 1] - Spec.FLARE_THROW.x / tps) < 0.001
	check(step_ok, "the first 10 ticks carry it %.1f px a tick sideways, the throw's %.0f px/s (got %s)" % [Spec.FLARE_THROW.x / tps, Spec.FLARE_THROW.x, xs.slice(0, 4)])
	check(absf((300.0 - top) - APEX) <= 2.0, "its apex is %.0f px above the throw, within 2 px (got %.1f)" % [APEX, 300.0 - top])
	check(over == 0 and is_equal_approx(fastest, FALL_MAX) and is_equal_approx(Game.tuning.f(&"max_fall"), FALL_MAX),
			"its fall reaches the terminal %.0f px/s and never passes it (fastest %.1f, ticks over %d)" % [FALL_MAX, fastest, over])
	check(stuck_at > 0 and arc.state == Flare.State.STUCK and _room.is_solid(Vector2i(floori((arc.position.x + FLARE_HALF.x + 1.0) / Room.TILE), floori(arc.position.y / Room.TILE))),
			"it sticks to the right wall, the first surface it meets (tick %d, at %s)" % [stuck_at, arc.position])
	# The floor and the ceiling.
	var floor_flare := _spawn(Vector2(176, 600), Vector2.ZERO, 60.0)
	var ceiling := _spawn(Vector2(176, 24), Vector2(0.0, Spec.FLARE_THROW.y), 60.0)
	# Thrown from where a player hugging the right wall stands (body 10 px wide: its centre 5 px out).
	var hug := _spawn(Vector2(331, 200), Spec.FLARE_THROW, 60.0)
	await frames(2)
	check(hug.state == Flare.State.STUCK and _rests_on_surface(hug) and not _room.is_solid(Vector2i((hug.position / Room.TILE).floor())),
			"thrown toward a wall from a spot hugging it, it is STUCK within two ticks, in the open cell (state %d at %s)" % [hug.state, hug.position])
	await frames(40)
	check(floor_flare.state == Flare.State.STUCK and _room.is_solid(Vector2i(floori(floor_flare.position.x / Room.TILE), floori((floor_flare.position.y + FLARE_HALF.y + 1.0) / Room.TILE))),
			"dropped, it sticks to the floor (at %s)" % floor_flare.position)
	check(ceiling.state == Flare.State.STUCK and _room.is_solid(Vector2i(floori(ceiling.position.x / Room.TILE), floori((ceiling.position.y - FLARE_HALF.y - 1.0) / Room.TILE))),
			"thrown up, it sticks to the ceiling (at %s)" % ceiling.position)
	var stuck: Array[Flare] = [arc, floor_flare, ceiling, hug]
	var names := ["wall", "floor", "ceiling", "hugged wall"]
	var at := stuck.map(func(f: Flare) -> Vector2: return f.position)
	var rests := stuck.map(func(f: Flare) -> bool: return _rests_on_surface(f))
	await frames(30)
	for i in stuck.size():
		check(rests[i] and stuck[i].position == at[i] and stuck[i].velocity == Vector2.ZERO,
				"stuck to the %s it never moves again over 30 ticks, its 4 × 4 body in open cells within 1 px of a solid one (rests %s, at %s, then %s)" % [names[i], rests[i], at[i], stuck[i].position])
	await _burn_all()
	await _free()


## It passes through a crawler and a lurker without sticking, and neither changes. The flare burns
## at 60 px, under the notice floor, so the lurker has no light to answer: only the body is tested.
func test_through_creatures() -> void:
	await _build(&"t_sensing", &"spawn", true)
	var crawler := _room.spawn(CrawlerScene, Vector2(121, 290), {hover = true}) as Crawler
	var lurker := _room.spawn(LurkerScene, Vector2(160, 300)) as Lurker
	await frames(2)
	var flare := _spawn(Vector2(100, 300), Spec.FLARE_THROW, 60.0)
	var met_crawler := 0
	var met_lurker := 0
	var flying := true
	var lurker_still := true
	for k in 40:
		await frames(1)
		flying = flying and flare.state == Flare.State.FLYING
		# The crawler's Body is 14 × 8 at (0, 2); the lurker's Shape a 7 px circle at (0, -1).
		met_crawler += int(_rect(flare).intersects(Rect2(crawler.position + Vector2(-7, -2), Vector2(14, 8))))
		met_lurker += int(_rect(flare).get_center().distance_to(lurker.position + Vector2(0, -1)) < 7.0)
		lurker_still = lurker_still and lurker.state == Lurker.State.IDLE and not lurker.monitorable and lurker.position == Vector2(160, 300)
	check(met_crawler > 0 and met_lurker > 0, "(premise) the flare's body overlapped the crawler's (%d ticks) and the lurker's (%d ticks)" % [met_crawler, met_lurker])
	check(flying and absf(flare.position.x - (100.0 + 40.0 * Spec.FLARE_THROW.x / Engine.physics_ticks_per_second)) < 0.01,
			"it flies through both without sticking: still FLYING, 40 ticks of the throw along (x %.1f)" % flare.position.x)
	check(is_instance_valid(crawler) and not crawler.is_queued_for_deletion() and lurker_still,
			"...and neither changes: the crawler lives, the lurker rests at home, never monitorable")
	check(flare.collision_layer == 0 and flare.collision_mask == 1, "(why) the flare is on no layer and meets only the world (layer %d, mask %d)" % [flare.collision_layer, flare.collision_mask])
	await _burn_all()
	await _free()


## t_cache_drop's column 5 is open from the top exit to the bottom one: a flare falling down it has
## nothing to stick to, and burns out within a tick of leaving the room's bounds grown by one tile.
func test_open_exit() -> void:
	await _build(&"t_cache_drop", &"up", true)
	var limit := _room.bounds().grow(Room.TILE)
	var flare: Variant = _spawn(Vector2(88, 60), Vector2.ZERO, 60.0)
	var last := Vector2(88, 60)
	var gone_at := -1
	for k in range(1, 121):
		await frames(1)
		if not is_instance_valid(flare) or not flare.light_source.is_lit():
			gone_at = k
			break
		last = flare.position
	var step := FALL_MAX / Engine.physics_ticks_per_second
	check(gone_at > 0 and gone_at < int(Spec.FLARE_BURN * Engine.physics_ticks_per_second) / 2,
			"through an open bottom exit the flare is out after %d ticks, long before its %.0f s burn ends" % [gone_at, Spec.FLARE_BURN])
	check(limit.has_point(last) and last.y > limit.end.y - step - 0.01, "...within a tick of leaving the room's bounds + 1 tile (last seen at y %.1f; the limit is %.0f)" % [last.y, limit.end.y])
	await frames(2)
	check(not is_instance_valid(flare) and _flares().is_empty(), "...and it is freed")
	await _free()


# --- 3. The burn (AC4) ----------------------------------------------------------------------------

## Two stuck flares on one clock: the plain one burns Spec.FLARE_BURN, the other was spawned while a
## test gear set flare_burn to 6.0 (Long Wick's number, E5). Each is at full light until its last
## Spec.FLARE_FADE seconds, then falls on every tick and never rises; the sensed radius is whole on
## every tick it burns.
func test_burn() -> void:
	await _build(&"t_sensing", &"spawn", true)
	check(_flares().is_empty(), "(premise) no flare burns at the start")
	var tps := Engine.physics_ticks_per_second
	Game.tuning.apply_gear([&"t_wick"], [{id = &"t_wick", stat = &"flare_burn", op = &"set", value = 6.0}])
	var long_wick := _spawn(Vector2(120, 300), Vector2.ZERO)
	long_wick.stick()
	Game.tuning.apply_gear([])
	var plain := _spawn(Vector2(240, 300), Vector2.ZERO)
	plain.stick()
	var full: float = plain.light_source.light.energy
	check(full > 0.0 and is_equal_approx(plain.light_source.light.texture_scale, 100.0 / 64.0), "(premise) a spawned flare is lit at once, its light sized to its radius before its first tick")
	var tracks: Array[Dictionary] = []
	for row: Array in [[plain, Spec.FLARE_BURN, "the flare"], [long_wick, 6.0, "with flare_burn set to 6.0"]]:
		tracks.append({flare = row[0], burn = row[1], name = row[2], out = -1, dim_early = 0, not_falling = 0, rises = 0,
				radius_off = 0, moved = 0, last = full, alpha = 1.0})
	for k in range(1, 8 * tps):
		await frames(1)
		for t in tracks:
			if t.out >= 0:
				continue
			var flare: Variant = t.flare
			if not is_instance_valid(flare) or not flare.light_source.is_lit():
				t.out = k
				continue
			var energy: float = flare.light_source.light.energy
			var fade_from := roundi((t.burn - Spec.FLARE_FADE) * tps)
			if k < fade_from:
				t.dim_early += int(energy != full)
			elif k > fade_from:
				t.not_falling += int(energy >= t.last)
			t.rises += int(energy > t.last)
			t.radius_off += int(flare.light_source.radius() != 100.0)
			t.moved += int(flare.state != Flare.State.STUCK or flare.position.y != 300.0)
			t.last = energy
			t.alpha = (flare.get_node(^"Sprite") as Sprite2D).modulate.a
		if tracks.all(func(t: Dictionary) -> bool: return t.out >= 0):
			break
	for t in tracks:
		var want := roundi(t.burn * tps)
		check(absi(t.out - want) <= 1, "%s: out %d ticks after the spawn, %.1f s from the throw, ± 1 (got %d)" % [t.name, want, t.burn, t.out])
		check(t.dim_early == 0, "...at its full light for the first %d ticks (%d ticks dimmed)" % [roundi((t.burn - Spec.FLARE_FADE) * tps), t.dim_early])
		check(t.not_falling == 0 and t.rises == 0 and t.last < 0.05 * full and t.alpha < 0.05,
				"...over the last %.0f s it falls on every tick and never rises, ending under 5 %% (ticks not falling %d, rises %d, last energy %.3f of %.1f, sprite alpha %.3f)" % [Spec.FLARE_FADE, t.not_falling, t.rises, t.last, full, t.alpha])
		check(t.radius_off == 0 and t.moved == 0, "...its sensed radius is the pre-toss 100 px on every tick it burns (D8), and it never moves (%d, %d ticks off)" % [t.radius_off, t.moved])
	await frames(2)
	check(not is_instance_valid(plain) and not is_instance_valid(long_wick) and _flares().is_empty(), "...and both are freed, out of group flare")
	await _free()


# --- 4. No damage, no bank-heal -------------------------------------------------------------------

func test_no_damage() -> void:
	await _build()
	var hits := []
	_p.health.damaged.connect(func(amount: int, cause: StringName) -> void: hits.append([amount, cause]))
	place(_room.entry_position(&"spawn"))
	await frames(6)
	var flare := _spawn(_p.global_position, Vector2.ZERO)
	flare.stick()
	await frames(2)  # overlaps lag a tick after a spawn
	var inside := true
	for i in 60:
		await frames(1)
		inside = inside and _p.hurt_rect().has_point(flare.position)
	check(inside and _p.is_on_floor(), "(premise) the player stands in a stuck flare for 60 ticks")
	check(hits.is_empty() and _p.health.hp == Spec.MAX_HP and not _p.is_dead, "...and takes no damage (hits %s, HP %d)" % [hits, _p.health.hp])
	check(not flare.has_method(&"contact_cause") and not flare.has_method(&"take_hit") and not flare.is_in_group(&"enemy") and not flare.is_in_group(&"predator") and flare.collision_layer == 0,
			"a flare has no contact_cause() and no take_hit(), is in neither `enemy` nor `predator`, and sits on no collision layer")
	await _burn_all()
	await _free()


## FR12, Story 1.19: links spent by a Flare Toss never bank-heal. At 3 HP with a chain of 20 a toss
## leaves 10 and heals nothing; landing those 10 is a real bank of Spec.BANK_HEAL_MIN, and heals.
func test_no_bank_heal() -> void:
	await _build()
	_p.health.hit(&"crawler_walker", 0.0)
	check(_p.health.hp == Spec.MAX_HP - 1, "(premise) one hit down: %d HP" % _p.health.hp)
	await _air(2 * Spec.BANK_HEAL_MIN)
	var seen := await _tap()
	var hp_at_toss := _p.health.hp
	await frames(5)
	check(seen.taps == 1 and _p.chain.count == Spec.BANK_HEAL_MIN and hp_at_toss == Spec.MAX_HP - 1 and _p.health.hp == Spec.MAX_HP - 1,
			"a toss at chain %d spends %d links and heals nothing (chain %d, HP %d then %d)" % [2 * Spec.BANK_HEAL_MIN, Spec.BANK_HEAL_MIN, _p.chain.count, hp_at_toss, _p.health.hp])
	place(_room.entry_position(&"spawn") + Vector2(0, -4))
	for i in 30:
		if _p.is_on_floor():
			break
		await frames(1)
	check(_p.is_on_floor() and _p.chain.count == 0 and _p.health.hp == Spec.MAX_HP,
			"...and landing the %d links left is a bank of its own: +1 HP (on floor %s, HP %d)" % [Spec.BANK_HEAL_MIN, _p.is_on_floor(), _p.health.hp])
	await _burn_all()
	await _free()


# --- 5. The lure, end to end (AC6) ----------------------------------------------------------------

## A real tap toward the lurker's wall. The player's physics is on only for the ticks of the tap,
## then off and re-placed, so the play rect holds still for the lurker's rules. Returns the flare
## (null when none was thrown) on the tick after the toss, before the lurker has read it.
func _toss_left(at: Vector2) -> Flare:
	place(at)
	_p.set_physics_process(true)
	Input.action_press("move_left")
	Input.action_press("light")
	await frames(TAP_TICKS)
	Input.action_release("light")
	var flare: Flare = null
	for i in 6:
		await frames(1)
		# Exactly one: each lure case starts with no flare, so the one in the group is this toss's.
		if _flares().size() == 1:
			flare = _flares()[0]
			break
	_p.set_physics_process(false)
	Input.action_release("move_left")
	place(at)
	return flare


## FR16: a lurker hunting the player (lethal) meets a tossed flare larger than the halved chain: it
## hunts the flare from the next tick, with no telegraph and harmless. FR21: when the flare burns
## out it heads home, and the player's light, still noticed, costs it a full telegraph.
func test_lure_hunt() -> void:
	await _build(&"t_sensing", &"spawn", true, true)
	_chain(10)
	place(BESIDE)
	_l.force(Lurker.State.HUNT, _p.light_source)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.target == _p.light_source and _l.monitorable, "(premise) the lurker hunts the player at chain 10, monitorable")
	var flare := await _toss_left(BESIDE)
	check(flare != null and _p.chain.count == 5, "(premise) a tap toward its wall: chain 5, a flare thrown (chain %d)" % _p.chain.count)
	if flare == null:
		await _free()
		return
	var source: Variant = flare.light_source
	check(is_equal_approx(flare.radius, ChainState.radius_for(10)) and flare.velocity.x < 0.0 and flare.radius > _p.light_source.radius() and _p.light_source.radius() >= Spec.NOTICE_MIN_RADIUS,
			"...the flare burns at chain 10's %.1f px and flies left; the player's light is now %.1f px, still one a lurker notices" % [flare.radius, _p.light_source.radius()])
	var switched := -1
	var telegraphs := 0
	for i in 2:
		await frames(1)
		telegraphs += int(_l.state == Lurker.State.TELEGRAPH)
		if switched < 0 and _l.target == source:
			switched = i + 1
	check(switched > 0 and _l.state == Lurker.State.HUNT and telegraphs == 0 and not _l.monitorable,
			"within 2 ticks the lurker hunts the flare, with no TELEGRAPH tick, harmless (tick %d, state %s, monitorable %s)" % [switched, _name(_l.state), _l.monitorable])
	# Until the flare is out: on it, harmless.
	var off_flare := 0
	var ticks := 0
	while LightSource.live(source) and ticks < 400:
		await frames(1)
		ticks += 1
		if LightSource.live(source):
			off_flare += int(_l.state != Lurker.State.HUNT or _l.target != source or _l.monitorable)
	check(not LightSource.live(source) and off_flare == 0, "for as long as the flare burns the lurker hunts it and nothing else: never a TELEGRAPH tick, never monitorable (%d ticks off, over %d)" % [off_flare, ticks])
	check(_l.notices(_p.light_source) or _l.senses(_p.light_source), "(premise) the flare is out with the player's %.1f px light still in the lurker's reach" % _p.light_source.radius())
	# The lurker ran before the flare on the tick it went out: its next tick finds the target gone.
	await frames(1)
	check(_l.state == Lurker.State.RETURN and not _l.monitorable, "the flare burns out: the lurker's next tick is RETURN, harmless (state %s)" % _name(_l.state))
	var harmless := not _l.monitorable
	var waited := 0
	while _l.state != Lurker.State.TELEGRAPH and waited < 120:
		await frames(1)
		waited += 1
		harmless = harmless and not _l.monitorable
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == _p.light_source, "...then it telegraphs at the player (after %d ticks; state %s)" % [waited, _name(_l.state)])
	var held := 1
	while _l.state == Lurker.State.TELEGRAPH and held < 300:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			held += 1
			harmless = harmless and not _l.monitorable
	check(held >= _floor_ticks() and harmless, "...for %d ticks, at least Spec.TELEGRAPH_MIN (%d), harmless from the burn-out to the telegraph's end (FR21)" % [held, _floor_ticks()])
	check(_l.state == Lurker.State.HUNT and _l.target == _p.light_source and _l.monitorable, "...and only then hunts the player, monitorable (state %s)" % _name(_l.state))
	await _free()


## Row T4 with a real flare: a telegraph at the player (the lurker woke by itself) that meets a
## tossed flare goes on from where its timer was and ends in a hunt of the flare, harmless.
func test_lure_telegraph() -> void:
	await _build(&"t_sensing", &"spawn", true, true)
	_chain(10)
	place(BESIDE)
	for i in 5:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			break
	var start := Engine.get_physics_frames()
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == _p.light_source and not _l.monitorable, "(premise) the lurker wakes and telegraphs at the player's light (state %s)" % _name(_l.state))
	var harmless := not _l.monitorable
	for i in 15:
		await frames(1)
		harmless = harmless and not _l.monitorable
	var flare := await _toss_left(BESIDE)
	var at_toss := Engine.get_physics_frames() - start
	check(flare != null and _l.state == Lurker.State.TELEGRAPH, "(premise) a toss %d ticks into the telegraph (state %s)" % [at_toss, _name(_l.state)])
	if flare == null:
		await _free()
		return
	var source: Variant = flare.light_source
	var retargeted := false
	while _l.state == Lurker.State.TELEGRAPH and Engine.get_physics_frames() - start < 300:
		await frames(1)
		harmless = harmless and not _l.monitorable
		retargeted = retargeted or (_l.state == Lurker.State.TELEGRAPH and _l.target == source)
	var total := Engine.get_physics_frames() - start
	check(retargeted and _l.state == Lurker.State.HUNT and _l.target == source, "the telegraph turns to the flare and ends in a hunt of it (retargeted %s, state %s)" % [retargeted, _name(_l.state)])
	# A restarted timer would run a full telegraph from the toss: at least Spec.TELEGRAPH_MIN more.
	check(total >= _floor_ticks() and total < at_toss + _floor_ticks(), "...keeping its timer: %d ticks in all, under the %d a restart at the toss would need" % [total, at_toss + _floor_ticks()])
	for i in 30:
		await frames(1)
		harmless = harmless and not _l.monitorable
	check(harmless and _l.target == source, "...harmless from the wake through 30 ticks of the hunt")
	await _burn_all()
	await _free()


## Readiness R20: a flare lures only a lurker that can sense it. A toss at chain 3 burns under
## Spec.NOTICE_MIN_RADIUS and no lurker answers; at chain 4 it is over, and the lurker goes for it.
## The lurker is held still for the tap, so only the flare is left for it to read (the player's
## light after either toss is under the floor too).
func test_lure_floor() -> void:
	for links: int in [3, 4]:
		await _build(&"t_sensing", &"spawn", true, false)
		_chain(links)
		var flare := await _toss_left(BESIDE)
		check(flare != null, "(premise) a tap at chain %d throws a flare" % links)
		if flare == null:
			await _free()
			continue
		var source: Variant = flare.light_source
		check(_p.light_source.radius() < Spec.NOTICE_MIN_RADIUS, "(premise) the player's light after it is %.1f px, under the notice floor" % _p.light_source.radius())
		_l.set_physics_process(true)
		var harmless := true
		if links == 3:
			check(flare.radius < Spec.NOTICE_MIN_RADIUS, "(premise) a flare tossed at chain 3 burns at %.1f px, under Spec.NOTICE_MIN_RADIUS (%.0f)" % [flare.radius, Spec.NOTICE_MIN_RADIUS])
			var rest := true
			for i in 90:
				await frames(1)
				rest = rest and _l.state == Lurker.State.IDLE and _l.target == null and not _l.monitorable
			check(rest and flare.global_position.distance_to(LURKER_AT) < flare.radius * Spec.NOTICE_FACTOR,
					"...and the lurker never answers it over 90 ticks, though it burns %.0f px from it (state %s)" % [flare.global_position.distance_to(LURKER_AT), _name(_l.state)])
		else:
			check(flare.radius >= Spec.NOTICE_MIN_RADIUS, "(premise) a flare tossed at chain 4 burns at %.1f px, at or over Spec.NOTICE_MIN_RADIUS (%.0f)" % [flare.radius, Spec.NOTICE_MIN_RADIUS])
			var hunted := false
			for i in 120:
				await frames(1)
				harmless = harmless and not _l.monitorable
				if _l.state == Lurker.State.HUNT and _l.target == source:
					hunted = true
					break
			check(hunted and harmless, "...and the lurker telegraphs and hunts it, harmless (state %s)" % _name(_l.state))
		await _burn_all()
		await _free()


# --- 6. The toss from a cling (Q1) ----------------------------------------------------------------

## One cling on t_input's right wall with a chain of 6, held until its grace runs out (the chain
## banks). With `toss`, a tap 15 ticks in. Returns the ticks from the cling's first tick to the bank,
## and what the toss showed.
func _cling(toss: bool) -> Dictionary:
	_release_all()
	# A landing first: the grace refills on the floor (or on a pogo hit), never by itself.
	place(_room.entry_position(&"spawn"))
	for i in 30:
		if _p.is_on_floor():
			break
		await frames(1)
	await frames(2)
	place(Vector2(Room.TILE * 21 - 6.0, 56))
	await frames(6)  # falling, coyote spent
	for i in 6:
		_p.chain.add_hit()
	Input.action_press("jump")
	var out := {ticks = -1, tossed = false, chain = -1, radius = 0.0, vx = 0.0, clinging_after = false, light_after = -1.0, still_clinging = true}
	var start := -1
	var toss_tick := -1
	for tick in range(1, 181):
		await frames(1)
		if start < 0:
			if _p._clinging:
				start = tick
			continue
		if _p.chain.count == 0:
			out.ticks = tick - start
			break
		out.still_clinging = out.still_clinging and _p._clinging
		if not toss:
			continue
		if tick == start + 15:
			Input.action_press("light")
		elif tick == start + 15 + TAP_TICKS:
			Input.action_release("light")
		if toss_tick < 0 and _flares().size() == 1:  # exactly one: _cling() burns every flare out before it returns
			var flare := _flares()[0]
			toss_tick = tick
			out.tossed = true
			out.chain = _p.chain.count
			out.radius = flare.radius
			out.vx = flare.velocity.x
		elif toss_tick > 0 and tick == toss_tick + 1:
			out.clinging_after = _p._clinging
			out.light_after = _p.light_source.radius()
	_release_all()
	await _burn_all()
	return out


func test_cling_toss() -> void:
	await _build(&"t_input")
	var plain := await _cling(false)
	var tps := Engine.physics_ticks_per_second
	check(plain.ticks > 0 and absi(plain.ticks - roundi(Game.tuning.f(&"cling_grace") * tps)) <= 2, "(premise) a cling with a chain of 6 banks when its grace runs out, %d ticks in" % plain.ticks)
	var tossed := await _cling(true)
	check(tossed.tossed and tossed.chain == 3, "a tap while clinging at chain 6 throws: chain 3 (tossed %s, chain %d)" % [tossed.tossed, tossed.chain])
	check(is_equal_approx(tossed.radius, ChainState.radius_for(6)) and tossed.radius > Spec.NOTICE_MIN_RADIUS,
			"...the flare burns at the chain's own %.1f px, not the cling's shielded %.0f (got %.1f)" % [ChainState.radius_for(6), Spec.BASE_LIGHT, tossed.radius])
	check(tossed.vx == -Spec.FLARE_THROW.x, "...thrown away from the wall (velocity.x %.0f on the right wall)" % tossed.vx)
	check(tossed.clinging_after and tossed.light_after == Spec.BASE_LIGHT and tossed.still_clinging,
			"...the cling goes on: still clinging on the next tick and to the end, the light still %.0f px (clinging %s, light %.1f)" % [Spec.BASE_LIGHT, tossed.clinging_after, tossed.light_after])
	check(tossed.ticks == plain.ticks, "...and its grace is neither refilled nor reset: the chain banks %d ticks into the cling, as without the toss (%d)" % [tossed.ticks, plain.ticks])
	await _free()


# --- 7. The cap (AC7, Q2) -------------------------------------------------------------------------

## Six tosses by the player's own path inside one burn: five flares burn, the first is the one that
## went out, and on the tick of the sixth throw (read inside the tick, with the old flare still
## queued in the tree) the always-lights are not over the budget.
func test_cap() -> void:
	await _build()
	check(_flares().is_empty(), "(premise) no flare burns at the start")
	var sampler := Sampler.new()
	sampler.camera = _h.camera
	sampler.room = _room
	add_child(sampler)
	await _air(8)
	var first: Variant = null  # may be freed below: a freed object compares equal to null, so `had_first` says it was set
	var had_first := false
	var counts: Array[int] = []
	var swap := {}
	var after := {}
	for i in 6:
		while _p.chain.count < 8:
			_p.chain.add_hit()
		await _tap()
		counts.append(_flares().size())
		if i == 0 and not _flares().is_empty():
			first = _flares()[0]
			had_first = true
		if i == 5:
			swap = sampler.log[-1]
			await frames(1)
			after = sampler.log[-1]
	check(counts == [1, 2, 3, 4, 5, 5], "six tosses in a row: the flares burning after each are 1, 2, 3, 4, 5, 5 (got %s)" % [counts])
	check(had_first and (not is_instance_valid(first) or not first.is_in_group(Flare.GROUP)) and _flares().size() == 5, "...and the one that went out is the first thrown, the one with the least time left")
	check(swap.get("flares") == 5 and swap.get("queued", 0) == 1 and swap.get("lit") == Spec.LIGHTS_ON_SCREEN_MAX and swap.get("over") == 0,
			"on the tick of the sixth throw, with the old flare still queued in the tree: 5 in group flare, %d lights lit with the player's, over 0 (got %s)" % [Spec.LIGHTS_ON_SCREEN_MAX, swap])
	check(after.get("flares") == 5 and after.get("lit") == Spec.LIGHTS_ON_SCREEN_MAX and after.get("over") == 0, "...and the same on the next tick (got %s)" % [after])
	check(sampler.log.all(func(s: Dictionary) -> bool: return s.over == 0 and s.lit <= Spec.LIGHTS_ON_SCREEN_MAX), "...on no tick of the six tosses were the always-lights over the budget")
	await _burn_all()
	# The cap is the Tuning value: 2 through the gear seam.
	Game.tuning.apply_gear([&"t_cap"], [{id = &"t_cap", stat = &"flare_max", op = &"set", value = 2.0}])
	await _air(8)
	counts.clear()
	for i in 4:
		while _p.chain.count < 8:
			_p.chain.add_hit()
		await _tap()
		counts.append(_flares().size())
	Game.tuning.apply_gear([])
	check(counts == [1, 2, 2, 2], "with flare_max set to 2, four tosses leave 1, 2, 2, 2 burning (got %s)" % [counts])
	sampler.queue_free()
	await _burn_all()
	await _free()


# --- 8. In a real World ---------------------------------------------------------------------------

func _on_spawned(player: Player) -> void:
	_spawned.append(player)


## m1_shaft in world.tscn: the share reaches the dive and shows its popup through the wiring that
## exists, the flare is the room's and the budget counts it, and a death with a flare burning (a
## lurker hunting it) rebuilds the room without it and without an error.
func test_world() -> void:
	_spawned.clear()
	_world = WorldScene.instantiate()
	_world.start_room = &"m1_shaft"
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	add_child(_world)
	await frames(2)
	_p = _spawned[-1]
	_h = {}
	_room = _world.current_room()
	check(Game.dive.carried == 0 and _flares().is_empty(), "(premise) a fresh dive: nothing carried, no flare")
	_p.global_position = Vector2(200, 40)  # open air above m1_shaft's first hoverer row
	_p.velocity = Vector2.ZERO
	_p.reset_physics_interpolation()
	await frames(1)
	for i in 8:
		_p.chain.add_hit()
	var held := _p.chain.held
	var seen := await _tap()
	var flares := _flares()
	check(seen.taps == 1 and _p.chain.count == 4 and flares.size() == 1, "(premise) a tap at chain 8 in the World: chain 4, one flare (chain %d, flares %d)" % [_p.chain.count, flares.size()])
	if flares.size() != 1:
		await _free_world()
		return
	var flare := flares[0]
	var share := held - _p.chain.held
	check(share == 18 and Game.dive.carried == share, "the share of the held embers is carried: +%d (carried %d)" % [share, Game.dive.carried])
	var popups := _room.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == tr("POPUP_BANKED") % share).size()
	check(popups == 1, "...and one popup shows +%d banked (got %d)" % [share, popups])
	check(flare.get_parent() == _world.current_room(), "the flare is a child of World.current_room() (AR23)")
	await frames(1)
	var lights := get_tree().get_nodes_in_group(BudgetLight.GROUP)
	var c := BudgetLight.counts(lights, _world.light_rect())
	var light := flare.light_source.light
	check(BudgetLight.lit_on_screen(light, _world.light_rect()) and not light.demoted and c.lit >= 2 and c.over == 0,
			"the budget counts its light, lit and never demoted, beside the player's (counts %s)" % [c])
	# A lurker hunting the flare when the player dies: the rebuild frees both with the room.
	var lurkers := _lurkers()
	lurkers.sort_custom(func(a: Lurker, b: Lurker) -> bool: return a.global_position.distance_squared_to(flare.global_position) < b.global_position.distance_squared_to(flare.global_position))
	check(not lurkers.is_empty(), "(premise) m1_shaft has lurkers")
	if not lurkers.is_empty():
		lurkers[0].force(Lurker.State.HUNT, flare.light_source)
		await frames(2)
		check(lurkers[0].target == flare.light_source and not lurkers[0].monitorable, "(premise) a lurker holds the flare as its target, harmless")
	var old_room := _room
	var n := _spawned.size()
	_p.die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > n:
			break
		await frames(1)
	check(_spawned.size() == n + 1 and _world.current_room() != old_room, "(premise) the death respawned a new player in a rebuilt room")
	_room = _world.current_room()
	await frames(5)
	var left := _room.get_children().filter(func(node: Node) -> bool: return node is Flare).size()
	check(_flares().is_empty() and left == 0 and get_tree().get_nodes_in_group(LightSource.GROUP).all(func(node: Node) -> bool: return (node as LightSource).kind != Sensing.KIND_FLARE),
			"after the respawn's rebuild no flare is left: none in group flare, none in the room, no flare light (the runner fails on any script error from the freed one)")
	await _free_world()


func _free_world() -> void:
	_release_all()
	_world.queue_free()
	await get_tree().process_frame
	await frames(1)
	Game.reset_for_tests()
