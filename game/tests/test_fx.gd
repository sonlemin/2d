extends Node

const Spec := preload("res://tests/spec.gd")
const TICK := 1.0 / 60.0  ## physics ticks/s: what a player sees, one frame per tick
## Probed on 4.7.2 (Story 1.16 D10): RendererCanvasCull::_cull_canvas_item skips an item whose
## combined modulate alpha is < 0.007, so a warm-up drawn below it draws nothing.
const CANVAS_CULL_ALPHA := 0.007
## Public static functions on Fx that are not effects: the materials, the gate readers, warm-up.
const NOT_EFFECTS := ["unshaded", "additive", "reduce_flashing", "shake_on", "reduced_motion", "warm_up"]
## Fx's shared materials (AR46, Story 1.12 D6): each one built once and reused, never one per effect,
## and the code-built effects free themselves. Story 1.16: the accessibility gate (AR57), the
## flash-rate table held to the cap (NFR8, UX-DR125), the reduced variants (UX-DR126/127) and
## warm-up at room load (D10). Thresholds come from Spec, never from Fx's own consts.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_fx.gd

var _fail := 0


func run() -> void:
	_test_materials()
	await _test_effects()
	_test_gate()
	_test_table()
	_test_reflection()
	_test_blink_sampled()
	_test_pulse_sampled()
	_test_pop_reduced()
	await _test_popup_motion()
	await _test_warm_up()
	Game.reset_for_tests()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_materials() -> void:
	var u := Fx.unshaded()
	check(u != null and u == Fx.unshaded(), "Fx.unshaded() returns the same instance twice")
	check(u != null and u.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and u.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX,
			"...unshaded, mixed: reads in the dark (light_mode %d, blend_mode %d)" % [u.light_mode, u.blend_mode])
	var a := Fx.additive()
	check(a != null and a == Fx.additive(), "Fx.additive() returns the same instance twice")
	check(a != null and a.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and a.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"...unshaded and additive: a sprite glow adds onto the dark (light_mode %d, blend_mode %d)" % [a.light_mode, a.blend_mode])
	check(u != a, "the two are different instances")


## pop() and popup() put one child under the parent they are given (the room, AR23), drawn with the
## shared unshaded material; the sparks free themselves once they finish.
func _test_effects() -> void:
	var parent := Node2D.new()
	add_child(parent)
	Fx.pop(parent, Vector2(10, 10))
	var sparks: Array[Node] = parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	check(sparks.size() == 1 and sparks[0].material == Fx.unshaded(), "pop() adds one CPUParticles2D with Fx.unshaded() (got %s)" % [parent.get_children()])
	Fx.popup(parent, Vector2(10, 10), "x5", Color.WHITE)
	var labels: Array[Node] = parent.get_children().filter(func(n: Node) -> bool: return n is Label)
	check(labels.size() == 1 and labels[0].material == Fx.unshaded(), "popup() adds one Label with Fx.unshaded() (got %s)" % [parent.get_children()])
	# Lifetime 0.35 s of game time (probed: freed after about 0.36 s). The timer runs on game time
	# too, so a time scale left by another test stretches both alike. A freed object compares equal
	# to null, so the premise is checked first.
	var found := sparks.size() == 1
	var p: Node = sparks[0] if found else null
	await get_tree().create_timer(0.6, true, false, false).timeout
	check(found and not is_instance_valid(p), "...and the sparks free themselves after their lifetime (AR46: code-built FX free themselves)")
	parent.queue_free()


## AR57, D1: the three readers follow Game.settings live, so a DevTools --set applies at once.
func _test_gate() -> void:
	Game.reset_for_tests()
	check(not Fx.reduce_flashing() and Fx.shake_on() and not Fx.reduced_motion(), "the gate at the defaults: reduce flashing off, shake on, reduced motion off (D2)")
	Game.settings.set_value(&"reduce_flashing", true)
	Game.settings.set_value(&"shake", false)
	Game.settings.set_value(&"reduced_motion", true)
	check(Fx.reduce_flashing() and not Fx.shake_on() and Fx.reduced_motion(), "...and each reader follows its setting at once")
	Game.reset_for_tests()
	check(not Fx.reduce_flashing() and Fx.shake_on() and not Fx.reduced_motion(), "...and back after a reset")


