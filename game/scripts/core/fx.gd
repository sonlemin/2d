class_name Fx
## One-shot hit effects built in code (no art needed). Unshaded so they read in the dark.
## Also the accessibility gate (AR57, Story 1.16 D1): the only script that reads reduce flashing,
## screen shake and reduced motion (lint a11y_gate). Camera shake, the invulnerability blink and the
## UI kit's easing ask the readers below; there are no per-effect toggles. EFFECTS declares every
## effect's flash rate, and test_fx holds it to the cap (NFR8, UX-DR125).

const SPARK := Color(1.0, 0.82, 0.48)   ## chain-light amber
const SPARK_COUNT := 14  ## particles per pogo spark burst; presentation (M1 value, was pop()'s default).
const INVULN_BLINK_HZ := 2.5  ## Hz the player blinks while invulnerable (GDD Combat damage table "blinking at 2.5 Hz"; UX-DR125 blinks are 2.5 Hz).
const INVULN_LIT := 0.625  ## fraction of each blink period drawn lit (M1: 0.25 s of 0.4 s), so the player is visible more than not.
const EYE_PULSE_HZ := 2.0  ## Hz of the lurker's telegraph eye pulse, a smooth sine (GDD Predators "pulse at 2 Hz"; the pulse cap is 2 Hz, so nothing may raise it; was lurker.EYE_PULSE_HZ).
const STEADY_ALPHA := 0.5  ## alpha a blink holds instead under reduce flashing (UX-DR126 "steady transparency"): still clearly visible.
const POPUP_RISE := 14.0  ## px a popup rises over its life; presentation (M1 value, was inline).
## Warm-up draws at this alpha: the lowest the canvas renderer still draws. Probed on 4.7.2:
## RendererCanvasCull::_cull_canvas_item skips an item whose combined modulate alpha is < 0.007, so
## 1/255 would be culled and warm up nothing (Story 1.16 D10).
const WARM_ALPHA := 0.01

enum Kind { ONCE, PULSE, BLINK }

## Everything in the game that flashes, blinks, pulses, shakes or eases (NFR8, UX-DR125, Story 1.16
## D3). A new effect adds its row here, with its reduced variant in words, and draws through this
## gate. hz is 0 for ONCE: a one-shot's rate is its trigger's (one per pogo hit, one per bank).
## `fn` names the Fx function that draws it ("" when it lives elsewhere); test_fx checks that every
## public effect function on Fx has a row.
const EFFECTS := {
	&"pogo_sparks": {kind = Kind.ONCE, hz = 0.0, fn = "pop", reduced = "reduce flashing: half the count, max size 2 -> 1 px (the 1 px floor, D5)"},
	&"popup": {kind = Kind.ONCE, hz = 0.0, fn = "popup", reduced = "reduced motion: fades in place, no rise"},
	&"chain_popup": {kind = Kind.ONCE, hz = 0.0, fn = "chain_popup", reduced = "reduced motion: as popup, which draws it"},
	&"camera_shake": {kind = Kind.ONCE, hz = 0.0, fn = "", reduced = "shake off: none (CameraRig asks shake_on())"},
	# No reduced variant: one 18 px swell eased back per pogo hit, and pogo hits are at least the
	# 0.22 s attack cooldown apart with a bounce between them, so it never nears the cap.
	&"light_kick": {kind = Kind.ONCE, hz = 0.0, fn = "", reduced = ""},
	&"invuln_blink": {kind = Kind.BLINK, hz = INVULN_BLINK_HZ, fn = "blink_alpha", reduced = "reduce flashing: steady transparency (STEADY_ALPHA)"},
	# No reduced variant: the telegraph must read by motion, not colour alone (UX-DR129), and 2 Hz is
	# within the pulse cap.
	&"lurker_eye_pulse": {kind = Kind.PULSE, hz = EYE_PULSE_HZ, fn = "pulse", reduced = ""},
}

static var _unshaded_material: CanvasItemMaterial
static var _additive_material: CanvasItemMaterial


## Shared by every code-built effect, built once (project-context: cache materials as statics, never
## one per effect; AR46). Unshaded, so it reads in the dark.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded_material == null:
		_unshaded_material = CanvasItemMaterial.new()
		_unshaded_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_material


