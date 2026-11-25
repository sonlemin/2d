extends Node
## Light sensing for predators (Story 1.20, AR28–AR31, FR16–FR21), on the fixture room
## tests/rooms/sensing/t_sensing.txt (one lurker in the left wall at (8, 200)) through RoomHarness:
## - the M1 trace: a lone player light behaves tick for tick as on c40e75f (D8);
## - LightSource: the rule radius vs the shown one, the budget's demotion left alone, the first-tick
##   snap, a dead player's light (D4, D5);
## - target choice and retargeting with stand-in lights (FR16, FR21; D6): identity by node, a decoy
##   to a decoy, and the decoy kept off screen (review of 1.20);
## - stirring off screen, its step limit and the stir-to-hunt guarantee (AC5; D3, D9);
## - Q1 (the hunt senses off screen, the telegraph doesn't), Q2 (re-sense in the wait), no World.
## The player's physics is off throughout (placed by hand, the camera snapped), so the play rect is
## exact and the only actor deciding anything is the lurker. Stand-ins are LightSources added under
## the room (AR23: it frees them). Frame maths (development-guide.md): a read after an await sees the
## last tick the lurker ran; a change made after an await is seen by the next tick's callbacks.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_lurker.gd

const RoomHarness := preload("res://tests/room_harness.gd")
const Spec := preload("res://tests/spec.gd")
const LightTexture := preload("res://art/light.png")
const PlayerScene := preload("res://scenes/actors/player.tscn")
const TRACE := "res://tests/fixtures/lurker_trace_m1.json"
## The fixture room's lurker, written out (cell (0, 12) of 16 px tiles, its centre).
const LURKER_AT := Vector2(8, 200)
## UX DESIGN.md Layout & Spacing: the view is 270 px tall, written out (as smoke_rooms writes the width).
const VIEW_H := 270.0
## The player beside the lurker on screen: 100 px to its right, level with it (the camera clamps to
## the room's top, so the play rect is y 0–270 and the lurker sits well inside the notice rect).
const BESIDE := Vector2(108, 200)
## Where a decoy sits: 58 px from the lurker, on screen.
const DECOY_AT := Vector2(58, 170)
## The player whose camera puts the lurker 40 px above the play rect: centre 200 + 40 + 135.
const BELOW_40 := Vector2(40, 375)
## The player whose camera puts the lurker 4 px inside the play rect's top, in the 8 px margin band.
const BELOW_BAND := Vector2(40, 331)
## The chains used here: 10 (109.6 px, sensed from 175 px) and 20 (138.4 px, from 221 px).
const CHAIN_MID := 10
const CHAIN_MAX := 20

var _fail := 0
var _h: Dictionary
var _room: Room
var _p: Player
var _l: Lurker


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	RoomLoader.add_root("res://tests/rooms/sensing")
	await test_trace()
	await test_light_source()
	await test_first_tick()
	await test_demoted()
	await test_target_choice()
	await test_flare_to_player_in_telegraph()
	await test_tie()
	await test_player_to_flare()
	await test_identity()
	await test_decoy_to_decoy()
	await test_off_screen_decoy()
	await test_light_out()
	await test_stirring()
	await test_stir_pacing_light()
	await test_stir_pacing_edge()
	await test_stir_to_hunt()
	await test_q1_off_screen()
	await test_q2_resense()
	await test_no_world()
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Helpers ------------------------------------------------------------------------------------

func _build(id := &"t_sensing", entry := &"spawn") -> void:
	_h = RoomHarness.build(self, id, entry)
	_room = _h.room
	_p = _h.player
	Game.clock.clear()
	await frames(2)
	_p.set_physics_process(false)
	_l = _lurkers()[0]


func _free() -> void:
	RoomHarness.free_all(_h)
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(1)


## The room's lurkers by position (row, then column), never by group order.
func _lurkers() -> Array[Lurker]:
	var out: Array[Lurker] = []
	for n in _room.get_children():
		if n is Lurker:
			out.append(n)
	out.sort_custom(func(a: Lurker, b: Lurker) -> bool:
		return a.global_position.y < b.global_position.y or (a.global_position.y == b.global_position.y and a.global_position.x < b.global_position.x))
	return out


func place(pos: Vector2) -> void:
	_p.global_position = pos
	_p.velocity = Vector2.ZERO
	_h.camera.snap()


func _chain(n: int) -> void:
	_p.chain.break_chain()
	for i in n:
		_p.chain.add_hit()


func _play() -> Rect2:
	return _h.world.play_rect()


