extends Node
## Health (Story 1.19, FR10/FR12): the damage table, the cause registry, invulnerability, heals and
## the bank-heal threshold. Pure: a fresh Health per case. Expected values come from Spec (the GDD's
## numbers), never from Health's own consts.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_health.gd
## Not tested here, because a failed assert aborts the test: an unknown cause (a programmer error).

const Spec := preload("res://tests/spec.gd")
const INVULN := Spec.INVULN_S

var _fail := 0


func run() -> void:
	_test_table()
	_test_causes()
	_test_start()
	_test_hit_signals()
	_test_overkill()
	_test_invulnerability()
	_test_empty_refuses()
	_test_heal()
	_test_bank_heal()
	_test_reset()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Records every signal a Health emits, in order: ["damaged", amount, cause] / ["changed", hp].
func _record(h: Health) -> Array:
	var events := []
	h.damaged.connect(func(amount: int, cause: StringName) -> void: events.append(["damaged", amount, cause]))
	h.changed.connect(func(hp: int) -> void: events.append(["changed", hp]))
	return events


## Each cause's GDD row is written out here (GDD Combat enemy table: walkers and hoverers deal the
## crawler row on contact; GDD Health and damage: a lurker, a hazard). Never read from Health.CAUSES:
## a mapping swapped in the registry must fail here (review of Story 1.19).
func _cause_rows() -> Dictionary:
	return {&"crawler_walker": &"crawler", &"crawler_hoverer": &"crawler", &"lurker": &"lurker", &"spikes": &"hazard"}


func _test_table() -> void:
	check(Health.DAMAGE == Spec.DAMAGE, "the damage table is the GDD's: %s (got %s)" % [Spec.DAMAGE, Health.DAMAGE])
	# hurt() reads a hit that lost 0 HP as refused, after hit() has started the invulnerability.
	for row: StringName in Health.DAMAGE:
		check(int(Health.DAMAGE[row]) >= 1, "damage row %s costs at least 1 HP (got %s)" % [row, Health.DAMAGE[row]])
	var rows := _cause_rows()
	for cause: StringName in Health.CAUSES:
		check(rows.has(cause), "cause %s has its GDD row written out in this test" % cause)
	for cause: StringName in rows:
		var row: StringName = rows[cause]
		var h := Health.new()
		var lost := h.hit(cause, INVULN)
		var want: int = Spec.DAMAGE.get(row, -1)
		check(lost == want and h.hp == Spec.MAX_HP - want, "cause %s hits for the GDD's %s row: %d HP (got %d, hp %d)" % [cause, row, want, lost, h.hp])


func _test_causes() -> void:
	var snake := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for cause: StringName in Health.CAUSES:
		check(Health.DAMAGE.has(Health.CAUSES[cause]), "cause %s maps onto a damage row (%s)" % [cause, Health.CAUSES[cause]])
		check(snake.search(String(cause)) != null, "cause id %s is lower snake case (save data from 1.29)" % cause)
	# The E1 causes the epics and the death card name (Story 1.28): one per source in play today.
	for cause: StringName in [&"crawler_walker", &"crawler_hoverer", &"lurker", &"spikes"]:
		check(Health.CAUSES.has(cause), "the registry has %s" % cause)


func _test_start() -> void:
	var h := Health.new()
	check(h.hp == Spec.MAX_HP and Health.MAX == Spec.MAX_HP, "a fresh Health starts at Spec.MAX_HP, %d (got %d, MAX %d)" % [Spec.MAX_HP, h.hp, Health.MAX])
	check(not h.invulnerable() and not h.is_empty() and h.invuln == 0.0, "...not invulnerable, not empty")


func _test_hit_signals() -> void:
	var h := Health.new()
	var events := _record(h)
	var lost := h.hit(&"crawler_walker", INVULN)
	check(lost == 1 and events == [["damaged", 1, &"crawler_walker"], ["changed", Spec.MAX_HP - 1]],
			"a hit emits damaged(amount, cause), then changed(hp) (got %s)" % [events])
	check(h.invulnerable() and is_equal_approx(h.invuln, INVULN), "...and starts the invulnerability it was given (%s s; got %s)" % [INVULN, h.invuln])


func _test_overkill() -> void:
	var h := Health.new()
	h.reset(1)
	var events := _record(h)
	var lost := h.hit(&"lurker", INVULN)
	check(lost == 1 and h.hp == 0 and events == [["damaged", 1, &"lurker"], ["changed", 0]],
			"a lurker (%d) at 1 HP loses the 1 HP left: damaged(1, lurker), not 2 (got %d, %s)" % [Spec.DAMAGE[&"lurker"], lost, events])
	check(h.is_empty(), "...and HP is empty")


