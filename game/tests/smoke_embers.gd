extends Node
## The Ember Cache on the real World (Story 1.22, FR22–FR24, AR24, AR25): a Normal death drops the
## carried embers as a cache where the player last stood on clean floor, the respawn's rebuild
## spawns it through the swap path, a touch carries them again. Then where it drops (a ground, a
## mid-air and a hazard death; the `up` arrival's mid-air fallback and its near-miss), Easy and
## Hard (no cache; the popup), a second death before recovery, the save (both halves of the
## progress-save rule), a cache in a room that is gone, the cache's light, and a lurker hunting a
## cache over a ticking player (harmless, and home at once when the cache is recovered).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_embers.gd
## Each case builds its own World and frees it with reset_for_tests(), so no case meets another's
## cache (D9). Lurkers are held still (physics off) except where a case drives one. Slot saves stay
## unarmed except in the save case, which points the store at TMP and loads slot 1 first.
## Frame maths (development-guide.md): World's safe-ground tracker records a floor tick, so a player
## placed on the floor waits a few ticks before it is that life's safe ground.

const WorldScene := preload("res://scenes/world/world.tscn")
const EmberCacheScene := preload("res://scenes/objects/ember_cache.tscn")
const Spec := preload("res://tests/spec.gd")
const TMP := "user://smoke_embers_tmp"
## m1_shaft spots on clean floor, away from P, the walkers and the hoverers' drift: the right wall
## ledge (cell (20, 23)) and the left one lower down (cell (1, 56)).
const SPOT_A := Vector2(328, 372)
const SPOT_B := Vector2(24, 900)
## t_spikes (tests/rooms/hazards): P's ledge, the floor row's feet, the spike run's left edge.
const SPIKES_P := Vector2(40, 68)
const SPIKES_STAND_Y := 196.0
const SPIKES_LEFT := 96.0

## Counts World's "saved Ember Cache" warnings, as smoke_world counts the respawn point's. A
## push_warning's text arrives as `code` (probed on 4.7.2); the mutex as in tests/runner.gd.
class CacheWarnings extends Logger:
	var _lock := Mutex.new()
	var _count := 0

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING or not code.begins_with("World: the saved Ember Cache"):
			return
		_lock.lock()
		_count += 1
		_lock.unlock()

	## How many arrived since the last take().
	func take() -> int:
		_lock.lock()
		var n := _count
		_count = 0
		_lock.unlock()
		return n


var _fail := 0
var _world: World
var _spawned: Array[Player] = []
var _caches_at_spawn: Array = []  # per spawn, [position] of every EmberCache the build left
var _lurkers_on := false


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(ceil(s * Engine.physics_ticks_per_second)))


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	# A run killed before its cleanup leaves the save case's slot here, and the next run would load
	# it (review of Story 1.22, probed: 3 false FAILs).
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	RoomLoader.add_root("res://tests/rooms/hazards")
	RoomLoader.add_root("res://tests/rooms/embers")
	await test_epic_smoke()
	await test_ground_death()
	await test_mid_air_death()
	await test_hazard_death()
	await test_up_fallback()
	await test_up_near_miss()
	await test_easy_and_hard()
	await test_second_death()
	await test_saves()
	await test_unknown_room()
	await test_cache_hunt_harmless()
	Game.reset_for_tests()
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Setup ----------------------------------------------------------------------------------------

func _boot(room: StringName, entry := &"spawn") -> void:
	_spawned.clear()
	_caches_at_spawn.clear()
	_world = WorldScene.instantiate()
	_world.start_room = room
	_world.start_entry = entry
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	add_child(_world)


func _free_world() -> void:
	for a in ["move_left", "move_right"]:
		Input.action_release(a)
	_world.queue_free()
	await get_tree().process_frame
	await frames(1)
	Game.reset_for_tests()
	_lurkers_on = false


func _on_spawned(player: Player) -> void:
	_spawned.append(player)
	_caches_at_spawn.append(_caches().map(func(c: EmberCache) -> Vector2: return c.position))
	if not _lurkers_on:
		for n in _room().get_children():
			if n is Lurker:
				n.set_physics_process(false)


func _p() -> Player:
	return _spawned[-1]


