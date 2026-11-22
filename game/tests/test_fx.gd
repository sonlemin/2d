extends Node

const Spec := preload("res://tests/spec.gd")
const Rate := preload("res://tests/rate.gd")
const TICKS := 60.0  ## physics ticks/s: what a player sees, one frame per tick
const TICK := 1.0 / TICKS
const SAMPLE_S := 10.0  ## s sampled for a rate: long enough that one tick of error is under 0.01 Hz
## Values the story's ACs fix, which are not GDD thresholds (so not in Spec) and never read from Fx:
const M1_BLINK_LIT_S := 0.25  ## AC8: M1 drew the player for 0.25 s of each 0.4 s blink period; unchanged.
const STEADY_ALPHA_AC3 := 0.5  ## AC3: the steady transparency under reduce flashing.
const POPUP_RISE_AC8 := 14.0  ## px, AC8: M1's popup rise, kept (the design docs give no distance).
## Probed on 4.7.2 (Story 1.16 D10): RendererCanvasCull::_cull_canvas_item skips an item whose
## combined modulate alpha is < 0.007, so a warm-up drawn below it draws nothing.
const CANVAS_CULL_ALPHA := 0.007
## Public static functions on Fx that are not effects: the materials, the gate readers, warm-up.
const NOT_EFFECTS := ["unshaded", "additive", "flash_material", "white_flash_allowed", "reduce_flashing", "shake_on", "reduced_motion", "warm_up"]
## Story 1.19's hit flash, from its ACs (epics 1.19, UX-DR126), never read from Fx:
const FLASH_TICKS_AC8 := 4  ## 67 ms of white from the hit tick
const DIM_TICKS_AC8 := 6  ## 100 ms of dim under reduce flashing
const DIM_AC8 := 0.6  ## the dim's self_modulate
const INVULN_TICKS := 36  ## Spec.INVULN_S (0.6 s) at 60 ticks/s: hits back to back as each invulnerability ends
## Fx's shared materials (AR46, Story 1.12 D6): each one built once and reused, never one per effect,
## and the code-built effects free themselves. Story 1.16: the accessibility gate (AR57), the
## flash-rate table held to the cap (NFR8, UX-DR125), the reduced variants (UX-DR126/127) and
## warm-up at room load (D10). Rate caps come from Spec and the ACs' own values from the consts
## above, never from Fx's consts.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_fx.gd

var _fail := 0


func run() -> void:
	Game.reset_for_tests()  # pop() and popup() read the gate
	_test_materials()
	await _test_effects()
	_test_gate()
	_test_table()
	_test_reflection()
	_test_blink_sampled()
	_test_pulse_sampled()
	_test_pop_reduced()
	_test_hit_flash()
	_test_hit_flash_reduced()
	_test_hit_flash_flip()
	_test_flash_cap()
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
		check(e.reduced != "" or e.get("why", "") != "", "EFFECTS %s names its reduced variant, or says why it has none" % name)
		if e.kind != Fx.Kind.MOTION:
			check(e.hz <= Spec.FLASH_HZ_MAX, "EFFECTS %s: %s Hz is within the %s flashes/s cap" % [name, e.hz, Spec.FLASH_HZ_MAX])
		match e.kind:
			Fx.Kind.BLINK:
				check(is_equal_approx(e.hz, Spec.BLINK_HZ), "EFFECTS %s: a blink is exactly %s Hz (got %s)" % [name, Spec.BLINK_HZ, e.hz])
			Fx.Kind.PULSE:
				check(e.hz > 0.0 and e.hz <= Spec.PULSE_HZ_MAX, "EFFECTS %s: a pulse is > 0 and <= %s Hz (got %s)" % [name, Spec.PULSE_HZ_MAX, e.hz])
			Fx.Kind.ONCE:
				check(e.hz == 0.0, "EFFECTS %s: a one-shot declares 0 Hz (its rate is its trigger's: smoke_bot holds pogo hits apart; got %s)" % [name, e.hz])
			Fx.Kind.MOTION:
				# Code review 1.16 (sonlm): position or scale only, no brightness change, so declared
				# and not rate-capped. It must say why it is not a flash and has no reduced variant.
				check(e.hz >= 0.0 and e.reduced == "" and e.get("why", "") != "", "EFFECTS %s: a motion row declares its rate (%.2f Hz) and says why it is not capped" % [name, e.hz])
		check(e.fn == "" or (load("res://scripts/core/fx.gd") as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == e.fn),
				"EFFECTS %s: fn '%s' is a function on Fx (or empty)" % [name, e.fn])
	# The rates the game runs are measured on the real actors, not read back from the table:
	# smoke_world times a real lurker's eye pulse, smoke_a11y a real knock's blink.


