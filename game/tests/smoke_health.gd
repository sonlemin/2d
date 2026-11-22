extends Node
## Health on the real World (Story 1.19, AC2–AC8): crawler and lurker contact through the one
## hurt() path, the poll's own `monitorable` read, spikes and the safe ground (the seed on an `up`
## arrival included), death at 0 HP and the full-HP respawn, the bank-heal, the hit flash and the
## pogo squash's clock. On tests/rooms/hazards/t_spikes.txt (P on a ledge, a walker on its own
## ledge, an in-wall lurker, ^^^^ on the floor at columns 6-9, up/down self-loops).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_health.gd
## Frame maths (development-guide.md): a read after an `await` sees the last tick the player ran.
## The Probe runs inside each tick after World (its hazard poll) and before the Player, so it sees
## a spike's return before the player's own tick moves it.

const WorldScene := preload("res://scenes/world/world.tscn")
const Spec := preload("res://tests/spec.gd")
const TMP := "user://smoke_health_tmp"
const ROOM := &"t_spikes"
const STAND_Y := 196.0  ## feet on the floor row 13: (13 × 16) − 12
const P_POS := Vector2(40, 68)  ## the P cell (2, 4)
const OPEN := Vector2(200, 60)  ## column 12, in the air: straight down onto clean floor
const SPIKES_LEFT := 96.0  ## x of the spike run's left edge (column 6)
const DIM_AC8 := 0.6  ## the reduce-flashing dim (epics 1.19, UX-DR126), never read from Fx
const FLASH_TICKS_AC8 := 4  ## 67 ms of white (epics 1.19)
const DIM_TICKS_AC8 := 6  ## 100 ms of dim (epics 1.19)
const GAP_TICKS_Q1 := 60  ## Q1 (sonlm): the white flash at most once per second


## Calls `job` every physics tick from inside World, before the room and the Player.
class Probe extends Node:
	var job: Callable

	func _init(j: Callable) -> void:
		job = j

	func _physics_process(_delta: float) -> void:
		if job.is_valid():
			job.call()


var _fail := 0
var _world: World
var _spawned: Array[Player] = []
var _hits: Array = []  # [amount, cause] for every damaged of every life
var _died := 0
var _ticks: Array[Dictionary] = []  # the Probe's records while _recording
var _recording := false


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	RoomLoader.add_root("res://tests/rooms/hazards")
	_boot(&"spawn")
	await frames(2)
	await test_crawler_contact()
	await test_flash_reduced()
	await test_lurker_hunt()
	await test_lurker_harmless()
	await test_contact_causes()
	await test_stale_list()
	await test_predator_first()
	await test_spikes_walk_off()
	await test_spikes_invulnerable()
	await test_bank_heal()
	await test_death_and_respawn()
	await test_squash()
	await _free_world()
	_boot(&"up")
	await test_seed_up_arrival()
	await _free_world()
	Game.reset_for_tests()
	for f in DirAccess.get_files_at(TMP):  # remove_absolute() fails on a folder that is not empty
		DirAccess.remove_absolute(TMP.path_join(f))
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Setup ------------------------------------------------------------------------------------------

func _boot(entry: StringName) -> void:
	Game.store.dir = TMP  # per boot: _free_world()'s reset_for_tests() points it home again
	_spawned.clear()
	_world = WorldScene.instantiate()
	_world.start_room = ROOM
	_world.start_entry = entry
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	add_child(_world)
	var probe := Probe.new(_on_probe)
	probe.name = "HealthProbe"
	_world.add_child(probe)
	_world.move_child(probe, 0)  # after World's own tick, before the room and the Player


func _free_world() -> void:
	for a in ["move_left", "move_right", "light", "attack", "jump"]:
		Input.action_release(a)
	_world.queue_free()
	await get_tree().process_frame
	await frames(1)
	Game.reset_for_tests()


