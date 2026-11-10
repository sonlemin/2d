class_name ChainState
extends RefCounted
## Pure chain logic, with no scene or engine-node dependencies so headless tests can cover it.
##
## Pillar 1: Chain = Light = Danger. Each pogo hit without landing adds one link.
## The chain drives Blade Bloom (slash size) and Chain-Light (light radius).
## Landing and Snuff break it. All tuning constants live here.
##
## Embers (M1 reward test): every hit adds ember_value(link) to a HELD pile.
## Breaking the chain safely (landing, Snuff, a knock) BANKS the pile; dying LOSES it.

signal changed(count: int)
signal banked(amount: int)

# --- Tuning constants (addendum: "tuning constants to set in the MVP") ---
const MAX_CHAIN := 20
const BASE_RADIUS := 40.0        ## px of light with no chain
const RADIUS_GAIN := 22.0        ## px per sqrt(link)
const SNUFF_RADIUS := 12.0       ## px of light while snuffed
const BASE_BLOOM := 1.0          ## slash scale with no chain
const BLOOM_GAIN := 0.18         ## scale per sqrt(link)

var count: int = 0
var snuffed: bool = false
var clinging: bool = false       ## wall cling: chain paused and hidden (base light), not broken
var held: int = 0                ## embers riding on the current chain, not yet safe


## Register a pogo hit. Snuffed hits still bounce the player but add no link,
## because there is no light to feed.
func add_hit() -> void:
	if snuffed:
		return
	var next := mini(count + 1, MAX_CHAIN)
	held += ember_value(next)  # still pays at the cap: the light stops growing, the haul doesn't
	if next != count:
		count = next
		changed.emit(count)


## Safe end of a chain: the held embers are banked.
func break_chain() -> void:
	if held > 0:
		var amount := held
		held = 0
		banked.emit(amount)
	_reset_count()


## Death: the held embers are gone. Returns how many were lost.
func lose() -> int:
	var lost := held
	held = 0
	_reset_count()
	return lost


func _reset_count() -> void:
	if count != 0:
		count = 0
		changed.emit(count)


## Embers paid by the hit that makes link number `link` (1 = first hit of a chain).
## This curve IS the temptation: it decides how much one more pogo is worth.
## Default: linear per hit, so a chain of n pays n(n+1)/2 in total (quadratic).
static func ember_value(link: int) -> int:
	return maxi(link, 1)


## Snuff (hold Light): going dark breaks the chain (decision log, 2026-11-08).
func set_snuffed(value: bool) -> void:
	snuffed = value
	if value:
		break_chain()


## Wall cling pauses the chain: the count and held embers stay, the light drops to base.
func set_clinging(value: bool) -> void:
	clinging = value


## Chain-Light radius in px. Diminishing returns: early links matter most.
func light_radius() -> float:
	if snuffed:
		return SNUFF_RADIUS
	if clinging:
		return BASE_RADIUS  # pressed to the wall, the chain-light is shielded: lurkers lose you
	return radius_for(count)


static func radius_for(links: int) -> float:
	var n := clampi(links, 0, MAX_CHAIN)
	return BASE_RADIUS + RADIUS_GAIN * sqrt(float(n))


## Blade Bloom: a multiplier on slash and pogo hitbox size.
func bloom_scale() -> float:
	return bloom_for(count)


static func bloom_for(links: int) -> float:
	var n := clampi(links, 0, MAX_CHAIN)
	return BASE_BLOOM + BLOOM_GAIN * sqrt(float(n))