## D3: a new public static effect function on Fx with no EFFECTS row fails here. It sees Fx's own
## functions only: an effect drawn elsewhere (the light kick, the arcs, the lurker's shiver) is
## declared by hand, and review is what catches a missing row.
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


## What a player sees of the blink, one sample per tick over `seconds` of invulnerability counting
## down: the ticks it turns lit (rises), the values drawn, and the length in ticks of every whole lit
## and dark run (a run cut by the start or the end of the window is not a whole one).
func _blink_samples(seconds: float) -> Dictionary:
	var rises: Array[int] = []
	var lit: Array[int] = []
	var dark: Array[int] = []
	var values := {}
	# Sampled half a tick off the tick boundaries, where the blink's edges fall (0.25 s and 0.4 s are
	# whole ticks), so float rounding can't move an edge to the next tick.
	var prev := Fx.blink_alpha(seconds - 0.5 * TICK)
	var run := 1
	var edges := 0
	var i := 0
	while true:
		i += 1
		var r := seconds - (i + 0.5) * TICK
		if r <= 0.0:
			break  # the end of invulnerability (alpha back to 1.0) is not a flash
		var a := Fx.blink_alpha(r)
		values[a] = true
		if a == prev:
			run += 1
			continue
		if edges > 0:
			(lit if prev > a else dark).append(run)
		edges += 1
		run = 1
		if a > prev:
			rises.append(i)
		prev = a
	return {rises = rises, values = values, lit = lit, dark = dark}


func _test_blink_sampled() -> void:
	Game.reset_for_tests()
	var got := _blink_samples(SAMPLE_S)
	var band := Rate.hz_band(got.rises, TICKS)
	check(band.x <= Spec.BLINK_HZ and Spec.BLINK_HZ <= band.y and band.x <= Spec.FLASH_HZ_MAX,
			"the invulnerability blink, sampled at 60 ticks/s, lights %.3f to %.3f times/s over %d blinks (Spec %s, cap %s)" % [band.x, band.y, got.rises.size(), Spec.BLINK_HZ, Spec.FLASH_HZ_MAX])
	var lit_ticks := roundi(M1_BLINK_LIT_S * TICKS)
	var dark_ticks := roundi((1.0 / Spec.BLINK_HZ - M1_BLINK_LIT_S) * TICKS)
	var within := func(runs: Array, want: int) -> bool: return not runs.is_empty() and runs.all(func(n: int) -> bool: return absi(n - want) <= 1)
	check(within.call(got.lit, lit_ticks) and within.call(got.dark, dark_ticks),
			"...lit %d ticks and dark %d of each period, within a tick: M1's 0.25 s of 0.4 s (AC8; lit %d..%d, dark %d..%d)" % [lit_ticks, dark_ticks, got.lit.min(), got.lit.max(), got.dark.min(), got.dark.max()])
	check(got.values.keys().all(func(a: float) -> bool: return a == 0.0 or a == 1.0), "...between 0 and 1 (got %s)" % [got.values.keys()])
	check(Fx.blink_alpha(0.0) == 1.0 and Fx.blink_alpha(-0.1) == 1.0, "...and fully drawn once invulnerability is over")
	Game.settings.set_value(&"reduce_flashing", true)
	got = _blink_samples(SAMPLE_S)
	check(got.rises.is_empty() and got.values.keys() == [STEADY_ALPHA_AC3], "reduce flashing: steady transparency at %s, no change at all (UX-DR126, AC3; %d rises, values %s)" % [STEADY_ALPHA_AC3, got.rises.size(), got.values.keys()])
	check(Fx.blink_alpha(0.0) == 1.0, "...and fully drawn once it is over")
	Game.reset_for_tests()