func _on_spawned(player: Player) -> void:
	_spawned.append(player)
	player.health.damaged.connect(_on_damaged)
	player.died.connect(_on_died)
	# Every case is about one actor at a time: the lurker acts only where a case drives it.
	if _world.current_room() != null:
		for n in _world.current_room().get_children():
			if n is Lurker:
				n.set_physics_process(false)


func _on_damaged(amount: int, cause: StringName) -> void:
	_hits.append([amount, cause])


func _on_died() -> void:
	_died += 1


func _on_probe() -> void:
	if not _recording or _spawned.is_empty():
		return
	var p := _p()
	var cam := _world.get_node("Camera") as CameraRig
	_ticks.append({pos = p.position, vel = p.velocity, safe = _world.last_safe_position(), hits = _hits.size(),
			floor = p.is_on_floor(), smoothed = cam._smoothed, lead = cam._lead})


func _p() -> Player:
	return _spawned[-1]


func _room() -> Room:
	return _world.current_room()


func _sprite() -> Sprite2D:
	return _p().get_node("Sprite") as Sprite2D


## The room's first walker by position (row, then column), never by group order.
func _walker() -> Crawler:
	var out: Array[Crawler] = []
	for n in _room().get_children():
		if n is Crawler and not n.hover and not n.is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Crawler, b: Crawler) -> bool: return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return out[0] if not out.is_empty() else null


func _lurker() -> Lurker:
	for n in _room().get_children():
		if n is Lurker:
			return n
	return null


## Full HP, no invulnerability, no flash running, no gap left from an earlier white flash (Q1), and
## the player still at `pos`.
func _fresh(pos: Vector2, hp := Spec.MAX_HP) -> void:
	for a in ["move_left", "move_right", "light", "attack", "jump"]:
		Input.action_release(a)
	Game.settings.set_value(&"reduce_flashing", false)
	_p().place_at(pos)
	await frames(GAP_TICKS_Q1 + 1)
	_p().health.reset(hp)
	_p().place_at(pos)
	await frames(1)


## Mid-air over the walker, the Hurtbox already on it (feet 4 px above its ledge): the next ticks
## poll a contact before any floor tick.
func _over_walker() -> Vector2:
	var w := _walker()
	return Vector2(w.position.x + 6.0, 128.0)


## Waits for the next damaged, at most `cap` ticks; returns the tick count or -1.
func _await_hit(cap: int) -> int:
	var n := _hits.size()
	for i in cap:
		await frames(1)
		if _hits.size() > n:
			return i + 1
	return -1


# --- AC2: crawler contact -------------------------------------------------------------------------