## A stand-in light (D1): a LightSource of `kind` with a set radius, a child of the room. With
## `lit`, it gets a child BudgetLight "Light" (rank CACHE, so the budget may demote it).
func _stand_in(kind: StringName, radius: float, pos: Vector2, lit := false) -> LightSource:
	var s := LightSource.new()
	s.name = "StandIn"
	s.kind = kind
	s.fixed_radius = radius
	s.position = pos
	if lit:
		var l := BudgetLight.new()
		l.name = "Light"
		l.rank = BudgetLight.Rank.CACHE
		l.texture = LightTexture
		s.add_child(l)
	_room.add_child(s)
	return s


func _kind(l: Lurker) -> StringName:
	return l.target.kind if LightSource.live(l.target) else &"none"


func _name(s: int) -> String:
	return Lurker.State.keys()[s]


## The telegraph floor in ticks: Spec.TELEGRAPH_MIN at 60 ticks/s. Each case here sees the first
## TELEGRAPH tick, so its count is exact and takes no one-tick allowance (smoke_rooms needs one: its
## telegraph may start a frame unseen). Review of 1.20: `+ 1` let 44 ticks (0.733 s) pass.
func _floor_ticks() -> int:
	return int(ceil(Spec.TELEGRAPH_MIN * Engine.physics_ticks_per_second))


## The most changes of `values` inside any 60-tick window (a second at 60 ticks/s).
static func _max_changes_per_second(values: Array) -> int:
	var at: Array[int] = []
	for i in range(1, values.size()):
		if values[i] != values[i - 1]:
			at.append(i)
	var most := 0
	for i in at.size():
		var n := 0
		for j in range(i, at.size()):
			if at[j] - at[i] < 60:
				n += 1
		most = maxi(most, n)
	return most


# --- 1. The M1 trace (D8) -------------------------------------------------------------------------