## NFR8, UX-DR125: every declared effect is within the cap.
func _test_table() -> void:
	check(not Fx.EFFECTS.is_empty(), "Fx.EFFECTS declares the effects (%d rows)" % Fx.EFFECTS.size())
	for name: StringName in Fx.EFFECTS:
		var e: Dictionary = Fx.EFFECTS[name]
		var shape: bool = e.has("kind") and e.has("hz") and e.has("fn") and e.has("reduced") and e.kind in Fx.Kind.values()
		check(shape, "EFFECTS %s has kind, hz, fn and reduced (got %s)" % [name, e])
		if not shape:
			continue
		check(e.hz <= Spec.FLASH_HZ_MAX, "EFFECTS %s: %s Hz is within the %s flashes/s cap" % [name, e.hz, Spec.FLASH_HZ_MAX])
		match e.kind:
			Fx.Kind.BLINK:
				check(is_equal_approx(e.hz, Spec.BLINK_HZ), "EFFECTS %s: a blink is exactly %s Hz (got %s)" % [name, Spec.BLINK_HZ, e.hz])
			Fx.Kind.PULSE:
				check(e.hz > 0.0 and e.hz <= Spec.PULSE_HZ_MAX, "EFFECTS %s: a pulse is > 0 and <= %s Hz (got %s)" % [name, Spec.PULSE_HZ_MAX, e.hz])
			Fx.Kind.ONCE:
				check(e.hz == 0.0, "EFFECTS %s: a one-shot declares 0 Hz (its rate is its trigger's; got %s)" % [name, e.hz])
		check(e.fn == "" or (load("res://scripts/core/fx.gd") as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == e.fn),
				"EFFECTS %s: fn '%s' is a function on Fx (or empty)" % [name, e.fn])
	check(is_equal_approx(Fx.EFFECTS[&"invuln_blink"].hz, Fx.INVULN_BLINK_HZ) and is_equal_approx(Fx.EFFECTS[&"lurker_eye_pulse"].hz, Fx.EYE_PULSE_HZ),
			"the rows declare the rates the game runs (INVULN_BLINK_HZ, EYE_PULSE_HZ)")


## D3: a new public static effect function on Fx with no EFFECTS row fails here, so no effect
## ships undeclared.
func _test_reflection() -> void:
	var covered := {}
	for name: StringName in Fx.EFFECTS:
		covered[Fx.EFFECTS[name].get("fn", "")] = true
	var methods: Array = (load("res://scripts/core/fx.gd") as Script).get_script_method_list()
	var seen := 0
	for m: Dictionary in methods:
		var fn: String = m.name
		if fn.begins_with("_") or not (m.flags & METHOD_FLAG_STATIC) or fn in NOT_EFFECTS:
			continue
		seen += 1
		check(covered.has(fn), "Fx.%s() is an effect with an EFFECTS row (D3)" % fn)
	check(seen >= 4, "...the reflection sees Fx's effect functions (%d)" % seen)


## Counts what a player sees: the blink's dark-to-lit transitions per second, one sample per tick,
## over 2 s of invulnerability counting down.
func _blink_count(seconds: float) -> Dictionary:
	var rises := 0
	var values := {}
	var prev := Fx.blink_alpha(seconds)
	var r := seconds
	while true:
		r -= TICK
		if r <= 0.0:
			break  # the end of invulnerability (alpha back to 1.0) is not a flash
		var a := Fx.blink_alpha(r)
		values[a] = true
		if a > prev:
			rises += 1
		prev = a
	return {rises = rises, values = values}


func _test_blink_sampled() -> void:
	Game.reset_for_tests()
	var got := _blink_count(2.0)
	var hz: float = got.rises / 2.0
	check(is_equal_approx(hz, Spec.BLINK_HZ) and hz <= Spec.FLASH_HZ_MAX, "the invulnerability blink, sampled at 60 ticks/s, lights %s times/s (Spec %s, cap %s)" % [hz, Spec.BLINK_HZ, Spec.FLASH_HZ_MAX])
	check(got.values.keys().all(func(a: float) -> bool: return a == 0.0 or a == 1.0), "...between 0 and 1 (got %s)" % [got.values.keys()])
	check(Fx.blink_alpha(0.0) == 1.0 and Fx.blink_alpha(-0.1) == 1.0, "...and fully drawn once invulnerability is over")
	Game.settings.set_value(&"reduce_flashing", true)
	got = _blink_count(2.0)
	check(got.rises == 0 and got.values.keys() == [Fx.STEADY_ALPHA], "reduce flashing: steady transparency, no change at all (UX-DR126; %d rises, values %s)" % [got.rises, got.values.keys()])
	check(Fx.STEADY_ALPHA >= 0.3 and Fx.STEADY_ALPHA < 1.0, "...the player stays visible and reads as invulnerable (alpha %s)" % Fx.STEADY_ALPHA)
	check(Fx.blink_alpha(0.0) == 1.0, "...and fully drawn once it is over")
	Game.reset_for_tests()


## The pulse's peaks per second, one sample per tick over 2 s, for every PULSE row.
func _test_pulse_sampled() -> void:
	for name: StringName in Fx.EFFECTS:
		var e: Dictionary = Fx.EFFECTS[name]
		if e.kind != Fx.Kind.PULSE:
			continue
		var v: Array[float] = []
		var t := 0.0
		while t < 2.0:
			v.append(Fx.pulse(t, e.hz))
			t += TICK
		var peaks := 0
		for i in range(1, v.size() - 1):
			if v[i - 1] < v[i] and v[i] >= v[i + 1]:
				peaks += 1
		var hz: float = peaks / 2.0
		check(hz > 0.0 and hz <= Spec.PULSE_HZ_MAX, "%s, sampled at 60 ticks/s, peaks %s times/s (cap %s)" % [name, hz, Spec.PULSE_HZ_MAX])
		check(v.min() >= 0.0 and v.max() <= 1.0, "...within 0..1 (got %.3f..%.3f)" % [v.min(), v.max()])


