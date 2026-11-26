extends Node
## Headless test runner for the pure chain logic.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_chain_state.gd
## Exits 0 when every test passes and 1 otherwise.

const ChainStateScript := preload("res://scripts/rules/chain_state.gd")

var _failures: int = 0
var _checks: int = 0


func run() -> void:
	for t in [
		"test_hit_increments",
		"test_land_breaks",
		"test_snuff_breaks_and_dims",
		"test_snuff_at_zero",
		"test_snuffed_hits_add_nothing",
		"test_cap_clamps",
		"test_curves_monotonic",
		"test_changed_signal",
		"test_embers_held_banked_lost",
		"test_cling_pauses_and_hides",
		"test_break_by_hit_banks",
		"test_ended_only_above_zero",
		"test_lose_emits_no_ended",
		"test_snuff_ended_not_by_hit",
		"test_hit_while_clinging_banks",
		"test_flare_cost",
		"test_toss_links",
		"test_toss_refused",
		"test_toss_share",
		"test_toss_at_cap",
		"test_toss_signals",
		"test_toss_radius",
		"test_toss_snuffed",
		"test_toss_chain_goes_on",
	]:
		call(t)
	if _failures == 0:
		print("ALL PASS (%d checks)" % _checks)
	else:
		printerr("%d FAILED of %d checks" % [_failures, _checks])


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func test_hit_increments() -> void:
	var c = ChainStateScript.new()
	var r0: float = c.light_radius()
	var b0: float = c.bloom_scale()
	c.add_hit()
	check(c.count == 1, "pogo hit -> chain 1")
	check(c.light_radius() > r0, "pogo hit grows light")
	check(c.bloom_scale() > b0, "pogo hit grows bloom")


func test_land_breaks() -> void:
	var c = ChainStateScript.new()
	for i in 5:
		c.add_hit()
	c.break_chain()
	check(c.count == 0, "landing resets chain")
	check(is_equal_approx(c.light_radius(), ChainStateScript.BASE_RADIUS), "landing resets light")
	check(is_equal_approx(c.bloom_scale(), ChainStateScript.BASE_BLOOM), "landing resets bloom")


func test_snuff_breaks_and_dims() -> void:
	var c = ChainStateScript.new()
	for i in 4:
		c.add_hit()
	c.set_snuffed(true)
	check(c.count == 0, "snuff breaks chain")
	check(is_equal_approx(c.light_radius(), ChainStateScript.SNUFF_RADIUS), "snuff dims to minimum")
	c.set_snuffed(false)
	check(is_equal_approx(c.light_radius(), ChainStateScript.BASE_RADIUS), "release snuff -> base light")


func test_snuff_at_zero() -> void:
	var c = ChainStateScript.new()
	c.set_snuffed(true)
	check(c.count == 0, "snuff at 0 keeps 0")
	check(c.light_radius() < ChainStateScript.BASE_RADIUS, "snuff at 0 still dims")


func test_snuffed_hits_add_nothing() -> void:
	var c = ChainStateScript.new()
	c.set_snuffed(true)
	c.add_hit()
	check(c.count == 0, "pogo while snuffed adds no link")


func test_cap_clamps() -> void:
	var c = ChainStateScript.new()
	for i in ChainStateScript.MAX_CHAIN + 5:
		c.add_hit()
	check(c.count == ChainStateScript.MAX_CHAIN, "chain clamps at MAX_CHAIN")
	check(is_equal_approx(c.light_radius(), ChainStateScript.radius_for(ChainStateScript.MAX_CHAIN)), "radius clamps")
	check(is_equal_approx(ChainStateScript.radius_for(999), ChainStateScript.radius_for(ChainStateScript.MAX_CHAIN)), "radius_for clamps")
	check(is_equal_approx(ChainStateScript.bloom_for(999), ChainStateScript.bloom_for(ChainStateScript.MAX_CHAIN)), "bloom_for clamps")


func test_curves_monotonic() -> void:
	for n in ChainStateScript.MAX_CHAIN:
		check(ChainStateScript.radius_for(n + 1) > ChainStateScript.radius_for(n), "radius strictly grows at %d" % n)
		check(ChainStateScript.bloom_for(n + 1) > ChainStateScript.bloom_for(n), "bloom strictly grows at %d" % n)
	check(ChainStateScript.radius_for(-3) == ChainStateScript.radius_for(0), "negative links clamp to 0")