## The scenario recorded on the baseline tree (Task 1), replayed with the same setup: the lurker
## notices on its own (no force()), so this pins notice, telegraph, hunt, the lost scent and the
## return for a lone player light.
func test_trace() -> void:
	var f := FileAccess.open(TRACE, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(f.get_as_text()) if f != null else ERR_FILE_CANT_OPEN
	check(err == OK and json.data is Dictionary and (json.data.ticks as Array).size() == 180, "the M1 trace fixture reads: 180 ticks (err %s)" % error_string(err))
	if err != OK:
		return
	var want: Array = json.data.ticks
	await _build(&"m1_shaft")
	var lurker := _lurkers()[1]
	for l in _lurkers():
		l.set_physics_process(l == lurker)
	_chain(CHAIN_MID)
	var toward := signf(_room.bounds().get_center().x - lurker.global_position.x)
	place(lurker.global_position + Vector2(toward * 100.0, 0))
	var home := Vector2i(int(json.data.lurker_home[0]), int(json.data.lurker_home[1]))
	var spot := Vector2i(int(json.data.player[0]), int(json.data.player[1]))
	check(Vector2i(lurker.global_position.round()) == home and Vector2i(_p.global_position.round()) == spot,
			"(premise) the same lurker and player spot as the fixture (%s, %s)" % [json.data.lurker_home, json.data.player])
	var got: Array = []
	for i in 180:
		if i == 90:
			_p.chain.break_chain()
		await frames(1)
		got.append([int(lurker.state), lurker.monitorable, roundi(lurker.global_position.x), roundi(lurker.global_position.y)])
	var first := -1
	for i in 180:
		var w: Array = want[i]
		if [int(w[0]), bool(w[1]), int(w[2]), int(w[3])] != got[i]:
			first = i
			break
	check(first == -1, "a lone player light matches the M1 trace tick for tick over 180 ticks (telegraph, hunt, lost scent, return)%s" % ("" if first == -1 else ": tick %d wants %s, got %s" % [first, want[first], got[first]]))
	await _free()


# --- 2. LightSource (AC2; D4, D5) -----------------------------------------------------------------

## radius() is the chain's, through a pogo hit, a Snuff and a cling, and still the chain's on the tick
## after kick(): the shown radius moved, the rule value didn't. A death extinguishes it. The pogo hit
## is the player's own handler (review of 1.20: by hand, the test did the wiring it claimed to check).
func test_light_source() -> void:
	await _build()
	var ls := _p.light_source
	check(ls != null and ls.kind == Sensing.KIND_PLAYER and ls.is_in_group(&"light_source") and ls.light is BudgetLight,
			"the player carries a LightSource of kind player, in group light_source, driving its child BudgetLight")
	_chain(CHAIN_MID)
	await frames(30)
	var before := ls.shown_radius()
	_p._on_pogo_hit()  # the chain's hit and the light's kick, as a landed pogo makes them
	Game.clock.clear()  # its hitstop would slow the easing below
	await frames(1)
	check(ls.radius() == _p.chain.light_radius() and ls.radius() == ChainState.radius_for(CHAIN_MID + 1),
			"after a pogo hit, radius() is the chain's %.1f px (got %.1f)" % [ChainState.radius_for(CHAIN_MID + 1), ls.radius()])
	check(ls.shown_radius() > ls.radius() + 1.0 and ls.shown_radius() > before,
			"...on the tick after kick(), the shown radius flared past it (%.1f > %.1f), the rule value didn't" % [ls.shown_radius(), ls.radius()])
	check(is_equal_approx(ls.light.texture_scale, ls.shown_radius() / (LightTexture.get_width() / 2.0)),
			"...and the light's texture_scale is the shown radius over half the texture (got %.3f)" % ls.light.texture_scale)
	_p.chain.set_snuffed(true)
	await frames(1)
	check(ls.radius() == _p.chain.light_radius() and ls.radius() < Spec.NOTICE_MIN_RADIUS,
			"snuffed, radius() is the chain's %.1f px (got %.1f)" % [_p.chain.light_radius(), ls.radius()])
	_p.chain.set_snuffed(false)
	_p.chain.set_clinging(true)
	await frames(1)
	check(ls.radius() == _p.chain.light_radius() and ls.radius() == Spec.BASE_LIGHT,
			"clinging, radius() is the chain's base %.0f px (got %.1f)" % [Spec.BASE_LIGHT, ls.radius()])
	_p.chain.set_clinging(false)
	_p.die()
	check(not ls.is_in_group(&"light_source") and not ls.is_lit() and not LightSource.live(ls),
			"after die(), the light is out of group light_source and not lit (D5)")
	var shown := ls.shown_radius()
	await frames(5)
	check(ls.shown_radius() == shown, "...and its shown radius holds, as M1's dead light did (%.1f)" % shown)
	# Review of 1.20: `player` is the one kind that makes a hunt harmful, so it is never the default.
	var bare := LightSource.new()
	check(bare.kind != Sensing.KIND_PLAYER and not (bare.kind in Sensing.KINDS),
			"a LightSource built without a kind is not a player light: it has none until its owner sets one (got '%s')" % bare.kind)
	bare.queue_free()
	await _free()


## Children run _ready() before their parent, so the player's radius_fn arrives after the light's
## _ready(): the shown radius snaps on the first tick, never eased in from 0 (or from the base).
func test_first_tick() -> void:
	await _build()
	for l in _lurkers():
		l.set_physics_process(false)
	var fresh: Player = PlayerScene.instantiate()
	for i in CHAIN_MID:
		fresh.chain.add_hit()
	fresh.position = Vector2(200, 100)
	_room.add_child(fresh)
	await frames(1)
	var want := ChainState.radius_for(CHAIN_MID)
	check(fresh.light_source.shown_radius() == want and is_equal_approx(fresh.light_source.light.texture_scale, want / (LightTexture.get_width() / 2.0)),
			"a player spawned at chain %d shows %.1f px on its first tick, not eased in (got %.1f)" % [CHAIN_MID, want, fresh.light_source.shown_radius()])
	fresh.queue_free()
	await _free()


## The budget owns `enabled` (Story 1.12): a demoted light stays demoted while its LightSource eases
## it. The harness has no LightBudget, so only the LightSource could undo it.
func test_demoted() -> void:
	await _build()
	var s := _stand_in(Sensing.KIND_CACHE, 90.0, Vector2(200, 400), true)
	await frames(1)
	s.light.set_demoted(true)
	s.fixed_radius = 120.0
	var held := true
	for i in 10:
		await frames(1)
		held = held and s.light.demoted and not s.light.enabled
	check(held, "a demoted light stays demoted (enabled false) over 10 ticks of easing")
	check(s.shown_radius() > 90.0 and s.shown_radius() < 120.0 and is_equal_approx(s.light.texture_scale, s.shown_radius() / (LightTexture.get_width() / 2.0)),
			"...while its size eases toward the new radius (shown %.1f, texture_scale %.3f)" % [s.shown_radius(), s.light.texture_scale])
	await _free()


# --- 3. Target choice and retargeting (AC4; D6) ---------------------------------------------------

## Both noticed: the lurker telegraphs at the brighter flare, then hunts it, never monitorable. Then
## (flare -> player) the flare drops under the notice radius: the next tick is a full telegraph at the
## player, harmless throughout, then a harmful hunt.
func test_target_choice() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	var flare := _stand_in(Sensing.KIND_FLARE, 120.0, DECOY_AT)
	check(_l.notices(_p.light_source) and _l.notices(flare) and flare.radius() > _p.light_source.radius(),
			"(premise) both lights are noticed, the flare's %.0f px over the player's %.1f px" % [flare.radius(), _p.light_source.radius()])
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == flare, "the lurker telegraphs at the flare, the larger light (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	var harmless := not _l.monitorable
	var tele := 1
	while _l.state == Lurker.State.TELEGRAPH and tele < 300:
		await frames(1)
		harmless = harmless and not _l.monitorable
		tele += 1
	check(_l.state == Lurker.State.HUNT and _l.target == flare, "...then hunts the flare (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	for i in 30:
		await frames(1)
		harmless = harmless and not _l.monitorable and _l.target == flare
	check(harmless, "...and is never monitorable on any tick of that telegraph or hunt (Pillar 2: a decoy hunt can't hurt)")
	# Flare -> player (FR21).
	flare.fixed_radius = 60.0
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == _p.light_source,
			"flare -> player: the next tick telegraphs at the player (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	var held := 1
	harmless = not _l.monitorable
	while _l.state == Lurker.State.TELEGRAPH and held < 300:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			held += 1
			harmless = harmless and not _l.monitorable
	check(held >= _floor_ticks() and harmless,
			"...the full telegraph: %d ticks, at least Spec.TELEGRAPH_MIN %.2f s (%d ticks), never monitorable" % [held, Spec.TELEGRAPH_MIN, _floor_ticks()])
	check(_l.state == Lurker.State.HUNT and _l.target == _p.light_source and _l.monitorable,
			"...then hunts the player, monitorable (state %s, monitorable %s)" % [_name(_l.state), _l.monitorable])
	# Review of 1.20: the flare hunt ran at full speed; the telegraph must not hand that on.
	check(_l._velocity == Vector2.ZERO, "...from rest: the flare hunt's speed is not carried through the telegraph (velocity %s)" % _l._velocity)
	await _free()


## Row T3 (FR21): a telegraph at the flare that switches onto the player restarts in full. The flare
## drops out half way through: the player's telegraph still lasts at least Spec.TELEGRAPH_MIN.
func test_flare_to_player_in_telegraph() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	var flare := _stand_in(Sensing.KIND_FLARE, 120.0, DECOY_AT)
	await frames(30)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == flare, "(premise) half a second into a telegraph at the flare (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	flare.fixed_radius = 60.0
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == _p.light_source,
			"flare -> player mid-telegraph: the next tick telegraphs at the player (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	var held := 1
	var harmless := not _l.monitorable
	while _l.state == Lurker.State.TELEGRAPH and held < 300:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			held += 1
			harmless = harmless and not _l.monitorable
	check(held >= _floor_ticks() and harmless and _l.state == Lurker.State.HUNT,
			"...a full telegraph at the player, not the flare's remainder: %d ticks, at least Spec.TELEGRAPH_MIN (%d), harmless, then HUNT" % [held, _floor_ticks()])
	await _free()


## A tie goes to the non-player light (Sensing.pick_target()).
func test_tie() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	var flare := _stand_in(Sensing.KIND_FLARE, _p.light_source.radius(), DECOY_AT)
	await frames(1)
	check(flare.radius() == _p.light_source.radius() and _l.state == Lurker.State.TELEGRAPH and _l.target == flare,
			"a flare tying the player's %.1f px light draws the telegraph (target %s)" % [_p.light_source.radius(), _kind(_l)])
	await _free()


## Player -> flare (FR16): a brighter decoy in reach takes the hunt on that same tick, with no
## telegraph and no harm.
func test_player_to_flare() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	_l.force(Lurker.State.HUNT, _p.light_source)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.target == _p.light_source and _l.monitorable, "(premise) the lurker hunts the player, monitorable")
	var flare := _stand_in(Sensing.KIND_FLARE, 130.0, DECOY_AT)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.target == flare and not _l.monitorable,
			"player -> flare: the same tick shows HUNT at the flare, not monitorable (state %s, target %s, monitorable %s)" % [_name(_l.state), _kind(_l), _l.monitorable])
	var no_tele := true
	for i in 30:
		await frames(1)
		no_tele = no_tele and _l.state == Lurker.State.HUNT and not _l.monitorable
	check(no_tele, "...and never a TELEGRAPH tick or a harmful one over the next 30 ticks")
	await _free()


