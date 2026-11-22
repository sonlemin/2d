extends Node
## The light budget (AR46, Story 1.12 D3, D4, D11, D12): BudgetLight's pure rule choose(), apply() on
## real nodes (demotion, the sprite fallback, recovery, what takes a slot), the per-light on-screen
## rule moved from 1.11's overlay, and the scene audit (every PointLight2D in a scene is a
## BudgetLight that shares light.png).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_light_budget.gd
## Budget results compare against Spec.LIGHTS_ON_SCREEN_MAX, never BudgetLight.MAX_ON_SCREEN; the one
## check that names MAX_ON_SCREEN pins it at or under the Spec ceiling.

const Spec := preload("res://tests/spec.gd")
const LightTexture := preload("res://art/light.png")
const SCRIPT_PATH := "res://scripts/core/budget_light.gd"
const TEXTURE_PATH := "res://art/light.png"
const SCENES := "res://scenes"
const VIEW := Rect2(0, 0, 480, 270)

const A := BudgetLight.Rank.ALWAYS
const C := BudgetLight.Rank.CACHE
const G := BudgetLight.Rank.GLOW

var _fail := 0


func run() -> void:
	_test_spec()
	_test_choose()
	_test_jitter()
	await _test_nodes()
	await _test_sprite_sync()
	await _test_no_slot()
	await _test_lit_on_screen()
	_test_scene_audit()
	_test_scene_ranks()
	await get_tree().process_frame
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _e(rank: int, dist: float, lit := true, on_screen := true) -> Dictionary:
	return {rank = rank, on_screen = on_screen, lit = lit, dist = dist}


func _choose(entries: Array, budget := Spec.LIGHTS_ON_SCREEN_MAX) -> Array[bool]:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	return BudgetLight.choose(typed, budget)


func _test_spec() -> void:
	check(BudgetLight.MAX_ON_SCREEN <= Spec.LIGHTS_ON_SCREEN_MAX,
			"BudgetLight.MAX_ON_SCREEN (%d) is at or under Spec.LIGHTS_ON_SCREEN_MAX (%d): 1.15 may tighten it, never loosen it" % [BudgetLight.MAX_ON_SCREEN, Spec.LIGHTS_ON_SCREEN_MAX])


# --- choose(): the rule (D4) ------------------------------------------------------------------------

func _test_choose() -> void:
	# The 8-light case: 3 ALWAYS, 1 CACHE, 4 GLOWs at distinct distances, all lit as they arrive.
	var got := _choose([_e(A, 10), _e(A, 50), _e(A, 90), _e(C, 30), _e(G, 20), _e(G, 40), _e(G, 60), _e(G, 80)])
	check(got.count(true) == Spec.LIGHTS_ON_SCREEN_MAX, "8 on screen: exactly %d kept (got %s)" % [Spec.LIGHTS_ON_SCREEN_MAX, got])
	check(got == ([true, true, true, true, true, true, false, false] as Array[bool]),
			"...the two dropped are the farthest GLOWs; every ALWAYS and the CACHE kept (got %s)" % [got])
	# ALWAYS alone past the budget: every one kept, and everything else drops (AC3's "never").
	got = _choose([_e(A, 1), _e(A, 2), _e(A, 3), _e(A, 4), _e(A, 5), _e(A, 6), _e(A, 7), _e(G, 0)])
	check(got == ([true, true, true, true, true, true, true, false] as Array[bool]),
			"ALWAYS x7 + GLOW: all 7 ALWAYS kept over the budget, the GLOW dropped, nearest of all (got %s)" % [got])
	# The CACHE placed farthest, so a distance-only sort would drop it.
	got = _choose([_e(A, 0), _e(C, 200), _e(G, 10), _e(G, 20), _e(G, 30), _e(G, 40), _e(G, 50), _e(G, 60)])
	check(got == ([true, true, true, true, true, true, false, false] as Array[bool]),
			"ALWAYS + CACHE (farthest) + 6 GLOWs: the CACHE and the nearest 4 GLOWs kept (got %s)" % [got])
	# Rank beats both distance and stickiness: a demoted far CACHE takes the slot of a lit near GLOW.
	got = _choose([_e(A, 0), _e(C, 100, false), _e(G, 5, true)], 2)
	check(got == ([true, true, false] as Array[bool]), "a GLOW nearer than the CACHE, and lit, still ranks below it (got %s)" % [got])
	got = _choose([_e(G, 100, true), _e(G, 5, false)], 1)
	check(got == ([true, false] as Array[bool]), "sticky: a lit far GLOW keeps its slot against an unlit near one (got %s)" % [got])
	got = _choose([_e(G, 100, false), _e(G, 5, false)], 1)
	check(got == ([false, true] as Array[bool]), "...and with neither lit, the nearer one wins (the near-miss of the sticky case; got %s)" % [got])
	# A slot frees: a lit GLOW has left the screen; the nearest demoted GLOW is relit.
	got = _choose([_e(G, 999, true, false), _e(G, 10, true), _e(G, 30, false), _e(G, 20, false)], 2)
	check(got == ([true, true, false, true] as Array[bool]), "a slot frees when a lit GLOW leaves the screen: the nearest demoted GLOW is relit (got %s)" % [got])
	got = _choose([_e(G, 0, true, false), _e(G, 0, false, false), _e(A, 0, false, false)], 0)
	check(got == ([true, false, false] as Array[bool]), "off-screen entries keep lit as given, true and false, even at budget 0 (got %s)" % [got])
	got = _choose([_e(C, 1), _e(G, 2, false), _e(G, 3)], 0)
	check(got == ([false, false, false] as Array[bool]), "budget 0 with no ALWAYS: everything on screen drops (got %s)" % [got])
	got = _choose([], 6)
	check(got.is_empty(), "no entries, no flags")