func _pulse_samples(hz: float) -> Array[float]:
	var v: Array[float] = []
	for i in int(SAMPLE_S * TICKS):
		v.append(Fx.pulse(i * TICK, hz))
	return v


## The pulse's rate from the span between its turns, one sample per tick, for every PULSE row.
func _test_pulse_sampled() -> void:
	# The measure itself: a pulse just over the cap is caught, one on it is not (a count over 2 s
	# read 2.1 Hz as 2.0).
	var over := Rate.hz_band(Rate.turns(_pulse_samples(2.1)), TICKS, 2)
	var on := Rate.hz_band(Rate.turns(_pulse_samples(Spec.PULSE_HZ_MAX)), TICKS, 2)
	check(over.x > Spec.PULSE_HZ_MAX and on.x <= Spec.PULSE_HZ_MAX, "the sampled measure tells a 2.1 Hz pulse (%.3f) from one on the %s Hz cap (%.3f)" % [over.x, Spec.PULSE_HZ_MAX, on.x])
	for name: StringName in Fx.EFFECTS:
		var e: Dictionary = Fx.EFFECTS[name]
		if e.kind != Fx.Kind.PULSE:
			continue
		var v := _pulse_samples(e.hz)
		var band := Rate.hz_band(Rate.turns(v), TICKS, 2)
		check(band.x > 0.0 and band.x <= Spec.PULSE_HZ_MAX, "%s, sampled at 60 ticks/s, pulses at least %.3f times/s (cap %s)" % [name, band.x, Spec.PULSE_HZ_MAX])
		check(v.min() >= 0.0 and v.max() <= 1.0, "...within 0..1 (got %.3f..%.3f)" % [v.min(), v.max()])


## Story 1.19 D9: white (the flash material) from the hit tick for 4 ticks, then restored.
func _test_hit_flash() -> void:
	Game.reset_for_tests()
	var m := Fx.flash_material()
	check(m != null and m == Fx.flash_material() and m.shader != null, "Fx.flash_material() is one cached ShaderMaterial")
	check(m != null and m.shader.code.contains("unshaded") and m.shader.code.contains("COLOR.rgb = vec3(1.0)"), "...unshaded, every texel white (probed on 4.7.2)")
	var s := Sprite2D.new()
	var drawn: Array[bool] = []
	var white: Array[bool] = []
	for tick in FLASH_TICKS_AC8 + 2:
		drawn.append(Fx.hit_flash(s, tick))
		white.append(s.material == m and s.self_modulate == Color.WHITE)
	var want_white: Array[bool] = []
	for tick in FLASH_TICKS_AC8 + 2:
		want_white.append(tick < FLASH_TICKS_AC8)
	check(white == want_white and drawn == want_white, "hit_flash() draws white for ticks 0-%d and restores at %d (white %s, running %s)" % [FLASH_TICKS_AC8 - 1, FLASH_TICKS_AC8, white, drawn])
	check(s.material == null and s.self_modulate == Color.WHITE, "...restored: no material, self_modulate white")
	check(not Fx.hit_flash(s, 0, false) and s.material == null and s.self_modulate == Color.WHITE, "a hit inside the gap (white = false) draws nothing at the defaults (Q1)")
	s.free()


