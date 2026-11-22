extends Node
## Sensing (Story 1.20, AR29, FR17–FR20): the radius floor, the reach, the notice rect, stir and
## target choice. Pure: no scene. Expected values come from Spec (the GDD's numbers), never from
## Sensing's own consts; the screen margin is the one value with no GDD line (D3), so it is read from
## Sensing after checking it can only shrink the notice region.
## Samples are axis-aligned and exact in float32 (Vector2 is 32-bit), so "inclusive at 160 px" tests
## the rule, not rounding.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_sensing.gd

const Spec := preload("res://tests/spec.gd")
## A play rect away from the origin, the 360 × 270 view between the gutters (UX DESIGN.md), written
## out so the edges below are plain numbers.
const PLAY := Rect2(60, 1000, 360, 270)
## A light that is noticed wherever it stands: over the floor, at distance 0 from the predator.
const BRIGHT := 100.0

var _fail := 0


func run() -> void:
	_test_consts()
	_test_floor()
	_test_reach()
	_test_notice_rect()
	_test_stir()
	_test_pick_target()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_consts() -> void:
	# Exact: the GDD gives exact values (Lurker: "≥ 80 px", "radius × 1.6", "within 96 px").
	check(Sensing.NOTICE_MIN_RADIUS == Spec.NOTICE_MIN_RADIUS, "NOTICE_MIN_RADIUS is the GDD's %.1f px (got %.1f)" % [Spec.NOTICE_MIN_RADIUS, Sensing.NOTICE_MIN_RADIUS])
	check(Sensing.NOTICE_FACTOR == Spec.NOTICE_FACTOR, "NOTICE_FACTOR is the GDD's × %.1f (got %.2f)" % [Spec.NOTICE_FACTOR, Sensing.NOTICE_FACTOR])
	check(Sensing.STIR_REACH == Spec.STIR_REACH, "STIR_REACH is the GDD's %.0f px (got %.1f)" % [Spec.STIR_REACH, Sensing.STIR_REACH])
	check(Sensing.SCREEN_MARGIN >= 0.0, "the screen margin is never negative: it may only shrink where a predator notices (D3; got %.1f)" % Sensing.SCREEN_MARGIN)
	check(PLAY.encloses(Sensing.notice_rect(PLAY)), "the notice rect %s lies inside the play rect %s (D3)" % [Sensing.notice_rect(PLAY), PLAY])
	check(Sensing.KINDS.size() == 3 and Sensing.KIND_PLAYER in Sensing.KINDS and Sensing.KIND_FLARE in Sensing.KINDS and Sensing.KIND_CACHE in Sensing.KINDS,
			"the kinds are player, flare and cache (got %s)" % [Sensing.KINDS])


func _test_floor() -> void:
	var p := Vector2(200, 1100)
	check(not Sensing.can_sense(p, Spec.NOTICE_MIN_RADIUS - 0.1, p), "a %.1f px light is never sensed, even at distance 0" % (Spec.NOTICE_MIN_RADIUS - 0.1))
	check(Sensing.can_sense(p, Spec.NOTICE_MIN_RADIUS, p), "a %.0f px light is sensed at distance 0 (the floor is inclusive)" % Spec.NOTICE_MIN_RADIUS)
	check(not Sensing.can_notice(p, Spec.NOTICE_MIN_RADIUS - 0.1, p, PLAY), "a %.1f px light is never noticed, even point-blank on screen" % (Spec.NOTICE_MIN_RADIUS - 0.1))


func _test_reach() -> void:
	var light := Vector2(200, 1100)
	var r := 100.0
	var limit := r * Spec.NOTICE_FACTOR  # 160 px, exact
	for d: float in [limit - 1.0, limit, limit + 1.0]:
		var want := d <= limit
		check(Sensing.can_sense(light, r, light + Vector2(d, 0)) == want,
				"a %.0f px light senses at %.0f px: %s (the reach is %.0f px, inclusive)" % [r, d, want, limit])
	check(Sensing.can_sense(light, r, light + Vector2(0, -limit)), "the reach is the same straight up (%.0f px)" % limit)


## The notice rect on each edge: 0.5 px inside notices, 0.5 px outside does not. The exact edge
## documents Rect2.has_point()'s half-open rule on 4.7.2: left and top count, right and bottom do not.
func _test_notice_rect() -> void:
	var m := Sensing.SCREEN_MARGIN
	var left := PLAY.position.x + m
	var right := PLAY.end.x - m
	var top := PLAY.position.y + m
	var bottom := PLAY.end.y - m
	var mid := PLAY.get_center()
	check(Sensing.notice_rect(PLAY) == Rect2(left, top, right - left, bottom - top), "notice_rect() is the play rect shrunk by the margin on every side")
	var samples := [
		["left, 0.5 px inside", Vector2(left + 0.5, mid.y), true], ["left, 0.5 px outside", Vector2(left - 0.5, mid.y), false],
		["right, 0.5 px inside", Vector2(right - 0.5, mid.y), true], ["right, 0.5 px outside", Vector2(right + 0.5, mid.y), false],
		["top, 0.5 px inside", Vector2(mid.x, top + 0.5), true], ["top, 0.5 px outside", Vector2(mid.x, top - 0.5), false],
		["bottom, 0.5 px inside", Vector2(mid.x, bottom - 0.5), true], ["bottom, 0.5 px outside", Vector2(mid.x, bottom + 0.5), false],
		["exactly on the left edge (counts)", Vector2(left, mid.y), true], ["exactly on the right edge (does not)", Vector2(right, mid.y), false],
		["exactly on the top edge (counts)", Vector2(mid.x, top), true], ["exactly on the bottom edge (does not)", Vector2(mid.x, bottom), false],
	]
	for s: Array in samples:
		var pos: Vector2 = s[1]
		check(Sensing.can_notice(pos, BRIGHT, pos, PLAY) == s[2], "notice rect, %s: notices %s" % [s[0], s[2]])