## AC4, "identity is the node, never the kind": a hunt of one player light that meets a second,
## brighter player light (a new life's light is such a node) owes it a full telegraph (row H3). A
## rule that compared kinds would hunt on.
func test_identity() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	_l.force(Lurker.State.HUNT, _p.light_source)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.target == _p.light_source and _l.monitorable, "(premise) the lurker hunts the player's light, monitorable")
	var other := _stand_in(Sensing.KIND_PLAYER, 130.0, DECOY_AT)
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == other and not _l.monitorable,
			"a second, brighter player light: the next tick telegraphs at it, harmless (state %s, monitorable %s)" % [_name(_l.state), _l.monitorable])
	var held := 1
	var harmless := not _l.monitorable
	while _l.state == Lurker.State.TELEGRAPH and held < 300:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			held += 1
			harmless = harmless and not _l.monitorable
	check(held >= _floor_ticks() and harmless and _l.state == Lurker.State.HUNT and _l.target == other,
			"...a full telegraph: %d ticks, at least Spec.TELEGRAPH_MIN (%d), harmless, then HUNT at the new light" % [held, _floor_ticks()])
	await _free()


## Row T4 (confirmed by sonlm at the review of 1.20): a telegraph that switches from one decoy to a
## brighter one keeps its timer, so the hunt starts on the tick it would have without the switch.
func test_decoy_to_decoy() -> void:
	var lengths: Array[int] = []
	for switch: bool in [false, true]:
		await _build()
		_chain(CHAIN_MID)
		place(BESIDE)
		var first := _stand_in(Sensing.KIND_FLARE, 120.0, DECOY_AT)
		await frames(1)
		check(_l.state == Lurker.State.TELEGRAPH and _l.target == first, "(premise) a telegraph at the first decoy (switch %s)" % switch)
		var ticks := 1
		var second: LightSource = null
		while _l.state == Lurker.State.TELEGRAPH and ticks < 300:
			if switch and ticks == 20:
				second = _stand_in(Sensing.KIND_CACHE, 130.0, DECOY_AT + Vector2(0, 30))
			await frames(1)
			if _l.state == Lurker.State.TELEGRAPH:
				ticks += 1
				if switch and ticks == 21:
					check(_l.target == second, "decoy -> decoy mid-telegraph: the target is the brighter one on the next tick (target %s)" % _kind(_l))
		check(_l.state == Lurker.State.HUNT and not _l.monitorable and (_l.target == second if switch else _l.target == first),
				"...then a harmless hunt of %s after %d TELEGRAPH ticks" % ["the second decoy" if switch else "the first decoy", ticks])
		lengths.append(ticks)
		await _free()
	check(lengths[0] == lengths[1] and lengths[0] >= _floor_ticks(),
			"the switch kept the timer: %d ticks with it, %d without (row T4)" % [lengths[1], lengths[0]])