## NFR8 (≤ 3 flashes/s): ALWAYS x5 + GLOW x2 (one slot left), 120 passes, each fed the last pass's
## output and the two GLOWs' distances swapped every pass. Only the first pass may change anything.
func _test_jitter() -> void:
	var entries: Array = [_e(A, 1), _e(A, 2), _e(A, 3), _e(A, 4), _e(A, 5), _e(G, 10), _e(G, 20)]
	var changes: Array[int] = []
	changes.resize(entries.size())
	changes.fill(0)
	var first: Array[bool] = []
	for pass_i in 120:
		var keep := _choose(entries)
		if pass_i == 0:
			first = keep
		for i in entries.size():
			if keep[i] != entries[i].lit:
				changes[i] += 1
			entries[i].lit = keep[i]
		var d: float = entries[5].dist
		entries[5].dist = entries[6].dist
		entries[6].dist = d
	check(first == ([true, true, true, true, true, true, false] as Array[bool]), "jitter: the first pass demotes the farther GLOW (got %s)" % [first])
	check(changes.max() <= 1, "jitter: over 120 passes with the GLOWs' distances swapping, no entry changes state more than once (got %s)" % [changes])


# --- apply() on nodes (D3, D12) ---------------------------------------------------------------------

## A BudgetLight under `parent`, rank and texture set before add_child (its _ready builds the sprite).
func _light(parent: Node, rank: int, pos: Vector2, energy := 1.0, scale := 0.2) -> BudgetLight:
	var l := BudgetLight.new()
	l.rank = rank
	l.texture = LightTexture
	l.energy = energy
	l.texture_scale = scale
	l.color = Color(1, 0.25, 0.2)
	l.position = pos
	parent.add_child(l)
	return l


## apply() returns nothing (it runs every tick); the cases read counts() right after it, as the
## overlay and the perf run do.
func _apply(lights: Array) -> Dictionary:
	BudgetLight.apply(lights, VIEW)
	return BudgetLight.counts(lights, VIEW)


func _holder() -> Node2D:
	var h := Node2D.new()
	add_child(h)
	return h