## UX-DR126: under reduce flashing, a dim (self_modulate 0.6) for 6 ticks, never the white, and on
## every hit, gap or not.
func _test_hit_flash_reduced() -> void:
	Game.reset_for_tests()
	Game.settings.set_value(&"reduce_flashing", true)
	var dim := Color(DIM_AC8, DIM_AC8, DIM_AC8, 1.0)
	for white: bool in [true, false]:
		var s := Sprite2D.new()
		var seen: Array[bool] = []
		var want: Array[bool] = []
		for tick in DIM_TICKS_AC8 + 2:
			var running := Fx.hit_flash(s, tick, white)
			seen.append(running and s.self_modulate.is_equal_approx(dim) and s.material == null)
			want.append(tick < DIM_TICKS_AC8)
		check(seen == want, "reduce flashing (white %s): self_modulate %s and no material for ticks 0-%d, restored at %d (got %s)" % [white, DIM_AC8, DIM_TICKS_AC8 - 1, DIM_TICKS_AC8, seen])
		check(s.material == null and s.self_modulate == Color.WHITE, "...and restored afterwards")
		s.free()
	Game.reset_for_tests()


## The gate is read on every tick: a setting flipped mid-flash leaves nothing stuck.
func _test_hit_flash_flip() -> void:
	Game.reset_for_tests()
	var s := Sprite2D.new()
	Fx.hit_flash(s, 0)
	Fx.hit_flash(s, 1)
	Game.settings.set_value(&"reduce_flashing", true)
	Fx.hit_flash(s, 2)
	var mid := s.material == null and s.self_modulate.is_equal_approx(Color(DIM_AC8, DIM_AC8, DIM_AC8, 1.0))
	for tick in range(3, DIM_TICKS_AC8 + 1):
		Fx.hit_flash(s, tick)
	check(mid and s.material == null and s.self_modulate == Color.WHITE, "turning reduce flashing on mid-flash switches to the dim, then restores (mid %s)" % mid)
	Fx.hit_flash(s, 0)
	Game.reset_for_tests()
	var back := Fx.hit_flash(s, 3)
	Fx.hit_flash(s, FLASH_TICKS_AC8)
	check(back and s.material == null and s.self_modulate == Color.WHITE, "...and turning it off mid-dim ends on the white's length and restores")
	s.free()
	Game.reset_for_tests()


## NFR8, Q1 (D10): the player sprite's brightness, one sample per tick (white 2, lit 1, dark 0), for
## hits back to back as each invulnerability ends, with the white flash gated by
## Fx.white_flash_allowed() and the blink from Fx.blink_alpha(). The most flashes (opposing
## transition pairs) in any 60-tick window. Red-checked with the gap at 0: it reads 4.0.
func flash_cap_sim(every: int, total := 600) -> float:
	var s: Array[int] = []
	var hit := -1
	var white_start := -1
	var last_white := -1
	for t in total:
		if t > 0 and t % every == 0:
			hit = t
			if Fx.white_flash_allowed(last_white, t):
				last_white = t
				white_start = t
		if hit < 0:
			s.append(1)
			continue
		var v := 1 if Fx.blink_alpha(maxf(Spec.INVULN_S - (t - hit) * TICK, 0.0)) > 0.0 else 0
		if white_start >= 0 and t - white_start < FLASH_TICKS_AC8:
			v = 2
		s.append(v)
	var best := 0.0
	for w in range(1, total - int(TICKS)):
		var changes := 0
		for t in range(w, w + int(TICKS)):
			if s[t] != s[t - 1]:
				changes += 1
		best = maxf(best, changes / 2.0)
	return best