## One damaged(1, crawler_walker), HP 3, the M1 knockback away from it on the hit tick, 0.6 s of
## invulnerability, no second hit while it lasts though still overlapping, held -> carried. The hit
## flash: white on the hit tick and 3 more, then restored; a second hit inside 60 ticks shows none.
func test_crawler_contact() -> void:
	await _fresh(P_POS)
	var p := _p()
	var w := _walker()
	_hits.clear()
	var carried := Game.dive.carried
	p.place_at(_over_walker())
	for i in 3:
		p.chain.add_hit()  # held 1 + 2 + 3 = 6
	var held: int = p.chain.held
	var at := await _await_hit(10)
	check(at > 0 and _hits == [[Spec.DAMAGE[&"crawler"], &"crawler_walker"]], "a walker's contact: exactly one damaged(1, crawler_walker) (got %s after %d ticks)" % [_hits, at])
	var away := signf(p.position.x - w.position.x)
	check(p.health.hp == Spec.MAX_HP - 1, "...HP %d (got %d)" % [Spec.MAX_HP - 1, p.health.hp])
	check(away > 0.0 and p.velocity == Vector2(150.0 * away, -150.0), "...knocked away from it at (±150, −150) on the hit tick (GDD Health; got %s)" % p.velocity)
	check(is_equal_approx(p.health.invuln, Spec.INVULN_S), "...%s s of invulnerability (got %s)" % [Spec.INVULN_S, p.health.invuln])
	check(held == 6 and Game.dive.carried == carried + 6 and p.chain.held == 0 and p.chain.count == 0, "...and the held 6 are carried (FR11: carried %d -> %d)" % [carried, Game.dive.carried])
	# The flash, on the hit tick and the 3 after it, then restored (D9).
	# With modulate.a at 1: a white drawn on a dark tick of the blink would be no flash at all.
	var white: Array[bool] = [_sprite().material == Fx.flash_material() and _sprite().modulate.a == 1.0]
	for i in FLASH_TICKS_AC8:
		await frames(1)
		white.append(_sprite().material == Fx.flash_material() and _sprite().modulate.a == 1.0)
	check(white == ([true, true, true, true, false] as Array[bool]), "...white (the flash material, at alpha 1) on the hit tick and 3 more, then none (got %s)" % [white])
	# Still overlapping, invulnerable: no second hit. Kept standing on the walker's ledge, beside it,
	# up to two ticks before the invulnerability ends (the walker hits again in the tick it does,
	# so invulnerable() never reads false in between).
	var overlapped := 0
	var since := FLASH_TICKS_AC8
	var hurtbox := p.get_node("Hurtbox") as Area2D
	while p.health.invuln > 2.0 / Engine.physics_ticks_per_second:
		p.place_at(Vector2(_walker().position.x + 6.0, 132.0))
		await frames(1)
		since += 1
		if hurtbox.overlaps_body(_walker()):
			overlapped += 1
	check(overlapped >= 20 and _hits.size() == 1, "...no second hit while invulnerable, though overlapping it for %d ticks (hits %d)" % [overlapped, _hits.size()])
	# Q1: the walker hits again as the invulnerability ends, inside 60 ticks of the first: no white.
	var again := await _await_hit(10)
	since += again
	check(again > 0 and since < GAP_TICKS_Q1 and _sprite().material == null and p.health.hp == Spec.MAX_HP - 2,
			"a second hit %d ticks after the first (under %d) shows no white (Q1: once per second; material %s)" % [since, GAP_TICKS_Q1, _sprite().material])


## UX-DR126: under reduce flashing the hit dims the sprite to 0.6 for 6 ticks, never white.
func test_flash_reduced() -> void:
	await _fresh(P_POS)
	Game.settings.set_value(&"reduce_flashing", true)
	_hits.clear()
	_p().place_at(_over_walker())
	var at := await _await_hit(10)
	var seen: Array[bool] = []
	var dim := Color(DIM_AC8, DIM_AC8, DIM_AC8, 1.0)
	seen.append(_sprite().self_modulate.is_equal_approx(dim) and _sprite().material == null)
	for i in DIM_TICKS_AC8:
		await frames(1)
		seen.append(_sprite().self_modulate.is_equal_approx(dim) and _sprite().material == null)
	check(at > 0 and seen == ([true, true, true, true, true, true, false] as Array[bool]),
			"reduce flashing: self_modulate %s and no material from the hit tick for 6 ticks, then restored (got %s)" % [DIM_AC8, seen])
	check(_sprite().self_modulate == Color.WHITE, "...self_modulate back to white")
	Game.settings.set_value(&"reduce_flashing", false)


# --- AC3: the lurker ------------------------------------------------------------------------------