func _test_nodes() -> void:
	var h := _holder()
	var player := _light(h, A, Vector2(240, 135))
	var flares: Array[BudgetLight] = [_light(h, A, Vector2(200, 135)), _light(h, A, Vector2(280, 135))]
	var cache := _light(h, C, Vector2(240, 100), 1.0)
	# GLOWs 60, 80, 100 and 120 px from the view's centre (240, 135).
	var glows: Array[BudgetLight] = [_light(h, G, Vector2(300, 135)), _light(h, G, Vector2(240, 215)),
			_light(h, G, Vector2(140, 135)), _light(h, G, Vector2(240, 15))]
	var all: Array = [player] + flares + [cache] + glows
	check(all.all(func(l: BudgetLight) -> bool: return l.is_in_group(BudgetLight.GROUP)), "(premise) every BudgetLight joins group budget_light in _ready")
	var fallbacks_ok := all.all(func(l: BudgetLight) -> bool:
		var s := l.get_node_or_null(^"Fallback") as Sprite2D
		return (s == null) if l.rank == A else (s != null and s.material == Fx.additive() and not s.visible))
	check(fallbacks_ok, "(premise) each CACHE and GLOW has a hidden Fallback sprite drawn with Fx.additive(); ALWAYS lights have none")
	var r := _apply(all)
	check(r.lit == Spec.LIGHTS_ON_SCREEN_MAX and r.sprites == 2 and r.over == 0,
			"8 light sources on screen: %d stay lit, 2 show sprites, over 0 (got %s)" % [Spec.LIGHTS_ON_SCREEN_MAX, r])
	check(glows[2].demoted and glows[3].demoted and not glows[2].enabled and not glows[3].enabled,
			"...the 2 GLOWs farthest from the centre are demoted, their PointLight2D disabled")
	check(not glows[0].demoted and not glows[1].demoted and glows[0].enabled and glows[1].enabled and not cache.demoted and cache.enabled,
			"...the nearer GLOWs and the CACHE stay lit")
	check(([player] + flares).all(func(l: BudgetLight) -> bool: return l.enabled and not l.demoted), "...the player's and flares' lights never change")
	await get_tree().process_frame
	var fb := func(l: BudgetLight) -> Sprite2D: return l.get_node(^"Fallback") as Sprite2D
	check(fb.call(glows[2]).visible and fb.call(glows[3]).visible and not fb.call(glows[0]).visible and not fb.call(cache).visible,
			"...and after a frame the demoted GLOWs show their sprites, the lit ones don't")
	r = _apply(all)
	check(r.lit == Spec.LIGHTS_ON_SCREEN_MAX and r.sprites == 2 and glows[2].demoted and glows[3].demoted, "a second apply with nothing changed changes nothing (got %s)" % [r])
	# Recovery: the 60 px GLOW leaves the view; the nearest demoted one (100 px) is relit.
	glows[0].position = Vector2(2000, 2000)
	r = _apply(all)
	check(not glows[2].demoted and glows[2].enabled and glows[3].demoted, "a lit GLOW leaves the view: the nearest demoted GLOW is relit, the farthest stays a sprite")
	check(not glows[0].demoted and glows[0].enabled, "...and the one that left keeps its state (off screen: left as it is)")
	check(r.lit == Spec.LIGHTS_ON_SCREEN_MAX and r.sprites == 1, "...lit %d, sprites 1 (got %s)" % [Spec.LIGHTS_ON_SCREEN_MAX, r])
	h.queue_free()
	# ALWAYS x7 + GLOW: AC3's "never", with `over` reported.
	h = _holder()
	var always: Array[BudgetLight] = []
	for i in 7:
		always.append(_light(h, A, Vector2(100 + 40 * i, 135)))
	var glow := _light(h, G, Vector2(240, 140))
	r = _apply(always + [glow])
	check(r.lit == 7 and r.over == 1 and r.sprites == 1, "the player and 6 flares plus a glow: all 7 always-lights stay lit, over 1 (got %s)" % [r])
	check(glow.demoted and always.all(func(l: BudgetLight) -> bool: return l.enabled and not l.demoted), "...the glow still drops, and no ALWAYS light is disabled")
	h.queue_free()
	# A raw PointLight2D is not the budget's: apply() and counts() skip it.
	h = _holder()
	var raw := PointLight2D.new()
	raw.texture = LightTexture
	raw.energy = 1.0
	raw.position = Vector2(240, 135)
	h.add_child(raw)
	var one := _light(h, A, Vector2(240, 135))
	r = BudgetLight.counts([raw, one], VIEW)
	check(r.lit == 1, "counts() skips a raw PointLight2D: it counts only BudgetLights (got %s)" % [r])
	h.queue_free()
	await get_tree().process_frame