func test_changed_signal() -> void:
	var c = ChainStateScript.new()
	var seen: Array[int] = []
	c.changed.connect(func(n: int) -> void: seen.append(n))
	c.add_hit()
	c.add_hit()
	c.break_chain()
	c.break_chain()  # already 0: must not emit again
	check(seen == [1, 2, 0], "changed emits on real changes only (got %s)" % [seen])


## M1 reward: hits fill a held pile; a safe break banks it (once); death loses it.
func test_embers_held_banked_lost() -> void:
	var c = ChainStateScript.new()
	var got := []
	c.banked.connect(func(a): got.append(a))
	for i in 4:
		c.add_hit()
	var expect := 0
	for n in range(1, 5):
		expect += ChainStateScript.ember_value(n)
	check(c.held == expect, "4 hits hold the sum of ember_value(1..4) (got %d)" % c.held)
	check(ChainStateScript.ember_value(5) >= ChainStateScript.ember_value(4), "a later hit is worth at least as much")
	c.break_chain()
	check(got == [expect] and c.held == 0, "landing banks the held embers exactly once")
	c.break_chain()
	check(got.size() == 1, "breaking an empty chain banks nothing")
	c.add_hit(); c.add_hit()
	c.set_snuffed(true)
	check(got.size() == 2 and c.held == 0, "Snuff is a safe exit: it banks too")
	c.set_snuffed(false)
	c.add_hit(); c.add_hit(); c.add_hit()
	var held_before: int = c.held
	var lost: int = c.lose()
	check(lost == held_before and lost > 0 and c.held == 0 and c.count == 0, "death loses the held embers")
	check(got.size() == 2, "death banks nothing")
	c.count = ChainStateScript.MAX_CHAIN
	var h0: int = c.held
	c.add_hit()
	check(c.held > h0, "hits at the chain cap still pay embers")


## Wall cling: the chain and held embers survive, but the light drops to base (lurkers lose you).
func test_cling_pauses_and_hides() -> void:
	var c = ChainStateScript.new()
	for i in 6:
		c.add_hit()
	var held: int = c.held
	c.set_clinging(true)
	check(c.count == 6 and c.held == held, "clinging keeps the chain and the held embers")
	check(is_equal_approx(c.light_radius(), ChainStateScript.BASE_RADIUS), "clinging drops the light to base")
	c.set_clinging(false)
	check(is_equal_approx(c.light_radius(), ChainStateScript.radius_for(6)), "letting go restores the chain-light")


## Story 1.19 (FR11, D4): any hit banks the held embers and resets the count, like a landing, but
## `ended` says it was a hit: banked first, then ended(n, true).
func test_break_by_hit_banks() -> void:
	var c = ChainStateScript.new()
	var seen := []
	c.banked.connect(func(a: int) -> void: seen.append(["banked", a]))
	c.ended.connect(func(n: int, by_hit: bool) -> void: seen.append(["ended", n, by_hit]))
	for i in 3:
		c.add_hit()
	var held: int = c.held
	c.break_by_hit()
	check(c.count == 0 and c.held == 0, "a hit resets the count and empties the held pile")
	check(seen == [["banked", held], ["ended", 3, true]], "a hit banks the held embers, then emits ended(3, true) (got %s)" % [seen])
	seen.clear()
	for i in 2:
		c.add_hit()
	c.break_chain()
	check(seen.size() == 2 and seen[1] == ["ended", 2, false], "a landing emits ended(2, false) (got %s)" % [seen])


## break_chain() runs on every floor tick: `ended` only when there was a chain to end.
func test_ended_only_above_zero() -> void:
	var c = ChainStateScript.new()
	var ends := []
	c.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	c.break_chain()
	c.break_by_hit()
	check(ends.is_empty(), "no ended at count 0, for a landing or a hit (got %s)" % [ends])


## A death loses the held embers and is no end: nothing can bank-heal from it.
func test_lose_emits_no_ended() -> void:
	var c = ChainStateScript.new()
	var ends := []
	c.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	for i in 12:
		c.add_hit()
	c.lose()
	check(ends.is_empty(), "lose() emits no ended (got %s)" % [ends])