## Sprite glows (BudgetLight's fallback, Story 1.12): added onto the dark and unshaded, so a
## demoted light still shows as a glow instead of vanishing under the darkness.
static func additive() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _additive_material


## AR57: true when blinks hold steady and sparks shrink (UX-DR126). Read live, so a DevTools --set
## or an Options change applies at once.
static func reduce_flashing() -> bool:
	return Game.settings.reduce_flashing


## FR38, UX-DR128: false means the camera never shakes; freeze frames and sparks stay.
static func shake_on() -> bool:
	return Game.settings.shake


## UX-DR127: true when popups stay put and UI easing snaps (the menu kit reads it when it lands).
static func reduced_motion() -> bool:
	return Game.settings.reduced_motion


## The invulnerability blink's alpha with `remaining` s of it left: lit for INVULN_LIT of each
## 1 / INVULN_BLINK_HZ period, dark for the rest (M1's 0.25 s of 0.4 s), or STEADY_ALPHA throughout
## under reduce flashing (UX-DR126). 1.0 once it is over. Pips reuse it (Story 1.25).
static func blink_alpha(remaining: float) -> float:
	if remaining <= 0.0:
		return 1.0
	if reduce_flashing():
		return STEADY_ALPHA
	var period := 1.0 / INVULN_BLINK_HZ
	return 1.0 if fmod(remaining, period) < INVULN_LIT * period else 0.0


## 0..1 sine at `hz`, the shape of every smooth pulse (the lurker's eyes; the alert frame, 1.27).
static func pulse(t: float, hz: float) -> float:
	return 0.5 + 0.5 * sin(t * TAU * hz)


## The pogo spark (Story 1.16 D6): every pogo hit kills a crawler today and this is its burst. Under
## reduce flashing, half the count and a 1 px max size (UX-DR126). "Half the size" keeps the 1 px
## floor (D5): a 0.5 px quad at nearest filter drops in and out between pixel centres, a flicker of
## its own.
static func pop(parent: Node, pos: Vector2, amount := SPARK_COUNT) -> void:
	var reduced := reduce_flashing()
	var p := CPUParticles2D.new()
	p.material = unshaded()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(int(amount * 0.5), 1) if reduced else amount
	p.lifetime = 0.35
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0 if reduced else 2.0
	p.color = SPARK
	p.global_position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A floating "x5" over the hit, so the chain count is felt where the eyes are.
static func chain_popup(parent: Node, pos: Vector2, count: int, embers: int) -> void:
	popup(parent, pos, "x%d  +%d" % [count, embers], SPARK, 8 if count < 5 else 10)


## Floating text that rises and fades; under reduced motion it fades in place (UX-DR127).
static func popup(parent: Node, pos: Vector2, text: String, color: Color, size := 8) -> void:
	var l := Label.new()
	l.material = unshaded()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 5
	parent.add_child(l)
	l.global_position = pos + Vector2(-10, -30)
	var tw := l.create_tween().set_parallel()
	if not reduced_motion():
		tw.tween_property(l, "position:y", l.position.y - POPUP_RISE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## AR46, Story 1.16 D10: GL Compatibility compiles a shader variant on an item's first draw, which the
## 1.15 web runs saw as a first-second hitch (docs/perf.md). So each cached material is drawn once
## at room load: sparks and a label with unshaded(), a light sprite with additive(). Children of the
## room (AR23), at `pos` (inside the first view: off-screen items are culled), at WARM_ALPHA (no one
## sees it, and the renderer still draws it), and each frees itself within a few frames.
static func warm_up(room: Node, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.material = unshaded()
	p.one_shot = true
	p.amount = 1
	p.lifetime = 0.05
	p.modulate.a = WARM_ALPHA
	p.position = pos
	room.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var l := Label.new()
	l.material = unshaded()
	l.text = "x"
	l.modulate.a = WARM_ALPHA
	l.position = pos
	room.add_child(l)
	var s := Sprite2D.new()
	s.material = additive()
	s.texture = preload("res://art/light.png")
	s.modulate.a = WARM_ALPHA
	s.position = pos
	room.add_child(s)
	# Two frames: one to be drawn, one to be sure the draw happened before the free.
	var tw := room.create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(l.queue_free)
	tw.tween_callback(s.queue_free)