## Review of 1.20 (sonlm, 2026-11-25): off screen, a lurker hunting a decoy stays on it when the
## player's light becomes the largest. It can't telegraph where it isn't seen (Pillar 2), so it never
## enters TELEGRAPH there and never harms; once the view brings it into the notice rect it switches
## onto the player with a full telegraph (row H3).
func test_off_screen_decoy() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BELOW_40)
	var decoy := _stand_in(Sensing.KIND_FLARE, 120.0, LURKER_AT + Vector2(50, 30))
	_l.force(Lurker.State.HUNT, decoy)
	await frames(5)
	check(_l.state == Lurker.State.HUNT and _l.target == decoy and not _play().has_point(_l.global_position),
			"(premise) off screen, the lurker hunts the decoy (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	_chain(CHAIN_MAX)
	check(_l.senses(_p.light_source) and not _l.notices(_p.light_source) and _p.light_source.radius() > decoy.radius(),
			"(premise) the player's %.1f px light is now the largest it senses, and it can't be noticed off screen" % _p.light_source.radius())
	var kept := true
	for i in 60:
		await frames(1)
		kept = kept and _l.state == Lurker.State.HUNT and _l.target == decoy and not _l.monitorable \
				and not Sensing.notice_rect(_play()).has_point(_l.global_position)
	check(kept, "off screen it stays on the decoy for 1 s: HUNT at the flare, never TELEGRAPH, never monitorable (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	# The view scrolls up until the lurker is inside the notice rect.
	place(Vector2(BELOW_40.x, 300))
	check(_l.notices(_p.light_source), "(premise) the view now holds the lurker inside the notice rect")
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH and _l.target == _p.light_source and not _l.monitorable,
			"on screen the next tick telegraphs at the player (state %s, target %s)" % [_name(_l.state), _kind(_l)])
	var held := 1
	var seen := Sensing.notice_rect(_play()).has_point(_l.global_position)
	var harmless := not _l.monitorable
	while _l.state == Lurker.State.TELEGRAPH and held < 300:
		await frames(1)
		if _l.state == Lurker.State.TELEGRAPH:
			held += 1
			harmless = harmless and not _l.monitorable
			seen = seen and Sensing.notice_rect(_play()).has_point(_l.global_position)
	check(held >= _floor_ticks() and harmless and seen and _l.state == Lurker.State.HUNT and _l.monitorable,
			"...a full telegraph, every tick of it inside the notice rect: %d ticks, at least Spec.TELEGRAPH_MIN (%d), then a harmful hunt" % [held, _floor_ticks()])
	await _free()


## The light went out (rows T1/H1, M1 D6): a freed hunted stand-in and a dead hunted player each send
## the lurker home on the first tick without them; a dead player's light is never noticed.
func test_light_out() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	var flare := _stand_in(Sensing.KIND_FLARE, 130.0, DECOY_AT)
	_l.force(Lurker.State.HUNT, flare)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.target == flare, "(premise) the lurker hunts the flare, the player noticed beside it")
	flare.queue_free()
	# Freed between ticks: still valid for this tick's callbacks, gone by the next (probed on 4.7.2).
	var waited := 0
	while is_instance_valid(flare) and waited < 5:
		await frames(1)
		waited += 1
	await frames(1)
	check(_l.state == Lurker.State.RETURN, "a freed hunted flare: the first tick without it is RETURN, not HUNT or TELEGRAPH (got %s)" % _name(_l.state))
	await _free()
	# The player's death.
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	_l.force(Lurker.State.HUNT, _p.light_source)
	await frames(1)
	check(_l.state == Lurker.State.HUNT and _l.monitorable, "(premise) the lurker hunts the player")
	_p.die()
	await frames(1)
	check(_l.state == Lurker.State.RETURN and not _l.monitorable, "a hunted player's die(): the next tick is RETURN, harmless (got %s)" % _name(_l.state))
	_l.force(Lurker.State.IDLE)
	_l.global_position = LURKER_AT
	_chain(CHAIN_MID)  # a dead player's chain is lost; relight it, so only extinguish() can keep the lurker asleep
	var ls := _p.light_source
	check(ls.is_inside_tree() and Sensing.can_notice(ls.global_position, ls.radius(), _l.global_position, _play()),
			"(premise) the dead player is still in the tree, its light %.1f px and the lurker on screen in its reach" % ls.radius())
	var asleep := true
	for i in 30:
		await frames(1)
		asleep = asleep and _l.state == Lurker.State.IDLE and not _l.notices(ls)
	check(asleep, "an IDLE lurker never notices a dead player's light over 30 ticks (extinguished, D5)")
	await _free()