func test_snuff_ended_not_by_hit() -> void:
	var c = ChainStateScript.new()
	var ends := []
	c.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	for i in 5:
		c.add_hit()
	c.set_snuffed(true)
	check(ends == [[5, false]], "a Snuff ends the chain safely: ended(5, false) (got %s)" % [ends])


## A cling pauses the chain (count and held kept); a hit there still banks the held embers.
func test_hit_while_clinging_banks() -> void:
	var c = ChainStateScript.new()
	var got := []
	c.banked.connect(func(a: int) -> void: got.append(a))
	for i in 4:
		c.add_hit()
	var held: int = c.held
	c.set_clinging(true)
	c.break_by_hit()
	check(got == [held] and c.held == 0 and c.count == 0, "a hit while clinging banks the %d held embers and resets the count (got %s)" % [held, got])


# --- Flare Toss (Story 1.23, FR14) ---------------------------------------------------------------

## A chain of `links` hits with its signals recorded in `seen` (in order).
func _chain_of(links: int, seen: Array) -> Object:
	var c = ChainStateScript.new()
	for i in links:
		c.add_hit()
	c.banked.connect(func(a: int) -> void: seen.append(["banked", a]))
	c.changed.connect(func(n: int) -> void: seen.append(["changed", n]))
	c.ended.connect(func(n: int, by_hit: bool) -> void: seen.append(["ended", n, by_hit]))
	return c


## The links a toss spends, 0-20, against a literal list (half, rounded up; nothing under 2).
func test_flare_cost() -> void:
	var want := [0, 0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10]
	var got := []
	for n in want.size():
		got.append(ChainStateScript.flare_cost(n))
	check(got == want, "flare_cost(0..20) is half the links rounded up, 0 under 2 (got %s)" % [got])
	check(ChainStateScript.flare_cost(-3) == 0, "flare_cost() of a negative count is 0")
	check(ChainStateScript.FLARE_MIN_LINKS == 2, "a toss needs 2 links (GDD Flare Toss; got %d)" % ChainStateScript.FLARE_MIN_LINKS)


## The GDD's examples by literal, then the small and the capped chain. A toss never ends a chain.
func test_toss_links() -> void:
	for pair: Array in [[8, 4], [5, 2], [2, 1], [3, 1], [20, 10]]:
		var c = _chain_of(pair[0], [])
		var r: float = c.toss_flare()
		check(c.count == pair[1] and r > 0.0, "a toss at chain %d leaves %d (got %d, radius %.1f)" % [pair[0], pair[1], c.count, r])
		check(c.count >= 1, "...and never ends the chain (count %d)" % c.count)


## Under 2 links: 0.0, no signal, count and held untouched.
func test_toss_refused() -> void:
	for links in [0, 1]:
		var seen := []
		var c = _chain_of(links, seen)
		var held: int = c.held
		var r: float = c.toss_flare()
		check(r == 0.0 and seen.is_empty() and c.count == links and c.held == held,
				"a toss at chain %d is refused: 0.0, no signal, count and held untouched (got %.1f, %s, count %d, held %d)" % [links, r, seen, c.count, c.held])


## The share of the held embers that banks: held x spent / count, floored; the rest stays held.
func test_toss_share() -> void:
	for row: Array in [[8, 36, 18, 18], [5, 15, 9, 6], [3, 6, 4, 2]]:
		var seen := []
		var c = _chain_of(row[0], seen)
		check(c.held == row[1], "(premise) a chain of %d holds %d embers (got %d)" % [row[0], row[1], c.held])
		c.toss_flare()
		var banked: int = seen[0][1] if not seen.is_empty() and seen[0][0] == "banked" else -1
		check(banked == row[2] and c.held == row[3], "a toss at chain %d with %d held banks %d and keeps %d (got %d, %d)" % [row[0], row[1], row[2], row[3], banked, c.held])
		check(banked + c.held == row[1], "...banked + held after is the held before (%d + %d = %d)" % [banked, c.held, row[1]])


## At the cap, the hits past it still paid: 25 hits hold 310 at count 20.
func test_toss_at_cap() -> void:
	var seen := []
	var c = _chain_of(25, seen)
	check(c.count == 20 and c.held == 310, "(premise) 25 hits: count 20, held 310 (got %d, %d)" % [c.count, c.held])
	c.toss_flare()
	check(seen == [["banked", 155], ["changed", 10]] and c.count == 10 and c.held == 155, "a toss there banks 155 and leaves count 10, held 155 (got %s, %d, %d)" % [seen, c.count, c.held])