func _test_invulnerability() -> void:
	var h := Health.new()
	h.hit(&"crawler_walker", INVULN)
	var events := _record(h)
	check(h.hit(&"lurker", INVULN) == 0 and events.is_empty() and h.hp == Spec.MAX_HP - 1,
			"a second hit inside the invulnerability is refused: returns 0, emits nothing (got %s, hp %d)" % [events, h.hp])
	h.tick(INVULN - 0.1)
	check(h.invulnerable() and h.hit(&"crawler_walker", INVULN) == 0, "...still refused 0.1 s before it ends")
	h.tick(0.1)
	check(not h.invulnerable() and h.invuln == 0.0, "tick() past it ends the invulnerability (invuln %s)" % h.invuln)
	check(h.hit(&"crawler_walker", INVULN) == 1 and events.size() == 2, "...and the next hit lands (events %s)" % [events])
	h.tick(10.0)
	check(h.invuln == 0.0, "tick() never takes invulnerability below 0")


func _test_empty_refuses() -> void:
	var h := Health.new()
	h.reset(1)
	h.hit(&"crawler_walker", INVULN)
	h.tick(INVULN)
	var events := _record(h)
	check(h.is_empty() and h.hit(&"crawler_walker", INVULN) == 0 and events.is_empty() and h.hp == 0,
			"a hit at 0 HP is refused: returns 0, emits nothing (got %s)" % [events])


func _test_heal() -> void:
	var h := Health.new()
	var events := _record(h)
	h.heal(1)
	check(events.is_empty() and h.hp == Spec.MAX_HP, "heal() at MAX emits nothing and stays at %d (got %s)" % [Spec.MAX_HP, events])
	h.reset(1)
	events.clear()
	h.heal(10)
	check(h.hp == Spec.MAX_HP and events == [["changed", Spec.MAX_HP]], "heal() clamps at MAX and emits changed once (got %d, %s)" % [h.hp, events])
	# heal() never lowers HP: a negative heal left a live player at 0 HP that hit() refused forever.
	for n: int in [-1, -10, 0]:
		h.reset(2)
		events.clear()
		h.heal(n)
		check(h.hp == 2 and events.is_empty(), "heal(%d) does nothing: HP stays 2 and nothing is emitted (got %d, %s)" % [n, h.hp, events])


## FR12: firing sample at the threshold, near-miss one below it, and never past MAX.
func _test_bank_heal() -> void:
	var h := Health.new()
	h.reset(2)
	var events := _record(h)
	check(not h.bank_heal(Spec.BANK_HEAL_MIN - 1, Spec.BANK_HEAL_MIN) and h.hp == 2 and events.is_empty(),
			"a banked chain of %d (one below Spec.BANK_HEAL_MIN) heals nothing (hp %d)" % [Spec.BANK_HEAL_MIN - 1, h.hp])
	check(h.bank_heal(Spec.BANK_HEAL_MIN, Spec.BANK_HEAL_MIN) and h.hp == 3 and events == [["changed", 3]],
			"a banked chain of %d heals 1 HP (hp %d, %s)" % [Spec.BANK_HEAL_MIN, h.hp, events])
	check(h.bank_heal(20, Spec.BANK_HEAL_MIN) and h.hp == 4, "a longer one heals 1 too, never more (hp %d)" % h.hp)
	events.clear()
	check(not h.bank_heal(20, Spec.BANK_HEAL_MIN) and h.hp == Spec.MAX_HP and events.is_empty(), "...and at MAX it heals nothing and emits nothing")


func _test_reset() -> void:
	var h := Health.new()
	h.hit(&"lurker", INVULN)
	var events := _record(h)
	h.reset(3)
	check(h.hp == 3 and not h.invulnerable() and events == [["changed", 3]], "reset(3): 3 HP, no invulnerability, changed emitted (got %d, %s, %s)" % [h.hp, h.invuln, events])
	h.reset(0)
	check(h.hp == 1, "reset(0) clamps to 1 (got %d)" % h.hp)
	h.reset(99)
	check(h.hp == Spec.MAX_HP, "reset(99) clamps to MAX (got %d)" % h.hp)
	h.reset()
	check(h.hp == Spec.MAX_HP, "reset() is full HP (got %d)" % h.hp)
