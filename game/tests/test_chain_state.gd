extends SceneTree
## Headless test runner for the pure chain logic.
## Run: godot --headless --path game --script res://tests/test_chain_state.gd
## Exits 0 when every test passes and 1 otherwise.

const ChainStateScript := preload("res://scripts/rules/chain_state.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
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
	]:
		call(t)
	if _failures == 0:
		print("ALL PASS (%d checks)" % _checks)
		quit(0)
	else:
		printerr("%d FAILED of %d checks" % [_failures, _checks])
		quit(1)


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