## A HUNT lurker on the player deals 2 with the same knockback. Its physics is off, so it stays in
## HUNT and monitorable (a live one would lose the grounded player's 40 px light at once).
func test_lurker_hunt() -> void:
	var spot := Vector2(200, STAND_Y)
	await _fresh(spot)
	var l := _lurker()
	_hits.clear()
	l.force(Lurker.State.HUNT, _p().light_source)
	l.global_position = _p().global_position + Vector2(-4, 0)
	var at := await _await_hit(10)
	var p := _p()
	check(at > 0 and _hits[0] == [Spec.DAMAGE[&"lurker"], &"lurker"] and p.health.hp == Spec.MAX_HP - 2,
			"a HUNT lurker on the player: damaged(2, lurker), HP %d (got %s, HP %d)" % [Spec.MAX_HP - 2, _hits, p.health.hp])
	check(p.velocity == Vector2(150.0, -150.0), "...knocked back away from it, as a crawler knocks (got %s)" % p.velocity)
	l.force(Lurker.State.IDLE)
	l.global_position = l._home


## Every actor's contact_cause() is a Health.CAUSES id with the GDD's damage: a walker and a hoverer
## 1, a lurker 2 (review of Story 1.19: the hoverer's was never exercised, and the only guard on an
## unknown id is an assert, which a release build strips).
func test_contact_causes() -> void:
	await _fresh(P_POS)
	var hoverer: Crawler = preload("res://scenes/actors/crawler.tscn").instantiate()
	hoverer.hover = true
	var got := [_walker().contact_cause(), hoverer.contact_cause(), _lurker().contact_cause()]
	check(got == [&"crawler_walker", &"crawler_hoverer", &"lurker"], "contact_cause(): a walker, a hoverer and a lurker name their own cause (got %s)" % [got])
	check(got.all(func(c: StringName) -> bool: return Health.CAUSES.has(c)), "...and each is in Health.CAUSES")
	_hits.clear()
	var landed := _p().hurt(hoverer.contact_cause(), _p().global_position + Vector2(8, 0))
	check(landed and _hits == [[Spec.DAMAGE[&"crawler"], &"crawler_hoverer"]] and _p().health.hp == Spec.MAX_HP - 1,
			"a hoverer's contact through hurt(): one damaged(%d, crawler_hoverer) (got %s)" % [Spec.DAMAGE[&"crawler"], _hits])
	hoverer.free()


## IDLE, TELEGRAPH and RETURN on the player deal nothing (Pillar 2).
func test_lurker_harmless() -> void:
	var spot := Vector2(200, STAND_Y)
	for s: Lurker.State in [Lurker.State.IDLE, Lurker.State.TELEGRAPH, Lurker.State.RETURN]:
		await _fresh(spot)
		var l := _lurker()
		_hits.clear()
		l.force(s, _p().light_source)
		var premise := true
		for i in 20:
			l.global_position = _p().global_position
			await frames(1)
			# On the Hurtbox (its radius is 7), still not hunting, still harmless.
			premise = premise and l.state != Lurker.State.HUNT and not l.monitorable \
					and l.global_position.distance_to(_p().global_position) < 7.0
		check(premise, "(premise) the %s lurker stays on the player, out of HUNT and not monitorable, for the 20 ticks (state %s)" % [Lurker.State.keys()[s], Lurker.State.keys()[l.state]])
		check(_hits.is_empty() and _p().health.hp == Spec.MAX_HP, "a %s lurker on the player for 20 ticks deals no damage (got %s)" % [Lurker.State.keys()[s], _hits])
		l.force(Lurker.State.IDLE)
		l.global_position = l._home


## D3, D12: the poll reads `monitorable` itself. A HUNT lurker sits on the player until the overlap
## list has it (the player invulnerable meanwhile); then, between ticks, it turns monitorable off.
## That tick's poll still sees it listed (the list lags a monitorable change by a step), but not
## monitorable: no damage. Without the read, this hits.
func test_stale_list() -> void:
	var spot := Vector2(200, STAND_Y)
	await _fresh(spot)
	var p := _p()
	var l := _lurker()
	var hurtbox := p.get_node("Hurtbox") as Area2D
	_hits.clear()
	p.health.invuln = 10.0
	l.force(Lurker.State.HUNT, p.light_source)
	l.global_position = p.global_position
	var listed := false
	for i in 10:
		await frames(1)
		if l in hurtbox.get_overlapping_areas():
			listed = true
			break
	# Now between ticks (an await resumes before the tick's callbacks).
	p.health.invuln = 0.0
	l.monitorable = false
	var still := l in hurtbox.get_overlapping_areas()
	await frames(1)
	check(listed and still and _hits.is_empty() and p.health.hp == Spec.MAX_HP,
			"a lurker listed by the Hurtbox but no longer monitorable deals no damage on that tick (premise: listed %s, still listed %s; got %s)" % [listed, still, _hits])
	l.force(Lurker.State.IDLE)
	l.global_position = l._home