## One `banked` with the share, then exactly one `changed` with the new count, and never `ended`:
## a toss is a partial bank, so nothing that hangs on a chain's end (the bank-heal) can fire.
func test_toss_signals() -> void:
	var seen := []
	var c = _chain_of(12, seen)
	c.toss_flare()
	check(seen == [["banked", 39], ["changed", 6]], "a toss at chain 12 emits banked(39), then changed(6), and no ended (got %s)" % [seen])
	# Every field before any signal (review of 1.22): a listener reads the new count and held.
	var at_banked := []
	var d = ChainStateScript.new()
	for i in 8:
		d.add_hit()
	var weak: WeakRef = weakref(d)  # the lambda must not hold `d`: a chain that owns its own listener never frees
	d.banked.connect(func(_a: int) -> void: at_banked.append([weak.get_ref().count, weak.get_ref().held]))
	d.toss_flare()
	check(at_banked == [[4, 18]], "...and both fields are set before banked fires (a listener saw count, held %s)" % [at_banked])
	# Through the public API the share is always >= 1 (held >= count from the first hit), so the
	# `share > 0` guard is reached by emptying the held pile on this test's own ChainState.
	seen.clear()
	var e = _chain_of(4, seen)
	e.held = 0
	var r: float = e.toss_flare()
	check(r > 0.0 and seen == [["changed", 2]] and e.held == 0, "with nothing held a toss still spends the links: no banked, one changed(2) (got %s)" % [seen])


## The flare burns at the chain's own light before the toss, on and off a wall (D3); after it the
## player's light and Blade Bloom follow the new count.
func test_toss_radius() -> void:
	var c = _chain_of(8, [])
	var r: float = c.toss_flare()
	check(is_equal_approx(r, ChainStateScript.radius_for(8)) and absf(r - 102.2) < 0.05, "a toss at chain 8 returns radius_for(8), 102.2 px (got %.2f)" % r)
	check(is_equal_approx(c.light_radius(), ChainStateScript.radius_for(4)) and is_equal_approx(c.bloom_scale(), ChainStateScript.bloom_for(4)),
			"...and light_radius() and bloom_scale() follow the new count, 4 (got %.1f, %.3f)" % [c.light_radius(), c.bloom_scale()])
	var w = _chain_of(8, [])
	w.set_clinging(true)
	check(is_equal_approx(w.light_radius(), ChainStateScript.BASE_RADIUS), "(premise) clinging, light_radius() is the base 40 px")
	r = w.toss_flare()
	check(is_equal_approx(r, ChainStateScript.radius_for(8)), "a toss from a cling still returns radius_for(8): the cling shields the light, it doesn't shrink the chain (got %.2f)" % r)
	check(w.count == 4 and w.clinging and is_equal_approx(w.light_radius(), ChainStateScript.BASE_RADIUS), "...the count halves, and the cling and its 40 px light go on")


## A Snuff breaks the chain and a snuffed hit adds no link, so a snuffed toss is always refused (D4).
func test_toss_snuffed() -> void:
	var seen := []
	var c = _chain_of(6, [])
	c.set_snuffed(true)
	c.add_hit()
	c.add_hit()
	c.banked.connect(func(a: int) -> void: seen.append(a))
	var r: float = c.toss_flare()
	check(r == 0.0 and c.count == 0 and seen.is_empty(), "snuffed, a toss is refused: 0.0, count 0, nothing banked (got %.1f, %d, %s)" % [r, c.count, seen])


## The chain goes on: the next hit pays ember_value(count + 1) on top of the held that stayed.
func test_toss_chain_goes_on() -> void:
	var c = _chain_of(8, [])
	c.toss_flare()
	var held: int = c.held
	c.add_hit()
	check(c.count == 5 and c.held == held + ChainStateScript.ember_value(5), "after a toss at 8, the next hit makes link 5 and pays ember_value(5) on top of the %d kept (got count %d, held %d)" % [held, c.count, c.held])
	# The rest banks as a chain of its own length: its end is a real end.
	var ends := []
	c.ended.connect(func(n: int, by_hit: bool) -> void: ends.append([n, by_hit]))
	c.break_chain()
	check(ends == [[5, false]] and c.held == 0, "...and a landing then ends a chain of 5: ended(5, false) (got %s)" % [ends])
