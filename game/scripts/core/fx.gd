class_name Fx
## One-shot hit effects built in code (no art needed). Unshaded so they read in the dark. Popups
## draw TextStyle.play_text (Story 1.17), outlined in the active zone's surface (Game.palette,
## read when the popup is made: it lives 0.85 s and zones change only at a cut; Story 1.18 D8).
## Also the accessibility gate (AR57, Story 1.16 D1): the only script that reads reduce flashing,
## screen shake and reduced motion (lint a11y_gate). Camera shake, the invulnerability blink and the
## UI kit's easing ask the readers below; there are no per-effect toggles. EFFECTS declares each
## effect with its rate: test_fx holds the periodic ones to the caps and smoke_bot holds the pogo-hit
## one-shots apart (NFR8, UX-DR125).

const SPARK := Palettes.AMBER  ## the reserved chain-amber, one home (Story 1.18 D8; was Color(1.0, 0.82, 0.48), #ffd17a)
const SPARK_COUNT := 14  ## particles per pogo spark burst; presentation (M1 value, was pop()'s default).
const INVULN_BLINK_HZ := 2.5  ## Hz the player blinks while invulnerable (GDD Combat damage table "blinking at 2.5 Hz"; UX-DR125 blinks are 2.5 Hz).
const INVULN_LIT := 0.625  ## fraction of each blink period drawn lit (M1: 0.25 s of 0.4 s), so the player is visible more than not.
const EYE_PULSE_HZ := 2.0  ## Hz of the lurker's telegraph eye pulse, a smooth sine (GDD Predators "pulse at 2 Hz"; the pulse cap is 2 Hz, so nothing may raise it; was lurker.EYE_PULSE_HZ).
const STEADY_ALPHA := 0.5  ## alpha a blink holds instead under reduce flashing (UX-DR126 "steady transparency"): still clearly visible.
const POPUP_RISE := 14.0  ## px a popup rises over its life; presentation (M1 value, was inline).
const SHIVER_RATE := 40.0  ## rad/s of the lurker's telegraph body shiver, about 6.4 Hz at ±0.5 px; presentation (M1 value, was inline in lurker.gd).
## Warm-up draws at this alpha: the lowest the canvas renderer still draws. Probed on 4.7.2:
## RendererCanvasCull::_cull_canvas_item skips an item whose combined modulate alpha is < 0.007, so
## 1/255 would be culled and warm up nothing (Story 1.16 D10).
const WARM_ALPHA := 0.01
## Process frames the warm-up items live. Counted in frames, not seconds: a slow frame right after a
## load would end a timer before anything was drawn (code review 1.16). Three frame starts leave two
## drawn frames, whether the room loads in _ready, on a physics tick or in _process.
const WARM_FRAMES := 3
## The hit flash (Story 1.19 D9, epics 1.19, UX-DR126), counted in physics ticks: they run at 60 per
## real second even in a hitstop, and a hit can land in a pogo's. Reviewed at the CP2 gate (1.30).
const HIT_FLASH_TICKS := 4  ## ticks (67 ms) the sprite draws pure white from the hit tick (epics 1.19 "67 ms white"); reviewed at 1.30.
const HIT_DIM_TICKS := 6  ## ticks (100 ms) of the dim that replaces the white under reduce flashing (UX-DR126 "a short dim"); reviewed at 1.30.
const HIT_DIM := 0.6  ## self_modulate brightness of that dim (epics 1.19 "60%"; UX-DR126); reviewed at 1.30.
## Ticks from one white flash to the next (Q1, sonlm 2026-11-22: once per second). With the 2.5 Hz
## invulnerability blink, hits back to back at the 0.6 s invulnerability reach 4 flashes per second
## without it, and 3.0 with it (NFR8; simulated in test_fx). The dim and the blink always run.
## Reviewed at 1.30.
const HIT_FLASH_GAP_TICKS := 60

enum Kind { ONCE, PULSE, BLINK, MOTION }