func _room() -> Room:
	return _world.current_room()


## The current room's live EmberCaches, by position (row, then column).
func _caches() -> Array:
	var out := _room().get_children().filter(func(n: Node) -> bool: return n is EmberCache and not n.is_queued_for_deletion())
	out.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return out


## The room's popup labels with exactly `text`.
func _popups(text: String) -> int:
	return _room().get_children().filter(func(n: Node) -> bool: return n is Label and n.text == text).size()


## The room's "-N lost" popups, whatever N is: the text around POPUP_LOST's number.
func _lost_popups() -> int:
	var parts := tr("POPUP_LOST").split("%d")
	return _room().get_children().filter(func(n: Node) -> bool:
		return n is Label and n.text.begins_with(parts[0]) and n.text.ends_with(parts[1]) and n.text.length() > parts[0].length() + parts[1].length()).size()


## Clean floor by the room's own cells, never by floor_spot(), which is the thing under test: the
## feet's cell is open and no hazard, the cell below is solid, the cell above open, and the feet are
## within 1 px of that floor's top.
func _on_clean_floor(c: Vector2) -> bool:
	var room := _room()
	var feet := Vector2i(floori(c.x / Room.TILE), floori((c.y + 11.5) / Room.TILE))
	return not room.is_solid(feet) and not room.hazards.has(feet) and room.is_solid(feet + Vector2i.DOWN) \
			and not room.is_solid(feet + Vector2i.UP) and absf(c.y + 12.0 - (feet.y + 1) * Room.TILE) <= 1.0


## Places the player on the floor at `spot` and waits until World records it as safe ground.
func _stand_at(spot: Vector2) -> void:
	_p().place_at(spot)
	await frames(3)
	check(_p().is_on_floor() and _world.last_safe_position() == spot, "(premise) standing at %s, World's safe ground (got %s, on floor %s)" % [spot, _world.last_safe_position(), _p().is_on_floor()])


## Banks `links` links (carried) and leaves `held` links held.
func _chain(links: int, held: int) -> void:
	for i in links:
		_p().chain.add_hit()
	_p().chain.break_chain()
	for i in held:
		_p().chain.add_hit()


func _await_respawn() -> void:
	var n := _spawned.size()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > n:
			break
		await frames(1)
	check(_spawned.size() == n + 1, "(premise) the respawn came")


# --- The epic's smoke -----------------------------------------------------------------------------

## m1_shaft on Normal: bank a chain, die away from P; the respawn rebuilds the room through the swap
## path with the cache at the drop spot; touching it carries the embers again.
func test_epic_smoke() -> void:
	_boot(&"m1_shaft")
	await frames(2)
	check(Game.slot.difficulty == &"normal" and Game.dive.carried == 0 and _room().floor_spot(SPOT_A) == SPOT_A, "(premise) Normal, nothing carried, SPOT_A on clean floor")
	_chain(4, 0)
	await _stand_at(SPOT_A)
	_chain(0, 2)  # after the landing, which banks a chain; the death comes before the next floor tick
	var carried := Game.dive.carried
	var held := _p().chain.held
	check(carried > 0 and held > 0, "(premise) a banked chain: %d carried, %d held" % [carried, held])
	var old_room := _room()
	var entered := []
	_world.room_entered.connect(func(id: StringName) -> void: entered.append(id))  # every one: a double announce must show
	_p().die()
	check(Game.dive.carried == 0 and _p().chain.held == 0, "a Normal death takes the carried embers and loses the held ones (carried %d)" % Game.dive.carried)
	check(Game.slot.has_cache() and Game.slot.cache_room == &"m1_shaft" and Game.slot.cache_pos == SPOT_A and Game.slot.cache_amount == carried,
			"...the slot holds the cache: %d in m1_shaft at %s (got %d at %s)" % [carried, SPOT_A, Game.slot.cache_amount, Game.slot.cache_pos])
	check(_popups(tr("POPUP_LOST") % held) == 1 and _lost_popups() == 1, "...and the one popup shows only the held loss, -%d lost (the carried went to the cache)" % held)
	var cost := _world.last_death_cost()
	cost.held_lost = -1
	check(_world.last_death_cost().get("held_lost") == held, "...and last_death_cost() hands out a copy: a reader can't change World's record (D2; got %s)" % [_world.last_death_cost()])
	await _await_respawn()
	check(_room() != old_room and entered == [&"m1_shaft"], "the respawn rebuilt the room through the swap path (a new Room, room_entered %s)" % [entered])
	var caches := _caches()
	check(caches.size() == 1 and caches[0].position == SPOT_A, "...and an EmberCache stands in it at the drop spot %s (got %s)" % [SPOT_A, caches.map(func(c: Node2D) -> Vector2: return c.position)])
	if caches.size() != 1:
		await _free_world()
		return
	var cache: EmberCache = caches[0]
	var source := cache.get_node(^"LightSource") as LightSource
	var light := source.get_node(^"Light") as BudgetLight if source != null else null
	check(source != null and source.is_in_group(&"light_source") and source.kind == &"cache" and source.radius() == Game.tuning.f(&"cache_radius"),
			"its LightSource is in group light_source, kind cache, at Tuning's cache_radius")
	check(light != null and light.rank == BudgetLight.Rank.CACHE, "...its Light a BudgetLight of rank CACHE")
	check(Game.dive.carried == 0, "(premise) the new life starts with nothing carried")
	_p().place_at(SPOT_A)
	await frames(3)
	check(Game.dive.carried == carried and not Game.slot.has_cache(), "touching it carries the %d again and the slot has no cache (carried %d)" % [carried, Game.dive.carried])
	check(not is_instance_valid(cache) or cache.is_queued_for_deletion(), "...the node is gone")
	check(_popups(tr("POPUP_BANKED") % carried) == 1, "...and the popup shows +%d banked" % carried)
	await _free_world()