## D3: a demoted light's sprite has the light's texture, colour and size; its alpha follows the energy.
func _test_sprite_sync() -> void:
	var h := _holder()
	var g := _light(h, G, Vector2(100, 100), 1.0, 0.8)
	g.set_demoted(true)
	await get_tree().process_frame
	var s := g.get_node(^"Fallback") as Sprite2D
	check(s.visible and is_equal_approx(s.modulate.a, BudgetLight.SPRITE_ALPHA) and is_equal_approx(s.modulate.r, 1.0) and is_equal_approx(s.modulate.g, 0.25),
			"a demoted GLOW at energy 1.0 shows its sprite in its own colour, alpha %.2f (got %s)" % [BudgetLight.SPRITE_ALPHA, s.modulate])
	check(s.scale.is_equal_approx(Vector2.ONE * g.texture_scale) and s.texture == g.texture and s.position == g.offset,
			"...at the light's size (scale = texture_scale %.2f; got %s), texture and offset" % [g.texture_scale, s.scale])
	g.energy = 0.5
	await get_tree().process_frame
	check(absf(s.modulate.a - 0.5 * BudgetLight.SPRITE_ALPHA) < 0.01, "...energy 0.5 gives alpha %.3f (got %.3f)" % [0.5 * BudgetLight.SPRITE_ALPHA, s.modulate.a])
	g.energy = 0.0
	await get_tree().process_frame
	check(not s.visible, "...and at energy 0 the sprite hides")
	g.energy = 1.0
	g.set_demoted(false)
	check(not s.visible and g.enabled, "relit: the sprite hides and the light is enabled at once, not a frame later")
	h.queue_free()
	await get_tree().process_frame


## D4: a hidden or dark light takes no slot (lurker glows at rest are energy 0 and hidden).
func _test_no_slot() -> void:
	var h := _holder()
	var lights: Array[BudgetLight] = [_light(h, A, Vector2(240, 135))]
	for i in 5:
		lights.append(_light(h, G, Vector2(150 + 40 * i, 120)))
	var hidden := _light(h, G, Vector2(240, 130))
	hidden.visible = false
	var dark := _light(h, G, Vector2(240, 131), 0.0)
	var r := _apply(lights + [hidden, dark])
	var demoted := (lights + [hidden, dark]).filter(func(l: BudgetLight) -> bool: return l.demoted)
	check(demoted.is_empty() and r.lit == 6, "6 wanting plus 1 hidden and 1 at energy 0: none demoted, 6 lit (got %s, %d demoted)" % [r, demoted.size()])
	check(not hidden.wants_light() and not dark.wants_light() and lights[1].wants_light(), "wants_light(): shown, energy > 0 and textured")
	h.queue_free()
	await get_tree().process_frame