## Everything in the game that flashes, blinks, pulses, shakes or eases (NFR8, UX-DR125, Story 1.16
## D3). A new effect adds its row here and draws through this gate.
## - hz is 0 for ONCE: a one-shot's rate is its trigger's. The cooldown alone does not hold the cap
##   (0.22 s apart is 4.5 per second), so the pogo-hit ones (sparks, chain popup, shake, light kick,
##   and the bank popup, at most one per chain) are held by smoke_bot, which measures the smallest
##   real-time gap between two pogo hits in every spine room against Spec.POGO_GAP_MIN.
## - MOTION moves or scales a sprite without changing its brightness: declared here, not rate-capped
##   (the cap is on flashes). Its hz is the rate it runs at, for the record.
## - `reduced` names the reduced variant in words; a row without one says why in `why`.
## - `fn` names the Fx function that draws it ("" when it lives elsewhere). test_fx checks that every
##   public effect function on Fx has a row; an effect drawn elsewhere is declared by hand.
const EFFECTS := {
	&"pogo_sparks": {kind = Kind.ONCE, hz = 0.0, fn = "pop", reduced = "reduce flashing: half the count, max size 2 -> 1 px (the 1 px floor, D5)"},
	&"popup": {kind = Kind.ONCE, hz = 0.0, fn = "popup", reduced = "reduced motion: fades in place, no rise"},
	&"chain_popup": {kind = Kind.ONCE, hz = 0.0, fn = "chain_popup", reduced = "reduced motion: as popup, which draws it"},
	&"camera_shake": {kind = Kind.ONCE, hz = 0.0, fn = "", reduced = "shake off: none (CameraRig asks shake_on())"},
	&"light_kick": {kind = Kind.ONCE, hz = 0.0, fn = "", reduced = "",
			why = "one 18 px swell of the player's light, eased back, per pogo hit (LightSource.kick(), from player.gd): a change of radius, never an on/off flash"},
	&"swing_arcs": {kind = Kind.ONCE, hz = 0.0, fn = "", reduced = "",
			why = "the slash and pogo arcs (player.gd) show for the 0.12 s or 0.22 s a swing can hit, once per Attack press: the player's own action at their own pace, not a flash the game plays at them (sonlm's laptop look, 2026-11-21: reads as a normal attack)"},
	&"invuln_blink": {kind = Kind.BLINK, hz = INVULN_BLINK_HZ, fn = "blink_alpha", reduced = "reduce flashing: steady transparency (STEADY_ALPHA)"},
	&"lurker_eye_pulse": {kind = Kind.PULSE, hz = EYE_PULSE_HZ, fn = "pulse", reduced = "",
			why = "the telegraph must read by motion, not colour alone (UX-DR129), and 2 Hz is within the pulse cap"},
	&"lurker_eye_open": {kind = Kind.MOTION, hz = 0.0, fn = "", reduced = "",
			why = "the eyes open from a slit over 0.2 s, once per telegraph (lurker.gd): part of the warning (UX-DR129)"},
	&"lurker_shiver": {kind = Kind.MOTION, hz = SHIVER_RATE / TAU, fn = "", reduced = "",
			why = "a ±0.5 px body shiver while a lurker telegraphs (lurker.gd): part of the warning, which must read by motion (UX-DR129); reduced motion covers UI easing and popups (UX-DR127)"},
	&"pogo_squash": {kind = Kind.MOTION, hz = 0.0, fn = "", reduced = "",
			why = "the sprite stretches to (0.75, 1.3) on a pogo hit and eases back on the physics tick, one tick = 1/60 s of real time, so it shows through the hitstop (player.gd, Story 1.19): hit feedback on the player's own action; reduced motion covers UI easing and popups (UX-DR127)"},
	&"hit_flash": {kind = Kind.ONCE, hz = 0.0, fn = "hit_flash", reduced = "reduce flashing: a 100 ms dim to 60% (self_modulate) instead of the white (UX-DR126 \"a short dim\")",
			why = "a white flash starts at most once per HIT_FLASH_GAP_TICKS (60): with the 2.5 Hz blink, hits back to back at the 0.6 s invulnerability would reach 4 flashes per second (Q1, sonlm 2026-11-22; NFR8)"},
}

static var _unshaded_material: CanvasItemMaterial
static var _additive_material: CanvasItemMaterial
static var _flash_material: ShaderMaterial


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


## The hit flash's look (Story 1.19 D9): every opaque texel pure white, unshaded so the darkness
## can't dim it, transparent texels untouched. `modulate` can't make a sprite white (it multiplies),
## so the flash swaps this in for its ticks only; the normal draw path is unchanged. Probed on 4.7.2:
## #ffffff under the dark CanvasModulate, and it composes with the blink's modulate.a. Built in code
## and cached (no .tres; AR46), and drawn once by warm_up().
static func flash_material() -> ShaderMaterial:
	if _flash_material == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tCOLOR.rgb = vec3(1.0);\n}\n"
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = shader
	return _flash_material


## Q1 (sonlm, 2026-11-22): a new white flash only when the last one started at least
## HIT_FLASH_GAP_TICKS ago. Ticks are Engine.get_physics_frames() values; `last` < 0 is never.
static func white_flash_allowed(last: int, now: int) -> bool:
	return last < 0 or now - last >= HIT_FLASH_GAP_TICKS