## Stir: sensed, outside the notice rect, within Spec.STIR_REACH of the play rect.
func _test_stir() -> void:
	var m := Sensing.SCREEN_MARGIN
	var mid := PLAY.get_center()
	var top := PLAY.position.y
	var inside := Vector2(mid.x, top + m + 0.5)
	check(Sensing.can_notice(inside, BRIGHT, inside, PLAY) and not Sensing.can_stir(inside, BRIGHT, inside, PLAY),
			"0.5 px inside the notice rect: notices and does not stir")
	var band := Vector2(mid.x, top + m - 0.5)
	check(not Sensing.can_notice(band, BRIGHT, band, PLAY) and Sensing.can_stir(band, BRIGHT, band, PLAY),
			"0.5 px outside the notice rect (on screen, in the margin band): stirs and does not notice (D3: no silent gap)")
	var just_out := Vector2(mid.x, top - 0.5)
	check(Sensing.can_stir(just_out, BRIGHT, just_out, PLAY), "0.5 px outside the play rect: stirs")
	var near := Vector2(mid.x, top - (Spec.STIR_REACH - 0.5))
	check(Sensing.can_stir(near, BRIGHT, near, PLAY), "%.1f px outside the play rect: stirs" % (Spec.STIR_REACH - 0.5))
	var far := Vector2(mid.x, top - (Spec.STIR_REACH + 0.5))
	check(not Sensing.can_stir(far, BRIGHT, far, PLAY), "%.1f px outside the play rect: does not stir" % (Spec.STIR_REACH + 0.5))
	var below := Vector2(mid.x, PLAY.end.y + Spec.STIR_REACH - 0.5)
	check(Sensing.can_stir(below, BRIGHT, below, PLAY), "%.1f px below the play rect: stirs (every side)" % (Spec.STIR_REACH - 0.5))
	var side := Vector2(PLAY.end.x + Spec.STIR_REACH - 0.5, mid.y)
	check(Sensing.can_stir(side, BRIGHT, side, PLAY), "%.1f px right of the play rect: stirs (every side)" % (Spec.STIR_REACH - 0.5))
	check(not Sensing.can_stir(just_out, Spec.NOTICE_MIN_RADIUS - 0.1, just_out, PLAY), "a %.1f px light never stirs" % (Spec.NOTICE_MIN_RADIUS - 0.1))
	# Out of reach: stir needs the sense rule too, not only the region.
	var light := just_out + Vector2(0, BRIGHT * Spec.NOTICE_FACTOR + 1.0)
	check(not Sensing.can_stir(light, BRIGHT, just_out, PLAY), "a light out of reach never stirs, even in the stir region")


func _entry(kind: StringName, radius: float) -> Dictionary:
	return {kind = kind, radius = radius, pos = Vector2.ZERO}


func _test_pick_target() -> void:
	var none: Array[Dictionary] = []
	check(Sensing.pick_target(none) == -1, "pick_target: no lights -> -1")
	var one: Array[Dictionary] = [_entry(Sensing.KIND_PLAYER, 90.0)]
	check(Sensing.pick_target(one) == 0, "pick_target: one light -> 0")
	var big: Array[Dictionary] = [_entry(Sensing.KIND_FLARE, 100.0), _entry(Sensing.KIND_PLAYER, 120.0), _entry(Sensing.KIND_CACHE, 90.0)]
	check(Sensing.pick_target(big) == 1, "pick_target: the largest radius wins, whatever its kind (got %d)" % Sensing.pick_target(big))
	var pf: Array[Dictionary] = [_entry(Sensing.KIND_PLAYER, 110.0), _entry(Sensing.KIND_FLARE, 110.0)]
	check(Sensing.pick_target(pf) == 1, "pick_target: a player/flare tie goes to the flare (got %d)" % Sensing.pick_target(pf))
	var fp: Array[Dictionary] = [_entry(Sensing.KIND_FLARE, 110.0), _entry(Sensing.KIND_PLAYER, 110.0)]
	check(Sensing.pick_target(fp) == 0, "pick_target: the flare wins the tie in either order (got %d)" % Sensing.pick_target(fp))
	var pc: Array[Dictionary] = [_entry(Sensing.KIND_PLAYER, 110.0), _entry(Sensing.KIND_CACHE, 110.0)]
	check(Sensing.pick_target(pc) == 1, "pick_target: a player/cache tie goes to the cache (got %d)" % Sensing.pick_target(pc))
	var fc: Array[Dictionary] = [_entry(Sensing.KIND_FLARE, 110.0), _entry(Sensing.KIND_CACHE, 110.0)]
	check(Sensing.pick_target(fc) == 0, "pick_target: a flare/cache tie keeps the earlier (got %d)" % Sensing.pick_target(fc))
	var cf: Array[Dictionary] = [_entry(Sensing.KIND_CACHE, 110.0), _entry(Sensing.KIND_FLARE, 110.0)]
	check(Sensing.pick_target(cf) == 0, "pick_target: a cache/flare tie keeps the earlier too (got %d)" % Sensing.pick_target(cf))