## AC3: a predator and a crawler touching on one tick: the predator is taken (the larger hit;
## deterministic), one hit, then invulnerability. Both are listed before the poll may hit (the player
## invulnerable meanwhile), so the tick that decides sees both.
func test_predator_first() -> void:
	await _fresh(P_POS)
	var p := _p()
	var l := _lurker()
	var hurtbox := p.get_node("Hurtbox") as Area2D
	_hits.clear()
	p.health.invuln = 10.0
	p.place_at(Vector2(_walker().position.x + 6.0, 132.0))
	l.force(Lurker.State.HUNT, p.light_source)
	var both := false
	for i in 10:
		l.global_position = p.global_position
		await frames(1)
		if l in hurtbox.get_overlapping_areas() and hurtbox.overlaps_body(_walker()):
			both = true
			break
	p.health.invuln = 0.0  # between ticks: the next poll sees both
	await frames(1)
	check(both and _hits == [[Spec.DAMAGE[&"lurker"], &"lurker"]], "a lurker and a walker on the player in one tick: the lurker's 2 is taken, one hit only (premise: both listed %s; got %s)" % [both, _hits])
	l.force(Lurker.State.IDLE)
	l.global_position = l._home


# --- AC6: spikes ----------------------------------------------------------------------------------

## Walks right off P's ledge, lands on the clean floor beside the spikes, then walks into them.
## Returns the Probe's record of the tick the player was returned in, or {}.
func _walk_into_spikes() -> Dictionary:
	var p := _p()
	Input.action_press("move_right")
	var left_ledge := false
	for i in 60:
		await frames(1)
		if not p.is_on_floor() and p.position.x > 64.0:
			left_ledge = true
			break
	Input.action_release("move_right")  # drop straight down onto the floor left of the spikes
	var landed := false
	for i in 90:
		await frames(1)
		if p.is_on_floor() and p.position.y > 150.0:
			landed = true
			break
	check(left_ledge and landed and p.position.x + 4.0 < SPIKES_LEFT, "(premise) walked off P's ledge and landed on clean floor beside the spikes at %s" % p.position)
	_ticks.clear()
	_recording = true
	Input.action_press("move_right")
	var back := {}
	# The return: the first record, after the walk got going, with the velocity zeroed (place_at). It
	# jumps back only a tick or so of the walk, so a position jump is no sign of it.
	for i in 60:
		await frames(1)
		var walking := false
		for t: Dictionary in _ticks:
			walking = walking or t.vel.x > 50.0
			if walking and t.vel == Vector2.ZERO:
				back = t
				break
		if not back.is_empty():
			break
	Input.action_release("move_right")
	_recording = false
	return back