func _test_flash_cap() -> void:
	Game.reset_for_tests()
	for every: int in [INVULN_TICKS, 40, 48, 60]:
		var got := flash_cap_sim(every)
		check(got <= Spec.FLASH_HZ_MAX, "hit flash + blink, hits every %d ticks: at most %.1f flashes in any second (cap %s)" % [every, got, Spec.FLASH_HZ_MAX])


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
	Fx.pop(parent, Vector2(10, 10), 0)
	p = parent.get_child(parent.get_child_count() - 1) as CPUParticles2D
	check(p != null and p.amount == 1, "pop() with a count of 0 still makes one spark: CPUParticles2D rejects an amount below 1 (got %s)" % [p.amount if p != null else -1])
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
		# The rise takes 0.6 s and the fade ends at 0.85 s: read between the two, one frame after the
		# timer so the tweens have stepped this frame too.
		await get_tree().create_timer(0.7, true, false, false).timeout
		await get_tree().process_frame
		if not is_instance_valid(l):
			check(false, "setup: the popup is still there 0.7 s in (a frame took over 0.1 s?)")
			parent.queue_free()
			continue
		var rise := y0 - l.position.y
		var faded := l.modulate.a < 1.0
		if reduced:
			check(rise == 0.0 and faded, "popup() under reduced motion stays put and still fades (rose %.2f px, alpha %.2f)" % [rise, l.modulate.a])
		else:
			check(absf(rise - POPUP_RISE_AC8) < 0.01 and faded, "popup() at the defaults has risen %s px once its rise ends, and fades (AC8: M1's rise; got %.2f)" % [POPUP_RISE_AC8, rise])
		var left := 120
		while is_instance_valid(l) and left > 0:
			left -= 1
			await get_tree().process_frame
		check(not is_instance_valid(l), "...and frees itself")
		parent.queue_free()
	Game.reset_for_tests()


## D10: one item per cached material, under the parent it is given (the room, AR23), drawn above the
## renderer's cull alpha, alive for two frames whatever the frame time (probed under a renderer,
## code review 1.16: two drawn frames; the 0.05 s timer it replaced drew none after a slow frame),
## and all four gone within a second (Story 1.19 adds the flash material's sprite).
func _test_warm_up() -> void:
	var parent := Node2D.new()
	add_child(parent)
	Fx.warm_up(parent, Vector2(40, 50))
	var kids := parent.get_children()
	var parts := kids.filter(func(n: Node) -> bool: return n is CPUParticles2D)
	var labels := kids.filter(func(n: Node) -> bool: return n is Label)
	var glows := kids.filter(func(n: Node) -> bool: return n is Sprite2D and n.material == Fx.additive())
	var flashes := kids.filter(func(n: Node) -> bool: return n is Sprite2D and n.material == Fx.flash_material())
	check(kids.size() == 4 and parts.size() == 1 and labels.size() == 1 and glows.size() == 1 and flashes.size() == 1, "warm_up() adds four children: sparks, a label, a glow sprite, a flash sprite (got %s)" % [kids])
	if kids.size() != 4 or parts.size() != 1 or labels.size() != 1 or glows.size() != 1 or flashes.size() != 1:
		parent.queue_free()
		return
	check(parts[0].material == Fx.unshaded() and labels[0].material == Fx.unshaded(), "...the sparks and the label with the cached unshaded()")
	check(glows[0].texture == preload("res://art/light.png"), "...the glow sprite with additive() and art/light.png, as BudgetLight's fallback")
	check(flashes[0].texture == preload("res://art/player.png"), "...the flash sprite with flash_material() and art/player.png, what the hit flash draws (Story 1.19)")
	var real := Node2D.new()
	add_child(real)
	Fx.chain_popup(real, Vector2.ZERO, 1, 1)
	check(labels[0].label_settings != null and labels[0].label_settings == (real.get_child(0) as Label).label_settings,
			"...the label with a real chain popup's LabelSettings: the same font, size and outline (Story 1.17 AC4)")
	real.queue_free()
	check(kids.all(func(n: CanvasItem) -> bool: return n.modulate.a >= CANVAS_CULL_ALPHA and n.modulate.a <= 0.02),
			"...each at an alpha no one sees but the renderer still draws (>= %s, probed; got %s)" % [CANVAS_CULL_ALPHA, kids.map(func(n: CanvasItem) -> float: return n.modulate.a)])
	check(kids.all(func(n: CanvasItem) -> bool: return n.get(&"position") == Vector2(40, 50)), "...at the position given (the entry, inside the first view)")
	await get_tree().process_frame
	await get_tree().process_frame
	check(kids.all(func(n: Variant) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()), "...all four still there two frames later (Fx.WARM_FRAMES counts frames, not seconds)")
	await get_tree().create_timer(1.0, true, false, false).timeout
	check(parent.get_child_count() == 0, "...and all four free themselves within a second (got %d left)" % parent.get_child_count())
	parent.queue_free()