## 1.11 D10's per-light rule, moved here from the overlay (smoke_dev_tools' test_lights).
func _test_lit_on_screen() -> void:
	var rect := Rect2(0, 0, 360, 270)
	var cases := [
		["inside", Vector2(100, 100), {}, true],
		["hidden", Vector2(100, 100), {visible = false}, false],
		["disabled", Vector2(100, 100), {enabled = false}, false],
		["energy 0", Vector2(100, 100), {energy = 0.0}, false],
		["no texture", Vector2(100, 100), {texture = null}, false],
		["wholly outside", Vector2(1000, 1000), {}, false],
		["straddling the edge", Vector2(390, 100), {}, true],
	]
	var h := _holder()
	for c: Array in cases:
		var light := PointLight2D.new()
		light.texture = LightTexture
		light.energy = 1.0
		light.position = c[1]
		for key: String in c[2]:
			light.set(key, c[2][key])
		h.add_child(light)
		check(BudgetLight.lit_on_screen(light, rect) == c[3], "a light %s %s" % [c[0], "is lit on screen" if c[3] else "isn't lit on screen"])
	# Scale: light.png is 128 px; at texture_scale 0.25 a light is 32 px, or 64 px under a parent at
	# scale 2. Centred at x 390, the 32 px one ends at 374 (outside x 0-360); the 64 px one reaches 358.
	var parent := Node2D.new()
	parent.position = Vector2(390, 100)
	parent.scale = Vector2(2, 2)
	h.add_child(parent)
	var scaled := PointLight2D.new()
	scaled.texture = LightTexture
	scaled.energy = 1.0
	scaled.texture_scale = 0.25
	parent.add_child(scaled)
	var box := BudgetLight.texture_rect(scaled)
	check(box.size.is_equal_approx(Vector2(64, 64)) and box.get_center().is_equal_approx(Vector2(390, 100)),
			"texture_rect() under a parent at scale 2: 64 x 64 around the light (got %s)" % [box])
	check(BudgetLight.lit_on_screen(scaled, rect), "...so it is on screen by its scaled size")
	parent.scale = Vector2.ONE
	check(not BudgetLight.lit_on_screen(scaled, rect), "...and not at scale 1 (the near-miss)")
	h.queue_free()
	await get_tree().process_frame


# --- The scenes (D11) ---------------------------------------------------------------------------------

## Every PointLight2D stored in a scene under scenes/ is a BudgetLight using light.png, read through
## SceneState without instancing. .tscn files are never linted, which is why this exists.
func _test_scene_audit() -> void:
	var paths := _tscn_files(SCENES)
	var seen := ["actors/player.tscn", "actors/lurker.tscn", "world/world.tscn"].all(func(f: String) -> bool: return SCENES.path_join(f) in paths)
	check(seen, "(premise) the walk sees player, lurker and world under %s, nested folders included (%d scenes)" % [SCENES, paths.size()])
	var lights := 0
	for path in paths:
		var state := (load(path) as PackedScene).get_state()
		for i in state.get_node_count():
			if state.get_node_type(i) != "PointLight2D":
				continue
			lights += 1
			var props := {}
			for j in state.get_node_property_count(i):
				props[state.get_node_property_name(i, j)] = state.get_node_property_value(i, j)
			var where := "%s %s" % [path.get_file(), state.get_node_path(i)]
			var script: Variant = props.get("script")
			check(script is Script and (script as Script).resource_path == SCRIPT_PATH, "%s is a BudgetLight (script %s)" % [where, script])
			var tex: Variant = props.get("texture")
			check(tex is Texture2D and (tex as Texture2D).resource_path == TEXTURE_PATH, "%s uses light.png (texture %s)" % [where, tex])
	check(lights >= 2, "(sentinel) the audit found the player's and the lurker's lights (%d)" % lights)


func _tscn_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_tscn_files(dir.path_join(d)))
	return out


## The two scenes with lights, instanced but never added to the tree (no _ready, no side effects).
func _test_scene_ranks() -> void:
	var player := (load("res://scenes/actors/player.tscn") as PackedScene).instantiate()
	var light := player.get_node_or_null(^"LightSource/Light")
	check(light is BudgetLight, "player.tscn's LightSource/Light is a BudgetLight")
	if light is BudgetLight:
		check(light.rank == A, "...of rank ALWAYS: the player's light is never demoted")
	player.queue_free()
	var lurker := (load("res://scenes/actors/lurker.tscn") as PackedScene).instantiate()
	var glow := lurker.get_node_or_null(^"Glow")
	check(glow is BudgetLight, "lurker.tscn's Glow is a BudgetLight")
	if glow is BudgetLight:
		check(glow.rank == G, "...of rank GLOW: demoted first")
	var eyes := lurker.get_node_or_null(^"Eyes") as Sprite2D
	var m := eyes.material as CanvasItemMaterial if eyes != null else null
	check(m != null and m.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "the lurker's Eyes stay an unshaded sprite: small glows are never lights")
	lurker.queue_free()
