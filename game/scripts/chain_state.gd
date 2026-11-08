class_name ChainState
extends RefCounted
## Pure chain logic, with no scene or engine-node dependencies so headless tests can cover it.
##
## Pillar 1: Chain = Light = Danger. Each pogo hit without landing adds one link.
## The chain drives Blade Bloom (slash size) and Chain-Light (light radius).
## Landing and Snuff break it. All tuning constants live here.

signal changed(count: int)

# --- Tuning constants (addendum: "tuning constants to set in the MVP") ---
const MAX_CHAIN := 20
const BASE_RADIUS := 40.0        ## px of light with no chain
const RADIUS_GAIN := 22.0        ## px per sqrt(link)
const SNUFF_RADIUS := 12.0       ## px of light while snuffed
const BASE_BLOOM := 1.0          ## slash scale with no chain
const BLOOM_GAIN := 0.18         ## scale per sqrt(link)

var count: int = 0
var snuffed: bool = false


## Register a pogo hit. Snuffed hits still bounce the player but add no link,
## because there is no light to feed.
func add_hit() -> void:
	if snuffed:
		return
	var next := mini(count + 1, MAX_CHAIN)
	if next != count:
		count = next
		changed.emit(count)


func break_chain() -> void:
	if count != 0:
		count = 0
		changed.emit(count)


## Snuff (hold Light): going dark breaks the chain (decision log, 2026-11-08).
func set_snuffed(value: bool) -> void:
	snuffed = value
	if value:
		break_chain()


## Chain-Light radius in px. Diminishing returns: early links matter most.
func light_radius() -> float:
	if snuffed:
		return SNUFF_RADIUS
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