func test_spikes_walk_off() -> void:
	await _fresh(P_POS)
	_hits.clear()
	var back := await _walk_into_spikes()
	var p := _p()
	check(not back.is_empty() and _hits == [[Spec.DAMAGE[&"hazard"], &"spikes"]] and p.health.hp == Spec.MAX_HP - 1,
			"walking into ^^^^: one damaged(1, spikes), HP %d (got %s)" % [Spec.MAX_HP - 1, _hits])
	if back.is_empty():
		return
	var safe: Vector2 = back.safe
	var r := Rect2(safe + Vector2(-4, -7), Vector2(8, 18))  # the Hurtbox at the safe spot
	# A body at rest sits up to move_and_slide's safe margin above the floor (y 195.93, not 196).
	check(back.pos == safe and absf(safe.y - STAND_Y) < 0.5 and safe.x + 4.0 <= SPIKES_LEFT and not _room().touches_hazard(r),
			"...returned to last_safe_position(), the floor beside the spikes, touching none (got %s, safe %s)" % [back.pos, safe])
	check(not is_equal_approx(safe.y, P_POS.y), "...not the ledge it walked off")
	check(back.vel == Vector2.ZERO and back.smoothed == back.pos and back.lead == 0.0, "...standing still, the camera snapped onto it (velocity %s, camera %s)" % [back.vel, back.smoothed])
	check(p.velocity.y >= 0.0 and not p.is_dead, "...and alive")


## Q2 (sonlm): while invulnerable a spike deals nothing, but still returns the player.
func test_spikes_invulnerable() -> void:
	await _fresh(P_POS)
	_hits.clear()
	_p().health.invuln = 30.0
	var back := await _walk_into_spikes()
	check(not back.is_empty() and _hits.is_empty() and back.pos == back.safe and back.vel == Vector2.ZERO
			and back.pos.x + 4.0 <= SPIKES_LEFT and not _room().touches_hazard(Rect2(back.pos + Vector2(-4, -7), Vector2(8, 18))),
			"invulnerable: a spike deals no damage but still returns the player to safe ground, left of the spikes and touching none (got %s, hits %s)" % [back.get("pos"), _hits])
	_p().health.invuln = 0.0


# --- AC5: bank-heal -------------------------------------------------------------------------------

## FR12: +1 HP for a safely banked chain of 10 (a landing, a Snuff), none for 9, none for a hit.
func test_bank_heal() -> void:
	var p := _p()
	# Land with 10: HP 3 -> 4.
	await _fresh(OPEN, Spec.MAX_HP - 1)
	for i in Spec.BANK_HEAL_MIN:
		p.chain.add_hit()
	await _land()
	check(p.health.hp == Spec.MAX_HP, "a chain of %d banked by landing heals 1 HP: 3 -> %d (got %d)" % [Spec.BANK_HEAL_MIN, Spec.MAX_HP, p.health.hp])
	# Land with 9: HP stays 3.
	await _fresh(OPEN, Spec.MAX_HP - 1)
	for i in Spec.BANK_HEAL_MIN - 1:
		p.chain.add_hit()
	await _land()
	check(p.health.hp == Spec.MAX_HP - 1, "...a chain of %d heals nothing (got %d)" % [Spec.BANK_HEAL_MIN - 1, p.health.hp])
	# 10, then a crawler hit: HP 3 -> 2, no heal.
	await _fresh(P_POS, Spec.MAX_HP - 1)
	_hits.clear()
	p.place_at(_over_walker())
	for i in Spec.BANK_HEAL_MIN:
		p.chain.add_hit()
	var at := await _await_hit(10)
	await _land()
	check(at > 0 and p.health.hp == Spec.MAX_HP - 2, "...a chain of %d broken by a crawler hit heals nothing: 3 -> 2 (got %d)" % [Spec.BANK_HEAL_MIN, p.health.hp])
	# 10, then a Snuff (a real hold of light): HP 3 -> 4.
	await _fresh(Vector2(OPEN.x, 24), Spec.MAX_HP - 1)
	for i in Spec.BANK_HEAL_MIN:
		p.chain.add_hit()
	Input.action_press("light")
	var snuffed := false
	for i in 30:
		await frames(1)
		if p.chain.snuffed:
			snuffed = true
			break
	check(snuffed and not p.is_on_floor() and p.health.hp == Spec.MAX_HP, "...a chain of %d ended by a Snuff in mid-air heals 1 HP: 3 -> %d (got %d)" % [Spec.BANK_HEAL_MIN, Spec.MAX_HP, p.health.hp])
	Input.action_release("light")
	await _land()


