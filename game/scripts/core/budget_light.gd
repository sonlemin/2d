class_name BudgetLight
extends PointLight2D
## Every PointLight2D in the game (AR46, Story 1.12): lights × lit canvas items is the cost at
## 480×270, so at most MAX_ON_SCREEN keep their PointLight2D on screen; World's LightBudget node
## demotes the rest to an additive sprite glow each physics tick, after the actors (D5). The player
## and flares are never demoted (ALWAYS). Size comes from texture_scale only, on the shared
## art/light.png, so a demoted light's sprite is the same picture at the same size.
## Only the budget writes `enabled` on a BudgetLight, through set_demoted(); owners set energy,
## colour, texture_scale and visible, as they did on a plain PointLight2D.
## Depends only on core/ (Fx): world/ calls it, never the other way round.

enum Rank { ALWAYS, CACHE, GLOW }  ## slots go in this order; GLOW (lurker wall glow) is demoted first
const GROUP := &"budget_light"
const MAX_ON_SCREEN := 6  ## AR46 budget, until the CP1 perf verdict (1.15) confirms or tightens it; the guarantee is Spec.LIGHTS_ON_SCREEN_MAX
const SPRITE_ALPHA := 0.35  ## additive sprite alpha per unit of energy: about a dark wall's share of the light it replaces; presentation, judged by eye in 1.15

## A light that forgets its rank is demoted first, never kept over budget. Set before add_child
## (AR23): _ready() builds the fallback sprite from it.
@export var rank := Rank.GLOW:
	set(value):
		assert(not is_node_ready(), "BudgetLight: rank is set before add_child; _ready() built the fallback from the old one")
		rank = value
var demoted := false  ## read-only outside; set through set_demoted()

var _sprite: Sprite2D  # the fallback glow; ALWAYS lights have none


func _ready() -> void:
	add_to_group(GROUP)
	# Presentation only, and only while demoted: a lit light has nothing to sync.
	set_process(false)
	if rank == Rank.ALWAYS:
		return
	# A child, so it hides with the light (the lurker sets `visible`) and follows its interpolated
	# transform; `enabled = false` disables only the light, never its children (probed on 4.7.2).
	_sprite = Sprite2D.new()
	_sprite.name = "Fallback"
	_sprite.texture = texture
	_sprite.material = Fx.additive()
	_sprite.position = offset
	_sprite.visible = false
	add_child(_sprite)


## Shown, with energy and a texture. `enabled` is not part of it: the budget owns that.
func wants_light() -> bool:
	return is_visible_in_tree() and energy > 0.0 and texture != null


## Only the budget calls this. The light and its sprite swap in the same call, so no frame shows
## both or neither.
func set_demoted(on: bool) -> void:
	assert(not on or rank != Rank.ALWAYS, "BudgetLight: an ALWAYS light is never demoted (AR46)")
	demoted = on
	enabled = not on
	set_process(on and _sprite != null)
	_sync_sprite()


func _process(_delta: float) -> void:
	_sync_sprite()


## The sprite stands in for the light: same texture, colour and size; alpha follows the energy, so a
## lurker's pulse still reads. The texture is copied each time, so a light textured after _ready()
## still gets a full sprite.
func _sync_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = demoted and energy > 0.0
	if not _sprite.visible:
		return
	_sprite.texture = texture
	_sprite.modulate = Color(color.r, color.g, color.b, clampf(energy * SPRITE_ALPHA, 0.0, 1.0))
	_sprite.scale = Vector2.ONE * texture_scale
	_sprite.position = offset


# --- Pure statics (tests call them on stand-ins) -------------------------------------------------

## The light's texture in world space: its size at texture_scale and the global scale, centred on
## the offset point (1.11 D10's formula, moved from the overlay). An empty rect without a texture.
static func texture_rect(light: PointLight2D) -> Rect2:
	if light.texture == null:
		return Rect2(light.global_position, Vector2.ZERO)
	var size := light.texture.get_size() * light.texture_scale * light.global_scale.abs()
	return Rect2(light.to_global(light.offset) - size / 2.0, size)