# --- Where it drops -------------------------------------------------------------------------------

## A ground death (standing on P's ledge): exactly the last safe position.
func test_ground_death() -> void:
	_boot(&"t_spikes")
	await frames(2)
	Game.dive.add_carried(10)
	await _stand_at(SPIKES_P)
	var safe := _world.last_safe_position()
	_p().die()
	check(Game.slot.cache_pos == safe and safe == SPIKES_P, "a ground death drops the cache exactly at the last safe position %s (got %s)" % [safe, Game.slot.cache_pos])
	await _free_world()


## A mid-air death (walked off the ledge, before landing): on the ledge it left, on clean floor.
func test_mid_air_death() -> void:
	_boot(&"t_spikes")
	await frames(2)
	Game.dive.add_carried(10)
	await _stand_at(SPIKES_P)
	Input.action_press("move_right")
	var airborne := false
	for i in 90:
		await frames(1)
		if not _p().is_on_floor() and _p().position.y > SPIKES_P.y:
			airborne = true
			break
	Input.action_release("move_right")
	check(airborne and _p().position.y < SPIKES_STAND_Y, "(premise) off the ledge, falling, not yet landed (at %s)" % _p().position)
	_p().die()
	var c := Game.slot.cache_pos
	check(absf(c.y - SPIKES_P.y) <= 1.0 and c.x < 64.0 and _on_clean_floor(c), "a mid-air death drops it on the ledge it left, on clean floor (got %s)" % c)
	await _free_world()


## A hazard death (1 HP, into the spikes): on clean floor before the spikes, never over a ^.
func test_hazard_death() -> void:
	_boot(&"t_spikes")
	await frames(2)
	Game.dive.add_carried(10)
	# Walk off P's ledge, drop straight down onto the floor left of the spikes, then walk in.
	Input.action_press("move_right")
	for i in 60:
		await frames(1)
		if not _p().is_on_floor() and _p().position.x > 64.0:
			break
	Input.action_release("move_right")
	for i in 90:
		await frames(1)
		if _p().is_on_floor() and _p().position.y > 150.0:
			break
	check(_p().is_on_floor() and absf(_p().position.y - SPIKES_STAND_Y) <= 1.0 and _p().position.x < SPIKES_LEFT, "(premise) landed on clean floor beside the spikes at %s" % _p().position)
	_p().health.reset(1)
	Input.action_press("move_right")
	for i in 240:
		await frames(1)
		if _p().is_dead:
			break
	Input.action_release("move_right")
	check(_p().is_dead and _p().death_cause == &"spikes", "(premise) the spikes killed (cause '%s')" % _p().death_cause)
	var c := Game.slot.cache_pos
	# A floor tick's y drifts under a pixel (195.93 seen): floor_spot() keeps such a spot as it is.
	check(absf(c.y - SPIKES_STAND_Y) <= 1.0 and c.x < SPIKES_LEFT and _on_clean_floor(c),
			"a hazard death drops it on clean floor before the spikes, never over a ^ (got %s)" % c)
	await _free_world()


