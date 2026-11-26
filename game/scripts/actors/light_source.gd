class_name LightSource
extends Node2D
## A light predators can sense (AR28): the player's Chain-Light, the Ember Cache (Story 1.22) and
## a tossed Flare (Story 1.23). Predators find it through group `light_source` and judge it with Sensing,
## never through group `player` (AR29; lint light_query).
## radius() is the rule value predators read. The shown radius, eased and kicked, is presentation
## only (a pogo's flare must never wake a lurker the chain itself wouldn't).
## It drives its child BudgetLight's size (texture_scale) and never its `enabled` or `visible`: the
## light budget alone decides light or sprite (Story 1.12, D4), and its fallback sprite copies the
## texture_scale, so a demoted light still follows the eased size.
## extinguish() is for a death (D5): a dead player's light leaves the group for good, so a lurker
## hunting it returns home at once and the next life's light (a new node) needs a fresh telegraph.

const LIGHT_LERP := 10.0  ## 1/s easing of the shown light toward radius(); presentation (was player.gd LIGHT_LERP, M1 player.light_lerp).
const GROUP := &"light_source"

## One of Sensing.KINDS, set by the owner (player.tscn: `player`). No default: `player` is the one
## kind that makes a hunt harmful (Lurker._harmful()), so a light that forgets its kind must never
## be one. A debug build asserts in _ready(); a release build treats it as a harmless decoy.
@export var kind: StringName = &""
## The rule radius, when set: the player sets it to chain.light_radius.
var radius_fn := Callable()
## px, for a light with a set radius: a Flare sets its pre-toss radius here in its _ready() and it
## holds for the whole burn (Story 1.23 D8); a test's stand-in. (The Ember Cache sets radius_fn
## instead, so its Tuning value is read on every call.)
var fixed_radius := 0.0
## The child BudgetLight it sizes, or null (a test stand-in has none).
var light: BudgetLight

var _shown := 0.0
var _snapped := false  # the shown radius starts at radius() on the first tick, never eased in from 0
var _out := false


func _ready() -> void:
	assert(kind in Sensing.KINDS, "LightSource: kind '%s' is not set or unknown (Sensing.KINDS)" % kind)
	add_to_group(GROUP)
	light = get_node_or_null(^"Light") as BudgetLight


## The rule value: what Sensing reads. Never the shown radius.
func radius() -> float:
	return radius_fn.call() if radius_fn.is_valid() else fixed_radius


## Leaves group light_source for good: nothing senses it again (D5).
func extinguish() -> void:
	_out = true
	if is_in_group(GROUP):
		remove_from_group(GROUP)


func is_lit() -> bool:
	return not _out and is_inside_tree() and is_in_group(GROUP)


## A source a predator may still read: not freed, still lit.
static func live(s: Variant) -> bool:
	return is_instance_valid(s) and s is LightSource and (s as LightSource).is_lit()


## The plain entry Sensing.pick_target() reads.
func sensed() -> Dictionary:
	return {kind = kind, radius = radius(), pos = global_position}


## The pogo flare (the player's LIGHT_KICK): the shown light swells, then eases back. The rule
## radius doesn't move.
func kick(px: float) -> void:
	_shown += px


func shown_radius() -> float:
	return _shown


## Snapped on the first tick, not in _ready(): children run _ready() before their parent, so the
## player's radius_fn is set after this node's _ready(). A parent's _physics_process runs before its
## children's, so this reads the chain as the player's tick left it (as _update_light() did).
func _physics_process(delta: float) -> void:
	if not is_lit():
		return  # a dead player's light holds where it was, as M1's did
	if not _snapped:
		_shown = radius()
		_snapped = true
	else:
		_shown = lerpf(_shown, radius(), clampf(LIGHT_LERP * delta, 0.0, 1.0))
	if light != null and light.texture != null:
		light.texture_scale = _shown / (light.texture.get_width() / 2.0)