# --- 4. Stirring (AC5; D3, D9) --------------------------------------------------------------------

func test_stirring() -> void:
	await _build()
	_chain(CHAIN_MAX)
	place(BELOW_40)
	var reach := _p.light_source.radius() * Spec.NOTICE_FACTOR
	var d := _l.global_position.distance_to(_p.global_position)
	check(not _play().has_point(_l.global_position) and is_equal_approx(_play().position.y - _l.global_position.y, 40.0) and d <= reach,
			"(premise) the lurker is 40 px above the play rect, %.0f px from a chain-%d light (reach %.0f px)" % [d, CHAIN_MAX, reach])
	await frames(1)
	check(_l.stirring and _l.stir == 1 and _l.state == Lurker.State.IDLE, "off screen in reach: IDLE, stirring, stir 1 on the first tick (half-open at once; got stir %d)" % _l.stir)
	var step := int(ceil(Spec.STIR_STEP * Engine.physics_ticks_per_second))
	var ones := 0
	while _l.stir == 1 and ones < 60:
		await frames(1)
		ones += 1
	check(_l.stir == 2 and ones == step, "...stir 2 after Spec.STIR_STEP %.2f s: %d ticks (got %d, stir %d)" % [Spec.STIR_STEP, step, ones, _l.stir])
	var calm := true
	for i in 120:
		await frames(1)
		calm = calm and _l.state == Lurker.State.IDLE and _l.stirring
	check(calm, "...and it stays IDLE and stirring over 2 s: it never telegraphs from off screen")
	# The 8 px band inside the play rect: on screen, outside the notice rect.
	place(BELOW_BAND)
	var band := _play().has_point(_l.global_position) and not Sensing.notice_rect(_play()).has_point(_l.global_position)
	var quiet := true
	for i in 30:
		await frames(1)
		quiet = quiet and _l.state == Lurker.State.IDLE and _l.stirring and not _l.notices(_p.light_source) and _l.stirs_for(_p.light_source)
	check(band and quiet, "in the margin band (on screen, outside the notice rect) it stirs and doesn't notice (D3; premise %s)" % band)
	await _free()