func _land() -> void:
	await frames(1)
	for i in 120:
		if _p().is_on_floor():
			return
		await frames(1)


# --- AC7: death and the respawn -------------------------------------------------------------------

## 0 HP is death: died once, the cause recorded, the held embers lost (not carried). A lethal hit
## flashes white too, and the dead sprite is restored 4 ticks later. The respawn is the same World
## with a new Player at full HP (FR13, AR25).
func test_death_and_respawn() -> void:
	await _fresh(P_POS, 1)
	var p := _p()
	var world_id := _world.get_instance_id()
	var scene := get_tree().current_scene
	_hits.clear()
	_died = 0
	var carried := Game.dive.carried
	var spawned := _spawned.size()
	p.place_at(_over_walker())
	for i in 3:
		p.chain.add_hit()
	var at := await _await_hit(10)
	var lethal_frame := Engine.get_physics_frames()
	check(at > 0 and _died == 1 and p.is_dead and p.death_cause == &"crawler_walker", "at 1 HP a walker's hit kills: died once, death_cause crawler_walker (died %d, cause '%s')" % [_died, p.death_cause])
	check(Game.dive.carried == carried and p.chain.held == 0, "...and the held 6 are lost, not carried (D2: carried %d -> %d)" % [carried, Game.dive.carried])
	check(_sprite().material == Fx.flash_material(), "...the lethal hit flashes white on its tick (AC8)")
	await frames(FLASH_TICKS_AC8)
	check(is_instance_valid(p) and (p.get_node("Sprite") as Sprite2D).material == null, "...and the dead sprite is restored %d ticks later" % FLASH_TICKS_AC8)
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > spawned:
			break
		await frames(1)
	var q := _p()
	check(_spawned.size() == spawned + 1 and q != p and q.health.hp == Spec.MAX_HP and not q.is_dead,
			"the respawn is a new Player at Spec.MAX_HP, %d (got %d)" % [Spec.MAX_HP, q.health.hp])
	check(_world.get_instance_id() == world_id and get_tree().current_scene == scene, "...in the same World, with no scene reload (AR25)")
	# Q1 across a death (sonlm, review of Story 1.19): World hands the gap to the new life, so a hit
	# inside 60 ticks of the lethal white shows no white. Per life they were 37 ticks apart.
	_hits.clear()
	q.place_at(_over_walker())
	var first := await _await_hit(10)
	var since := Engine.get_physics_frames() - lethal_frame
	check(first > 0 and since < GAP_TICKS_Q1 and (q.get_node("Sprite") as Sprite2D).material == null and q.health.hp == Spec.MAX_HP - 1,
			"the new life's hit %d ticks after the lethal white (under %d) shows no white: the gap outlives a life (material %s)" % [since, GAP_TICKS_Q1, (q.get_node("Sprite") as Sprite2D).material])
	# The control: kept on the walker, its next hit is over 60 ticks after the lethal white.
	while q.health.invuln > 2.0 / Engine.physics_ticks_per_second:
		q.place_at(Vector2(_walker().position.x + 6.0, 132.0))
		await frames(1)
	var second := await _await_hit(10)
	since = Engine.get_physics_frames() - lethal_frame
	check(second > 0 and since >= GAP_TICKS_Q1 and (q.get_node("Sprite") as Sprite2D).material == Fx.flash_material(),
			"...and its next hit, %d ticks after it, is white again" % since)


# --- AC8: the squash's clock ----------------------------------------------------------------------