func _sparks(parent: Node) -> CPUParticles2D:
	Fx.pop(parent, Vector2(10, 10))
	var p := parent.get_child(parent.get_child_count() - 1) as CPUParticles2D
	return p


## UX-DR126 (D5): half the count and a 1 px max under reduce flashing; the defaults are M1's.
func _test_pop_reduced() -> void:
	Game.reset_for_tests()
	var parent := Node2D.new()
	add_child(parent)
	var p := _sparks(parent)
	check(p != null and p.amount == 14 and p.scale_amount_min == 1.0 and p.scale_amount_max == 2.0, "pop() at the defaults: 14 sparks, 1-2 px, as in M1 (AC8; got %s, %s-%s)" % [p.amount, p.scale_amount_min, p.scale_amount_max])
	Game.settings.set_value(&"reduce_flashing", true)
	p = _sparks(parent)
	check(p != null and p.amount == 7 and p.scale_amount_min == 1.0 and p.scale_amount_max == 1.0, "...reduce flashing: 7 sparks, 1 px, the 1 px floor kept (D5; got %s, %s-%s)" % [p.amount, p.scale_amount_min, p.scale_amount_max])
	Game.reset_for_tests()
	parent.queue_free()


## UX-DR127: a popup rises 14 px by default and fades in place under reduced motion; it fades and
## frees itself either way.
func _test_popup_motion() -> void:
	for reduced: bool in [false, true]:
		Game.reset_for_tests()
		Game.settings.set_value(&"reduced_motion", reduced)
		var parent := Node2D.new()
		add_child(parent)
		Fx.popup(parent, Vector2(10, 10), "x5", Color.WHITE)
		var l := parent.get_child(0) as Label
		var y0 := l.position.y
		await get_tree().create_timer(0.55, true, false, false).timeout
		var rise := y0 - l.position.y
		var faded := l.modulate.a < 1.0
		if reduced:
			check(rise == 0.0 and faded, "popup() under reduced motion stays put and still fades (rose %.2f px, alpha %.2f)" % [rise, l.modulate.a])
		else:
			check(rise > 10.0 and rise <= 14.0 and faded, "popup() at the defaults rises (%.2f of 14 px) and fades (AC8)" % rise)
		await get_tree().create_timer(0.4, true, false, false).timeout  # fade ends at 0.85 s
		check(not is_instance_valid(l), "...and frees itself")
		parent.queue_free()
	Game.reset_for_tests()


## D10: one item per cached material, under the parent it is given (the room, AR23), drawn above the
## renderer's cull alpha, and all three gone within a second.
func _test_warm_up() -> void:
	var parent := Node2D.new()
	add_child(parent)
	Fx.warm_up(parent, Vector2(40, 50))
	var kids := parent.get_children()
	var parts := kids.filter(func(n: Node) -> bool: return n is CPUParticles2D)
	var labels := kids.filter(func(n: Node) -> bool: return n is Label)
	var sprites := kids.filter(func(n: Node) -> bool: return n is Sprite2D)
	check(kids.size() == 3 and parts.size() == 1 and labels.size() == 1 and sprites.size() == 1, "warm_up() adds three children: sparks, a label, a sprite (got %s)" % [kids])
	if kids.size() != 3 or parts.size() != 1 or labels.size() != 1 or sprites.size() != 1:
		parent.queue_free()
		return
	check(parts[0].material == Fx.unshaded() and labels[0].material == Fx.unshaded() and sprites[0].material == Fx.additive(), "...drawn with the cached unshaded(), unshaded() and additive()")
	check(sprites[0].texture == preload("res://art/light.png"), "...the sprite with art/light.png, as BudgetLight's fallback")
	check(kids.all(func(n: CanvasItem) -> bool: return n.modulate.a >= CANVAS_CULL_ALPHA and n.modulate.a <= 0.02),
			"...each at an alpha no one sees but the renderer still draws (>= %s, probed; got %s)" % [CANVAS_CULL_ALPHA, kids.map(func(n: CanvasItem) -> float: return n.modulate.a)])
	check(kids.all(func(n: CanvasItem) -> bool: return n.get(&"position") == Vector2(40, 50)), "...at the position given (the entry, inside the first view)")
	await get_tree().create_timer(1.0, true, false, false).timeout
	check(parent.get_child_count() == 0, "...and all three free themselves within a second (got %d left)" % parent.get_child_count())
	parent.queue_free()
