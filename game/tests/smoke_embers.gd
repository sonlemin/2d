extends Node
## The Ember Cache on the real World (Story 1.22, FR22–FR24, AR24, AR25): a Normal death drops the
## carried embers as a cache where the player last stood on clean floor, the respawn's rebuild
## spawns it through the swap path, a touch carries them again. Then where it drops (a ground, a
## mid-air and a hazard death; the `up` arrival's mid-air fallback and its near-miss), Easy and
## Hard (no cache; the popup), a second death before recovery, the save, the cache's light, and a
## lurker hunting a cache over a ticking player (harmless).
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
	_world.room_entered.connect(func(id: StringName) -> void: entered.append(id), CONNECT_ONE_SHOT)
	_p().die()
	check(Game.dive.carried == 0 and _p().chain.held == 0, "a Normal death takes the carried embers and loses the held ones (carried %d)" % Game.dive.carried)
	check(Game.slot.has_cache() and Game.slot.cache_room == &"m1_shaft" and Game.slot.cache_pos == SPOT_A and Game.slot.cache_amount == carried,
			"...the slot holds the cache: %d in m1_shaft at %s (got %d at %s)" % [carried, SPOT_A, Game.slot.cache_amount, Game.slot.cache_pos])
	check(_popups(tr("POPUP_LOST") % held) == 1, "...and the popup shows only the held loss, -%d lost (the carried went to the cache)" % held)
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
	check(absf(c.y - SPIKES_P.y) <= 1.0 and c.x < 64.0 and _room().floor_spot(c) == c, "a mid-air death drops it on the ledge it left, on clean floor (got %s)" % c)
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
	var feet := Vector2i(floori(c.x / Room.TILE), floori((c.y + 11.5) / Room.TILE))
	# A floor tick's y drifts under a pixel (195.93 seen): floor_spot() keeps such a spot as it is.
	check(absf(c.y - SPIKES_STAND_Y) <= 1.0 and c.x < SPIKES_LEFT and not _room().hazards.has(feet) and _room().floor_spot(c) == c,
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
	check(c != entry and c == Vector2(72, 116) and room.floor_spot(c) == c, "a death on the first tick drops the cache on the nearest clean floor, (72, 116), not at the entry (got %s)" % c)
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
			var any_lost := [held, 20, held + 20].any(func(n: int) -> bool: return _popups(tr("POPUP_LOST") % n) > 0)
			check(not any_lost, "Easy: no -N lost popup")
		else:
			check(Game.dive.carried == 0, "Hard: the carried 20 are lost too (carried %d)" % Game.dive.carried)
			check(_popups(tr("POPUP_LOST") % (held + 20)) == 1, "Hard: the popup shows -%d lost, held and carried" % (held + 20))
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
	var j := JSON.new()
	var err := j.parse(FileAccess.get_file_as_string(TMP.path_join("slot_1.json")))
	var slot: Dictionary = j.get_data().get("slot", {}) if err == OK and j.get_data() is Dictionary else {}
	check(slot.get("difficulty") == "hard" and slot.get("cache") == {"room": "m1_shaft", "x": SPOT_A.x, "y": SPOT_A.y, "amount": 12.0},
			"a progress save (the tier change) after a recovery writes the last resume save's cache (got %s)" % [slot.get("cache")])
	await _free_world()


# --- A cache hunt over a ticking player -----------------------------------------------------------

## The harness player in smoke_lurker never polls contact, so this is the check with a ticking one:
## a lurker hunting a cache, sitting on the player for 30 ticks, deals no damage (1.20 D7).
func test_cache_hunt_harmless() -> void:
	_lurkers_on = true
	_boot(&"t_spikes")
	await frames(2)
	var p := _p()
	var hits := []
	p.health.damaged.connect(func(amount: int, cause: StringName) -> void: hits.append([amount, cause]))
	await _stand_at(SPIKES_P)
	var cache: EmberCache = _room().spawn(EmberCacheScene, Vector2(24, 68))  # P's ledge, beside the player
	var source: LightSource = cache.get_node(^"LightSource")
	var l: Lurker = null
	for n in _room().get_children():
		if n is Lurker:
			l = n
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
	await _free_world()