## The fallback: in t_cache_drop the up column is open to the bottom, so ground_below(up) is the
## mid-air entry. A death on the first tick after an up arrival drops the cache on the nearest
## clean floor, not at the entry.
func test_up_fallback() -> void:
	var errors: Array = RoomLoader.inspect(&"t_cache_drop").errors
	check(errors.is_empty(), "t_cache_drop validates (exits link, no hazard on an arrival; got %s)" % [errors])
	_boot(&"t_cache_drop", &"up")
	var room := _room()
	var entry := room.entry_position(&"up")
	check(room.ground_below(&"up") == entry and _world.last_safe_position() == entry, "(firing premise) ground_below(up) falls back to the mid-air entry %s" % entry)
	Game.dive.add_carried(10)
	await frames(1)
	_p().die()
	var c := Game.slot.cache_pos
	check(c != entry and c == Vector2(72, 116) and _on_clean_floor(c), "a death on the first tick drops the cache on the nearest clean floor, (72, 116), not at the entry (got %s)" % c)
	await _free_world()


## The near-miss: an up arrival in t_spikes (its column lands on clean floor) drops it at
## ground_below(up) exactly.
func test_up_near_miss() -> void:
	_boot(&"t_spikes", &"up")
	var seeded := _room().ground_below(&"up")
	check(seeded != _room().entry_position(&"up"), "(premise) t_spikes' up column ends on clean floor at %s" % seeded)
	Game.dive.add_carried(10)
	await frames(1)
	_p().die()
	check(Game.slot.cache_pos == seeded, "an up arrival's first-tick death in t_spikes drops it at ground_below(up) exactly (got %s)" % Game.slot.cache_pos)
	await _free_world()


# --- Easy and Hard --------------------------------------------------------------------------------

func test_easy_and_hard() -> void:
	for tier: StringName in [&"easy", &"hard"]:
		_boot(&"t_spikes")
		await frames(2)
		Game.slot.set_difficulty(tier)  # no save: slot saves are unarmed here
		Game.dive.add_carried(20)
		await _stand_at(SPIKES_P)
		_chain(0, 3)
		var held := _p().chain.held
		_p().die()
		check(not Game.slot.has_cache(), "%s: a death drops no cache" % tier)
		if tier == &"easy":
			check(Game.dive.carried == 20 + held, "Easy: the held %d are carried and the 20 kept (carried %d)" % [held, Game.dive.carried])
			check(_lost_popups() == 0, "Easy: no -N lost popup, whatever N (got %d)" % _lost_popups())
		else:
			check(Game.dive.carried == 0, "Hard: the carried 20 are lost too (carried %d)" % Game.dive.carried)
			check(_popups(tr("POPUP_LOST") % (held + 20)) == 1 and _lost_popups() == 1, "Hard: the one popup shows -%d lost, held and carried" % (held + 20))
		await _free_world()


# --- A second death -------------------------------------------------------------------------------

## A second Normal death before recovery: the first cache goes dark and is freed at once, before the
## respawn, and the rebuilt room holds only the new one.
func test_second_death() -> void:
	_boot(&"m1_shaft")
	await frames(2)
	Game.dive.add_carried(10)
	await _stand_at(SPOT_A)
	_p().die()
	await _await_respawn()
	var first: Array = _caches()
	check(first.size() == 1 and first[0].position == SPOT_A, "(premise) the first cache stands at %s" % SPOT_A)
	if first.size() != 1:
		await _free_world()
		return
	var old: EmberCache = first[0]
	var old_source: LightSource = old.get_node(^"LightSource")
	Game.dive.add_carried(7)
	await _stand_at(SPOT_B)
	_p().die()
	check(old.is_queued_for_deletion() and not old_source.is_lit(), "the second death puts the first cache out and frees it at once, before the respawn")
	check(Game.slot.cache_amount == 7 and Game.slot.cache_pos == SPOT_B and _world.last_death_cost().get("cache_destroyed") == 10,
			"...the slot holds only the new cache of 7 at %s, the report names the 10 destroyed (got %s)" % [SPOT_B, _world.last_death_cost()])
	await _await_respawn()
	check(_caches_at_spawn[-1] == [SPOT_B], "the rebuilt room holds only the new cache (got %s)" % [_caches_at_spawn[-1]])
	await _free_world()