## Draws the hit flash on `item` at `tick` ticks after the hit (0 = the hit tick), and restores it
## once it is over (`material` null, `self_modulate` white). Returns true while it still draws, so the
## caller keeps ticking it, and false once it has restored. White for HIT_FLASH_TICKS when `white`
## (the gap allowed one, white_flash_allowed()); under reduce flashing, a dim to HIT_DIM for
## HIT_DIM_TICKS instead, on every hit (UX-DR126). The gate is read on every tick, so a setting
## flipped mid-flash restores cleanly. The caller owns `material` and `self_modulate` meanwhile.
static func hit_flash(item: CanvasItem, tick: int, white := true) -> bool:
	var reduced := reduce_flashing()
	var length := HIT_DIM_TICKS if reduced else (HIT_FLASH_TICKS if white else 0)
	if tick < 0 or tick >= length:
		item.material = null
		item.self_modulate = Color.WHITE
		return false
	if reduced:
		item.material = null
		item.self_modulate = Color(HIT_DIM, HIT_DIM, HIT_DIM, 1.0)
	else:
		item.material = flash_material()
		item.self_modulate = Color.WHITE
	return true


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
	p.amount = maxi(int(amount * 0.5) if reduced else amount, 1)  # CPUParticles2D rejects an amount below 1
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


## A floating "x5" over the hit, so the chain count is felt where the eyes are. 8 px at every
## count (Story 1.17 D7, sonlm): M1's 10 px scaled the 8 px face by a fraction; the gutter's chain
## number carries the long-chain read. Numbers only, so no string key (UX-DR150).
static func chain_popup(parent: Node, pos: Vector2, count: int, embers: int) -> void:
	popup(parent, pos, "x%d  +%d" % [count, embers], SPARK)


## Floating text that rises and fades; under reduced motion it fades in place (UX-DR127). Drawn in
## TextStyle.play_text: the game font at size 8 with the 1 px four-side outline (UX-DR15).
static func popup(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.material = unshaded()
	l.text = text
	l.label_settings = TextStyle.play_text(color, Game.palette.color(Palettes.Role.SURFACE))
	l.z_index = 5
	parent.add_child(l)
	l.global_position = pos + Vector2(-10, -30)
	var tw := l.create_tween().set_parallel()
	if not reduced_motion():
		tw.tween_property(l, "position:y", l.position.y - POPUP_RISE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## AR46, Story 1.16 D10: GL Compatibility compiles a shader variant on an item's first draw. So each
## cached material is drawn once at room load: sparks and a label with unshaded(), a light sprite
## with additive(), and the player's sprite with flash_material() (Story 1.19). Children of the room
## (AR23), at `pos` (inside the first view: off-screen items are culled), at WARM_ALPHA (no one sees
## it, and the renderer still draws it), freed after WARM_FRAMES. The room must be in the tree.
## Measured on the laptop (docs/perf.md): no change to the web first-frame stall, which is the load
## itself. Kept for the first use of a material later in a session; the stall is Story 7.13's.
static func warm_up(room: Node, pos: Vector2) -> void:
	assert(room.is_inside_tree(), "Fx.warm_up(): the room must be in the tree, or nothing is drawn")
	var p := CPUParticles2D.new()
	p.material = unshaded()
	p.amount = 1
	p.lifetime = 1.0  # outlives WARM_FRAMES: it is freed with the others, never by finishing first
	p.modulate.a = WARM_ALPHA
	p.position = pos
	room.add_child(p)
	p.emitting = true
	var l := Label.new()
	l.material = unshaded()
	l.text = "x"
	l.label_settings = TextStyle.play_text(SPARK, Game.palette.color(Palettes.Role.SURFACE))  # a real popup's font, size and outline
	l.modulate.a = WARM_ALPHA
	l.position = pos
	room.add_child(l)
	var s := Sprite2D.new()
	s.material = additive()
	s.texture = preload("res://art/light.png")
	s.modulate.a = WARM_ALPHA
	s.position = pos
	room.add_child(s)
	var f := Sprite2D.new()
	f.material = flash_material()
	f.texture = preload("res://art/player.png")  # what the real flash draws
	f.modulate.a = WARM_ALPHA
	f.position = pos
	room.add_child(f)
	_free_after_frames([p, l, s, f], room.get_tree(), WARM_FRAMES)


## Frees `items` once `frames` process frames have started. process_frame fires before that frame's
## _process and draw, and under --headless too (RenderingServer.frame_post_draw does not), so the
## items are drawn on every frame before the last one counted. Items freed with their room first are
## skipped.
static func _free_after_frames(items: Array[Node], tree: SceneTree, frames: int) -> void:
	for i in frames:
		await tree.process_frame
	for item in items:
		if is_instance_valid(item):
			item.queue_free()