## By the light: the condition flips every tick (a flare stand-in at 100 / 60 px beside the
## off-screen lurker); stir still changes at most Spec.FLASH_HZ_MAX times in any second.
func test_stir_pacing_light() -> void:
	await _build()
	_chain(0)
	place(BELOW_40)
	var flare := _stand_in(Sensing.KIND_FLARE, 100.0, LURKER_AT + Vector2(30, 0))
	var stirs: Array = []
	var flips: Array = []
	for i in 180:
		flare.fixed_radius = 100.0 if i % 2 == 0 else 60.0
		await frames(1)
		stirs.append(_l.stir)
		flips.append(_l.stirring)
		if _l.state != Lurker.State.IDLE:
			break
	var most := _max_changes_per_second(stirs)
	check(stirs.size() == 180 and flips.has(true) and flips.has(false) and most >= 2,
			"(premise) 3 s IDLE, stirring flipping every tick, stir moving (%d ticks, %d stir changes in the busiest second)" % [stirs.size(), most])
	check(most <= Spec.FLASH_HZ_MAX, "by the light: stir changes at most Spec.FLASH_HZ_MAX %d times in any 60 ticks (got %d)" % [Spec.FLASH_HZ_MAX, most])
	await _free()


## Across the edge: the lurker 1 px either side of the notice rect's top, the player bright, so it
## flips between noticing (TELEGRAPH) and stirring (RETURN). Two ticks a side: one flip per tick would
## only ever swap TELEGRAPH and RETURN, and a lurker stirs on a tick it starts in RETURN.
func test_stir_pacing_edge() -> void:
	await _build()
	_chain(CHAIN_MAX)
	place(BELOW_BAND)
	var edge := Sensing.notice_rect(_play()).position.y
	var stirs: Array = []
	var states := {}
	var stirred := false
	for i in 180:
		_l.global_position = Vector2(LURKER_AT.x, edge + (1.0 if i % 4 < 2 else -1.0))
		await frames(1)
		stirs.append(_l.stir)
		states[_l.state] = true
		stirred = stirred or _l.stirring
	var most := _max_changes_per_second(stirs)
	check(states.has(Lurker.State.TELEGRAPH) and stirred and most >= 2,
			"(premise) it flipped between TELEGRAPH and stirring (states %s, stir changes %d in the busiest second)" % [states.keys().map(_name), most])
	check(most <= Spec.FLASH_HZ_MAX, "across the edge: stir changes at most Spec.FLASH_HZ_MAX %d times in any 60 ticks (got %d)" % [Spec.FLASH_HZ_MAX, most])
	await _free()