# --- Saves ----------------------------------------------------------------------------------------

func test_saves() -> void:
	Game.store.dir = TMP
	Game.load_slot(1)
	Game.dive.add_carried(12)
	Game.slot.apply_death(Game.dive, 0, &"m1_shaft", SPOT_A)
	check(Game.save_now() == OK, "(premise) a resume save with a cache of 12 at %s" % SPOT_A)
	Game.reset_for_tests()
	check(not Game.slot.has_cache(), "(premise) reset: no cache in memory")
	Game.store.dir = TMP
	Game.load_slot(1)
	check(Game.slot.cache_room == &"m1_shaft" and Game.slot.cache_pos == SPOT_A and Game.slot.cache_amount == 12, "the load brings the cache back (got %s %s %d)" % [Game.slot.cache_room, Game.slot.cache_pos, Game.slot.cache_amount])
	_boot(&"m1_shaft")
	await frames(1)
	check(_caches_at_spawn.size() == 1 and _caches_at_spawn[0] == [SPOT_A], "...and a World built then spawns it (got %s)" % [_caches_at_spawn])
	# R14 (D5): a progress save after a recovery writes the last resume save's cache.
	Game.slot.recover_cache(Game.dive)
	Game.set_difficulty(&"hard")
	var file := _slot_file()
	var slot: Dictionary = file.get("slot", {})
	check(slot.get("difficulty") == "hard" and slot.get("cache") == {"room": "m1_shaft", "x": SPOT_A.x, "y": SPOT_A.y, "amount": 12.0},
			"a progress save (the tier change) after a recovery writes the last resume save's cache (got %s)" % [slot.get("cache")])
	check(file.get("dive", {}).get("carried") == 0.0, "...and that save's dive, nothing carried: the 12 are in the file once, in the cache (got %s)" % [file.get("dive")])
	# The other half (D5): a cache dropped since the last resume save is never kept by a progress
	# save. The resume save now holds no cache and the 12 carried.
	Game.set_difficulty(&"normal")
	check(Game.save_now() == OK and Game.dive.carried == 12 and not Game.slot.has_cache(), "(premise) a resume save with no cache and 12 carried")
	Game.slot.apply_death(Game.dive, 0, &"m1_shaft", SPOT_B)
	check(Game.slot.cache_amount == 12 and Game.dive.carried == 0, "(premise) a death since then: the 12 lie in a new cache at %s" % SPOT_B)
	Game.set_difficulty(&"easy")
	file = _slot_file()
	check(file.get("slot", {}).get("difficulty") == "easy" and file.get("slot", {}).has("cache") and file.get("slot", {}).get("cache") == null,
			"a progress save after a drop never keeps the cache dropped since the resume save: cache null (got %s)" % [file.get("slot", {}).get("cache")])
	check(file.get("dive", {}).get("carried") == 12.0, "...and writes that resume save's dive, 12 carried: the embers are in the file once (got %s)" % [file.get("dive")])
	await _free_world()
	Game.store.dir = TMP
	Game.load_slot(1)
	check(not Game.slot.has_cache() and Game.dive.carried == 12, "...and a load of it holds the 12 once, carried, with no cache (got cache %d, carried %d)" % [Game.slot.cache_amount, Game.dive.carried])
	Game.reset_for_tests()


## The slot file as written, {} when it doesn't parse.
func _slot_file() -> Dictionary:
	var j := JSON.new()
	var err := j.parse(FileAccess.get_file_as_string(TMP.path_join("slot_1.json")))
	return j.get_data() if err == OK and j.get_data() is Dictionary else {}


# --- A cache in a room that is gone ---------------------------------------------------------------