## A light is lit on screen when it is shown, enabled, has energy and a texture, and its texture
## rect meets `rect`. Idle lurker glows have energy 0 and are hidden.
static func lit_on_screen(light: PointLight2D, rect: Rect2) -> bool:
	if not (light.is_visible_in_tree() and light.enabled and light.energy > 0.0 and light.texture != null):
		return false
	return texture_rect(light).intersects(rect)


## The rule (D4): which entries keep their PointLight2D. Each entry is {rank, on_screen, lit, dist}.
## - Off screen: `lit` unchanged. It costs nothing (the engine culls it), and leaving it alone means
##   a light near the edge can't toggle as it crosses.
## - On-screen ALWAYS: kept, taking a slot; past the budget the slots go negative and every other
##   light drops.
## - The rest on screen, by rank (CACHE before GLOW), then lit first (sticky: a light changes state
##   only when something enters, leaves or outranks it, so nothing flickers; NFR8 ≤ 3 flashes/s),
##   then nearest the centre, then index (group order is tree order): the first free slots keep.
static func choose(entries: Array[Dictionary], budget := MAX_ON_SCREEN) -> Array[bool]:
	var keep: Array[bool] = []
	keep.resize(entries.size())
	var slots := budget
	var rest: Array[int] = []
	for i in entries.size():
		var e := entries[i]
		if not e.on_screen:
			keep[i] = e.lit
		elif e.rank == Rank.ALWAYS:
			keep[i] = true
			slots -= 1
		else:
			rest.append(i)
	rest.sort_custom(func(a: int, b: int) -> bool: return _before(entries[a], entries[b], a, b))
	for k in rest.size():
		keep[rest[k]] = k < slots
	return keep


static func _before(x: Dictionary, y: Dictionary, xi: int, yi: int) -> bool:
	if x.rank != y.rank:
		return x.rank < y.rank
	if x.lit != y.lit:
		return x.lit
	if x.dist != y.dist:
		return x.dist < y.dist
	return xi < yi


## Applies the budget to `lights` (group budget_light) against `rect` (World.light_rect()): each
## BudgetLight that wants light is an entry; those whose state changes are demoted or relit.
## Returns nothing: it runs every tick, and only the overlay and the perf run need counts().
static func apply(lights: Array, rect: Rect2, budget := MAX_ON_SCREEN) -> void:
	var wanting: Array[BudgetLight] = []
	var entries: Array[Dictionary] = []
	var centre := rect.get_center()
	for n: Variant in lights:
		var l := n as BudgetLight
		if l == null:
			continue
		# A relit demoted light would draw light and sprite, uncounted (AR46).
		assert(l.enabled != l.demoted, "BudgetLight: only the budget writes `enabled` (set_demoted())")
		if not l.wants_light():
			continue
		var r := texture_rect(l)
		wanting.append(l)
		entries.append({rank = l.rank, on_screen = r.intersects(rect), lit = not l.demoted, dist = r.get_center().distance_to(centre)})
	var keep := choose(entries, budget)
	for i in wanting.size():
		if wanting[i].demoted == keep[i]:  # kept but demoted, or dropped but lit
			wanting[i].set_demoted(not keep[i])


## {lit, sprites, over} for `rect`: the BudgetLights lit on screen; the demoted ones that want light
## and meet it (their sprites show); and how far the ALWAYS lights alone exceed the budget. Raw
## PointLight2Ds are not counted: this is what the budget sees, and what overlay 4 shows.
static func counts(lights: Array, rect: Rect2, budget := MAX_ON_SCREEN) -> Dictionary:
	var lit := 0
	var sprites := 0
	var always := 0
	for n: Variant in lights:
		var l := n as BudgetLight
		if l == null:
			continue
		if lit_on_screen(l, rect):
			lit += 1
		if l.wants_light() and texture_rect(l).intersects(rect):
			if l.demoted:
				sprites += 1
			if l.rank == Rank.ALWAYS:
				always += 1
	return {lit = lit, sprites = sprites, over = maxi(0, always - budget)}