## The pogo squash recovers on the physics tick at one tick = 1/60 s of real time, so it still shows
## through the 75 ms hitstop. `delta / Engine.time_scale` in _process snapped it to 1 on the hit
## frame (ledger, Story 1.16). Last: the pogo kills the walker.
func test_squash() -> void:
	await _fresh(P_POS)
	var p := _p()
	var w := _walker()
	var hit := [false]
	p.pogo_hit.connect(func() -> void: hit[0] = true)
	p.place_at(Vector2(w.position.x, 112.0))  # the pogo box on the walker, the Hurtbox above it
	Input.action_press("attack")
	for i in 10:
		await frames(1)
		if hit[0]:
			break
	Input.action_release("attack")
	# D9: a hit that lands in this hitstop flashes for its 4 ticks all the same, since the flash is
	# counted in physics frames (review of Story 1.19: the ledger claimed this check before it
	# existed). Spikes: no knockback, so the squash is left alone.
	var in_hitstop := Engine.time_scale < 1.0
	var landed := p.hurt(&"spikes")
	var white: Array[bool] = []
	var ys: Array[float] = []
	var scales: Array[float] = []
	for i in FLASH_TICKS_AC8 + 1:
		await frames(1)
		white.append(_sprite().material == Fx.flash_material())
		if i < 2:
			ys.append(_sprite().scale.y)
			scales.append(Engine.time_scale)
	check(hit[0] and scales.all(func(s: float) -> bool: return s < 1.0), "(premise) a pogo hit, and the next 2 ticks are inside its hitstop (time scale %s)" % [scales])
	check(ys.size() == 2 and ys.all(func(y: float) -> bool: return y > 1.15), "the pogo squash still shows on the 2 ticks after the hit, in the hitstop (scale.y %s > 1.15)" % [ys])
	check(in_hitstop and landed and white == ([true, true, true, true, false] as Array[bool]),
			"a hit landing in that hitstop is white for its 4 ticks, then restored (D9; in hitstop %s, got %s)" % [in_hitstop, white])
	await frames(30)
	check(is_equal_approx(_sprite().scale.y, 1.0) or absf(_sprite().scale.y - 1.0) < 0.01, "...and has eased back half a second later (scale.y %.3f)" % _sprite().scale.y)


# --- AC6, D6: the seed on an `up` arrival ---------------------------------------------------------

## Arriving from above, the player falls before any floor tick: the safe ground is seeded with
## Room.ground_below(&"up") at the build, so a spike hit then returns them to the floor below the
## entry, standing, never to the top opening.
func test_seed_up_arrival() -> void:
	var room := _room()
	var seeded := room.ground_below(&"up")
	check(_world.last_safe_position() == seeded and seeded != room.entry_position(&"up") and is_equal_approx(seeded.y, STAND_Y),
			"an up arrival: right after the build, last_safe_position() is ground_below(up), %s, not the entry %s (got %s)" % [seeded, room.entry_position(&"up"), _world.last_safe_position()])
	_hits.clear()
	_ticks.clear()
	_recording = true
	var p := _p()
	# Steer left over the spikes, then fall straight onto them.
	Input.action_press("move_left")
	var back := {}
	for i in 120:
		await frames(1)
		if p.position.x < 140.0:
			Input.action_release("move_left")
		for k in range(1, _ticks.size()):
			if _ticks[k].hits > _ticks[k - 1].hits:
				back = _ticks[k]
				break
		if not back.is_empty():
			break
	Input.action_release("move_left")
	_recording = false
	var touched_floor := false
	for t: Dictionary in _ticks:
		if t == back:
			break
		touched_floor = touched_floor or t.floor
	check(not back.is_empty() and not touched_floor and _hits == [[Spec.DAMAGE[&"hazard"], &"spikes"]],
			"(premise) it falls onto the spikes before any floor tick (hits %s, a floor tick first: %s)" % [_hits, touched_floor])
	check(not back.is_empty() and back.pos == seeded and back.vel == Vector2.ZERO, "...and is returned to that seed, still, not the top opening (got %s)" % [back.get("pos")])
	await frames(2)
	check(p.is_on_floor() and p.position == seeded, "...standing there (on floor %s at %s)" % [p.is_on_floor(), p.position])
