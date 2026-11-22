class_name Sensing
extends RefCounted
## The one light-sensing rule for every predator (AR29, FR17–FR20): a light wakes a predator only
## when it is big enough and near enough, and a predator notices only where its telegraph is seen.
## Pillar 2 ("warned, never ambushed"): notice needs the play rect (AR20: World.play_rect(), never
## the viewport); once noticed and telegraphed, the hunt follows the light by radius and distance
## alone (Story 1.20 Q1, sonlm). Off screen but in reach it stirs (D3), which the edge cue (1.27)
## and the stirring sound (E3) read.
## Pure: plain values in, plain values out, so test_sensing tests every boundary without a scene.
## The kinds live here because rules/ can't read actors/ (D2); LightSource uses them.

const NOTICE_MIN_RADIUS := 80.0  ## px of light before any predator notices it: GDD Lurker "≥ 80 px (4 links)" (Spec.NOTICE_MIN_RADIUS; was Lurker.NOTICE_MIN_RADIUS, M1 lurker.notice_min_radius).
const NOTICE_FACTOR := 1.6  ## × the light radius a predator senses from: GDD Lurker "within radius × 1.6" (Spec.NOTICE_FACTOR; was Lurker.NOTICE_FACTOR).
const SCREEN_MARGIN := 8.0  ## px inside the play rect a predator must sit to notice, so its whole telegraph is seen; no GDD line: a margin can only shrink where one notices (D3; was Lurker.SCREEN_MARGIN, M1 lurker.screen_margin).
const STIR_REACH := 96.0  ## px past the play rect's edge a predator that would wake still stirs: GDD Lurker "within 96 px of the edge" (Spec.STIR_REACH).

const KIND_PLAYER := &"player"
const KIND_FLARE := &"flare"
const KIND_CACHE := &"cache"
const KINDS: Array[StringName] = [KIND_PLAYER, KIND_FLARE, KIND_CACHE]


## Light and distance only, no screen: the hunt's rule (GDD Hunt; Q1). The reach is inclusive.
static func can_sense(light_pos: Vector2, light_radius: float, pred_pos: Vector2) -> bool:
	return light_radius >= NOTICE_MIN_RADIUS and pred_pos.distance_to(light_pos) <= light_radius * NOTICE_FACTOR


## Where a predator may notice: the play rect shrunk by the margin. Rect2.has_point() is half-open
## (probed on 4.7.2: the left and top edges count, the right and bottom do not).
static func notice_rect(play_rect: Rect2) -> Rect2:
	return play_rect.grow(-SCREEN_MARGIN)


## Wake and telegraph: sensed, and inside the notice rect (GDD Wakes "on screen").
static func can_notice(light_pos: Vector2, light_radius: float, pred_pos: Vector2, play_rect: Rect2) -> bool:
	return can_sense(light_pos, light_radius, pred_pos) and notice_rect(play_rect).has_point(pred_pos)


## Would wake but can't be seen: sensed, outside the notice rect, within STIR_REACH of the play rect.
## The 8 px band inside the play rect stirs too, so every sensed spot near the view either notices
## or stirs, with no silent gap (D3). grow() measures along each axis; corners reach a little further.
static func can_stir(light_pos: Vector2, light_radius: float, pred_pos: Vector2, play_rect: Rect2) -> bool:
	return can_sense(light_pos, light_radius, pred_pos) \
			and not notice_rect(play_rect).has_point(pred_pos) \
			and play_rect.grow(STIR_REACH).has_point(pred_pos)


## The light a predator goes for, among `lights` it already senses: each entry is
## {kind: StringName, radius: float, pos: Vector2}. The largest radius wins; on an exact tie a
## non-player light beats the player (GDD Flare Toss: "Predators that can sense the flare treat it
## as the player", so a decoy as bright as you draws them off); between two non-player lights the
## earlier index stays. -1 for none.
static func pick_target(lights: Array[Dictionary]) -> int:
	var best := -1
	for i in lights.size():
		if best == -1 or _beats(lights[i], lights[best]):
			best = i
	return best


## Does `a` (a later entry) take the place of `b`? Only a strictly larger radius, or a non-player
## light tying the player.
static func _beats(a: Dictionary, b: Dictionary) -> bool:
	if a.radius != b.radius:
		return a.radius > b.radius
	return b.kind == KIND_PLAYER and a.kind != KIND_PLAYER