## Review of Story 1.22 (probed): a saved cache whose room RoomLoader doesn't know never spawns, so
## World says so once at its start. The cache stays in the slot. Control: a cache in a known room
## that is not the one built warns nothing.
func test_unknown_room() -> void:
	var warnings := CacheWarnings.new()
	OS.add_logger(warnings)
	Game.dive.add_carried(33)
	Game.slot.apply_death(Game.dive, 0, &"room_that_is_gone", SPIKES_P)
	_boot(&"t_spikes")
	await frames(2)
	check(warnings.take() == 1, "a saved cache in a room RoomLoader doesn't know: World warns once (no ERROR: the runner checks)")
	check(_caches().is_empty() and Game.slot.cache_room == &"room_that_is_gone" and Game.slot.cache_amount == 33, "...spawns nothing and leaves the cache in the slot (got %s %d)" % [Game.slot.cache_room, Game.slot.cache_amount])
	await _free_world()
	Game.dive.add_carried(33)
	Game.slot.apply_death(Game.dive, 0, &"m1_shaft", SPOT_A)
	_boot(&"t_spikes")
	await frames(2)
	check(warnings.take() == 0 and _caches().is_empty(), "(control) a cache in m1_shaft while t_spikes is built: no warning, and no cache in this room")
	OS.remove_logger(warnings)
	await _free_world()


# --- A cache hunt over a ticking player -----------------------------------------------------------

## The harness player in smoke_lurker never polls contact, so this is the check with a ticking one:
## a lurker hunting a cache, sitting on the player for 30 ticks, deals no damage (1.20 D7). Then H1
## with a real cache (AC7): the cache is the slot's own, so recovering it puts its light out, and
## the lurker hunting it heads home at once.
func test_cache_hunt_harmless() -> void:
	_lurkers_on = true
	_boot(&"t_spikes")
	await frames(2)
	var p := _p()
	var hits := []
	p.health.damaged.connect(func(amount: int, cause: StringName) -> void: hits.append([amount, cause]))
	await _stand_at(SPIKES_P)
	Game.dive.add_carried(9)
	Game.slot.apply_death(Game.dive, 0, &"t_spikes", Vector2(24, 68))  # the slot's cache, so a recovery reaches the node
	var cache: EmberCache = _room().spawn(EmberCacheScene, Vector2(24, 68))  # P's ledge, beside the player
	var source: LightSource = cache.get_node(^"LightSource")
	# By position (row, then column), never by child order: t_spikes has one lurker today.
	var lurkers := _room().get_children().filter(func(n: Node) -> bool: return n is Lurker)
	lurkers.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	check(not lurkers.is_empty(), "(premise) t_spikes has a lurker")
	if lurkers.is_empty():
		await _free_world()
		return
	var l: Lurker = lurkers[0]
	await frames(1)
	l.force(Lurker.State.HUNT, source)
	var premise := true
	for i in 30:
		l.global_position = p.global_position
		await frames(1)
		premise = premise and l.state == Lurker.State.HUNT and l.target == source and not l.monitorable \
				and l.global_position.distance_to(p.global_position) < 7.0
	check(premise, "(premise) the lurker hunts the cache from on top of the player, never monitorable, for 30 ticks (state %s)" % Lurker.State.keys()[l.state])
	check(hits.is_empty() and p.health.hp == Spec.MAX_HP and not p.is_dead, "...and deals no damage (got %s, HP %d)" % [hits, p.health.hp])
	# H1: the hunted cache is recovered (here by the rule; the node hears cache_changed).
	var back := Game.slot.recover_cache(Game.dive)
	check(back == 9 and not source.is_lit() and cache.is_queued_for_deletion(), "recovering the hunted cache puts its light out and frees the node at once (got %d back)" % back)
	await frames(2)
	check(l.state == Lurker.State.RETURN and not l.monitorable, "...and the lurker that hunted it heads home at once, still harmless (H1; state %s)" % Lurker.State.keys()[l.state])
	await frames(30)
	check(hits.is_empty() and l.state != Lurker.State.HUNT, "...with no damage and no new hunt in the 30 ticks after (got %s, state %s)" % [hits, Lurker.State.keys()[l.state]])
	await _free_world()