## The guarantee (AR50, Pillar 2): from a stirring start, the view scrolls until the lurker is in the
## notice rect. Every HUNT is preceded by at least Spec.TELEGRAPH_MIN of TELEGRAPH, all of it inside
## the play rect; stirring ends with the telegraph and stir closes within two steps.
func test_stir_to_hunt() -> void:
	await _build()
	_chain(CHAIN_MAX)
	place(BELOW_40)
	await frames(30)
	check(_l.stirring and _l.stir == 2, "(premise) stirring, stir 2, before the scroll")
	var rows: Array = []  # [state, in play rect, stirring, stir]
	var y := BELOW_40.y
	for i in 400:
		if _l.state != Lurker.State.TELEGRAPH and rows.filter(func(r: Array) -> bool: return r[0] == Lurker.State.TELEGRAPH).is_empty():
			y -= 1.0
			place(Vector2(BELOW_40.x, y))
		await frames(1)
		rows.append([_l.state, _play().has_point(_l.global_position), _l.stirring, _l.stir])
		if _l.state == Lurker.State.HUNT:
			break
	var first_t := rows.map(func(r: Array) -> int: return r[0]).find(Lurker.State.TELEGRAPH)
	var hunt := rows.size() - 1
	check(first_t >= 0 and rows[hunt][0] == Lurker.State.HUNT, "the scroll brought it on screen: a telegraph at tick %d, then a hunt at tick %d" % [first_t, hunt])
	if first_t < 0 or rows[hunt][0] != Lurker.State.HUNT:
		await _free()
		return
	var tele := rows.slice(first_t, hunt)
	var all_tele := tele.all(func(r: Array) -> bool: return r[0] == Lurker.State.TELEGRAPH)
	check(all_tele and tele.size() >= _floor_ticks(), "the hunt came after %d ticks of TELEGRAPH, at least Spec.TELEGRAPH_MIN (%d)" % [tele.size(), _floor_ticks()])
	check(tele.all(func(r: Array) -> bool: return r[1]), "...the lurker inside play_rect() on every tick of it (Q1: the warning is seen)")
	check(tele.all(func(r: Array) -> bool: return not r[2]), "...stirring false from the first TELEGRAPH tick")
	var step := int(ceil(Spec.STIR_STEP * Engine.physics_ticks_per_second))
	var closed := -1
	for i in range(first_t, rows.size()):
		if rows[i][3] == 0:
			closed = i - first_t
			break
	check(closed >= 0 and closed <= 2 * step, "...and stir reached 0 within two steps (%d ticks after the first TELEGRAPH tick, at most %d)" % [closed, 2 * step])
	await _free()


# --- 5. Q1, Q2, no World --------------------------------------------------------------------------

## Q1 (sonlm, (b)): a hunt keeps sensing off screen; a telegraph doesn't.
func test_q1_off_screen() -> void:
	await _build()
	_chain(CHAIN_MAX)
	place(BELOW_40)
	_l.force(Lurker.State.HUNT, _p.light_source)
	var off := true
	for i in 18:
		await frames(1)
		off = off and not _play().has_point(_l.global_position)
	check(off and _l.state == Lurker.State.HUNT and _l.monitorable,
			"a HUNT lurker outside the play rect, its target sensed: still HUNT and monitorable after 0.3 s (off screen throughout %s)" % off)
	await _free()
	await _build()
	_chain(CHAIN_MAX)
	place(Vector2(BELOW_40.x, 300))
	_l.force(Lurker.State.TELEGRAPH, _p.light_source)
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH, "(premise) a TELEGRAPH lurker in the notice rect")
	place(BELOW_40)
	await frames(1)
	check(_l.state == Lurker.State.IDLE or _l.state == Lurker.State.RETURN,
			"a TELEGRAPH lurker that leaves the notice rect drops to IDLE or RETURN on that tick (got %s)" % _name(_l.state))
	await _free()


## Q2 (sonlm, (a), M1 as built): re-brighten inside the 0.6 s wait and the hunt resumes, no telegraph.
func test_q2_resense() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	_l.force(Lurker.State.HUNT, _p.light_source)
	await frames(1)
	var hunted := _l.state == Lurker.State.HUNT and _l.monitorable
	_p.chain.break_chain()
	var waiting := true
	for i in 18:
		await frames(1)
		waiting = waiting and _l.state == Lurker.State.HUNT and not _l.monitorable
	_chain(CHAIN_MID)
	await frames(1)
	check(hunted and waiting and _l.state == Lurker.State.HUNT and _l.monitorable,
			"a light under 80 px for 0.3 s, then back: HUNT and monitorable again on the next tick, harmless and still HUNT through the wait (premise hunted %s, waiting %s)" % [hunted, waiting])
	await _free()


## AR20's fallback: no `world` node means no screen, so nothing is noticed.
func test_no_world() -> void:
	await _build()
	_chain(CHAIN_MID)
	place(BESIDE)
	_h.world.remove_from_group(&"world")
	var asleep := true
	for i in 30:
		await frames(1)
		asleep = asleep and _l.state == Lurker.State.IDLE and not _l.notices(_p.light_source)
	check(asleep, "with no node in group world, a lurker never notices a bright light beside it (30 ticks)")
	_h.world.add_to_group(&"world")
	await frames(1)
	check(_l.state == Lurker.State.TELEGRAPH, "control: the stub back in group world, the same light is noticed at once (got %s)" % _name(_l.state))
	await _free()
