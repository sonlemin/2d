extends Node
## `--perf[=<s>]` (AR5, NFR1, NFR5; Story 1.12 D1, decided by sonlm 2026-11-19: the autopilot): a
## timed, repeatable perf run, so glow off/on, the laptop, Chrome, Firefox and an HD 620 can be
## compared. On every spawn it takes the player: input locked, hurtbox masked off (no contact can
## hurt it or break the chain), the chain paid through DevTools' --chain take-off arming (never
## pinned: 1.11 D6), and moved every physics tick along a vertical ping-pong down the room's centre,
## driven by a tick counter, never the wall clock. Two lights ride along, both the real things: a
## Flare (actors/flare.tscn, Story 1.23: rank ALWAYS, stuck, burning at the player's light radius of
## the tick it was made, FR15) and an Ember Cache (objects/ember_cache.tscn, Story 1.22: rank CACHE,
## Tuning's cache_radius, FR24). Both are LightSources, so they wake lurkers in perf_worst as real
## ones would, harmlessly: at chain 20 the flare ties the player's 138.4 px, and a tie goes to the
## non-player light, so lurkers in reach hunt the flare (or the cache), never the autopilot.
## The flare burns out every flare_burn seconds and is made again on the tick it is missing (never
## spawned, burnt out, freed with the room), so its fade and a new instance every 4 s are inside the
## measured window, as in play. It is not made until this life's chain has been seen held, so in a
## clean run every flare burns at the held chain's radius; after a break (a blocked path, as in
## m1_shaft) the chain is gone for good and the next flare burns at whatever the light is then
## (40 px): the summary's `breaks` already marks that run.
## It measures wall time between frames (Time.get_ticks_usec(), never delta, which the time scale
## bends), samples the light budget every tick, and at the end freezes one summary, logs it once and
## hands it to overlay 4. The autopilot keeps going after that, so the load stays while it is read.
## No class_name: DevTools preloads it, so dev/ adds one global name. Debug builds only.

const PATH_SPEED := 100.0  ## px/s up and down the room; just above a hunting lurker's 95 px/s, so hunters trail and fall away rather than pile up (since Story 1.20 a hunt keeps sensing off screen, so they drop when they fall out of reach, not at the screen edge)
const PATH_MARGIN := 3  ## tiles kept clear of the room's top and bottom edges
const FLARE_OFFSET := Vector2(-112, -32)  ## px from the player: on screen for the whole run, the worst case the budget must hold (in play a flare sticks where it lands; this one is stuck and carried along)
const CACHE_OFFSET := Vector2(112, 40)  ## px from the player, likewise (a real cache lies still)
const EmberCacheScene := preload("res://scenes/objects/ember_cache.tscn")
const FlareScene := preload("res://scenes/actors/flare.tscn")
const SLOW_FRAME_USEC := 20_000  ## NFR1: "no frame over 20 ms"
const PRIORITY := 100  ## after the player (0), the light budget (50) and DevTools' chain payment (100, earlier in the tree)
const KEEPER_PRIORITY := 25  ## the flare is remade after the actors (0: a flare burns out in its own tick) and before the light budget (50), as a real toss lands before it: made after the budget, the new always-light would stand beside a glow the budget had just relit, 7 lit for a tick

var seconds := 60  ## the run's length; set by DevTools before add_child
var hold_chain := ChainState.MAX_CHAIN  ## the chain held for the run: --chain's n, else 20
var glow := false  ## --glow=on, for the summary
var world: World  ## set by DevTools before add_child

var done := false  ## the summary is frozen
var result := {}  ## the summary, once done
var flare: Flare  ## the real flare riding along, re-made whenever it is missing; only read behind is_instance_valid()
var cache: EmberCache  ## the real Ember Cache riding along, re-made on every spawn; only read behind is_instance_valid()
var deaths := 0  ## spawns after the first (expected 0)
var breaks := 0  ## chain banks after the run started (expected 0)

var _player: Player  # only read behind is_instance_valid()
var _chain_held := false  # this life's chain has been seen at hold_chain: the flare may be made (cleared on every spawn)
var _spawn_frame := 0
var _spawns := 0
var _tick := 0  # ticks the player has run on the path since its spawn
var _x := 0.0
var _top := 0.0
var _bottom := 0.0
var _room_rect := Rect2()
var _path_checked := false
var _measuring := false
var _last_usec := 0
var _stats := {}
var _max_lit := 0
var _max_sprites := 0
var _max_over := 0


func _init() -> void:
	name = "PerfRun"
	process_physics_priority = PRIORITY


## Ticks between the actors and the light budget, for the flare's upkeep (KEEPER_PRIORITY).
class FlareKeeper extends Node:
	var keep := Callable()

	func _init() -> void:
		name = "FlareKeeper"
		process_physics_priority = KEEPER_PRIORITY

	func _physics_process(_delta: float) -> void:
		keep.call()


func _ready() -> void:
	world.player_spawned.connect(_on_player_spawned)  # a method: dropped with World
	var keeper := FlareKeeper.new()
	keeper.keep = _keep_flare
	add_child(keeper)


func _on_player_spawned(player: Player) -> void:
	_spawns += 1
	if _spawns > 1:
		deaths += 1
	_player = player
	_spawn_frame = Engine.get_physics_frames()
	_tick = 0
	_chain_held = false
	player.input.lock()
	# Untouchable: no predator or crawler contact can hurt or break the chain (the player's poll reads
	# the Hurtbox's overlaps, Story 1.19). Not monitoring = false: get_overlapping_bodies() then
	# prints an engine ERROR. smoke_perf pins this line. The mask never stops World's hazard poll (a
	# rect test on Room, not a physics overlap): perf_worst has no spikes, so the run stays untouched,
	# and a spike in a perf room would hit the autopilot (ledger, owner Story 7.13).
	player.get_node(^"Hurtbox").collision_mask = 0
	player.chain.banked.connect(_on_banked)
	var room := world.current_room()
	_room_rect = room.bounds()
	var margin := PATH_MARGIN * Room.TILE
	_x = _room_rect.get_center().x
	_top = _room_rect.position.y + margin
	_bottom = _room_rect.end.y - margin
	_place(0)
	player.reset_physics_interpolation()  # AR6: a teleport, never a smear
	# World snapped the rig to the P before this signal; without a second snap it would slide
	# about 60 px for half a second inside the measured window.
	var rig := get_viewport().get_camera_2d() as CameraRig
	if rig != null:
		rig.snap()
	if not _path_checked:
		_path_checked = true
		_check_path(room, player)
	# AR23: a child of the room, through room.spawn() like World's; the respawn's rebuild frees it
	# with the room (a death that changes the slot's cache frees it sooner, through cache_changed).
	cache = room.spawn(EmberCacheScene, _inside(player.global_position + CACHE_OFFSET)) as EmberCache
	cache.reset_physics_interpolation()


## Ticks the player has run, never the wall clock, so every run sees the same states in order.
## Skips paused ticks and the spawn frame, as DevTools' chain payment does.
func _physics_process(_delta: float) -> void:
	if get_tree().paused or Engine.get_physics_frames() <= _spawn_frame:
		return
	if not is_instance_valid(_player) or _player.is_dead:
		return
	_tick += 1
	_place(_tick)
	if _player.chain.count == hold_chain:
		_chain_held = true  # the keeper makes the flare from the next tick
	if not _measuring and not done and _chain_held:
		_measuring = true  # the clock starts in this frame's _process: the room build is never measured
	if _measuring and not done:
		var c := BudgetLight.counts(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())
		_max_lit = maxi(_max_lit, c.lit)
		_max_sprites = maxi(_max_sprites, c.sprites)
		_max_over = maxi(_max_over, c.over)


## Frame times in wall time. A paused frame is skipped and its time left out of the run.
func _process(_delta: float) -> void:
	if done or not _measuring:
		return
	var now := Time.get_ticks_usec()
	if _stats.is_empty():
		_stats = new_stats(seconds)
		_last_usec = now
		return
	if get_tree().paused:
		_last_usec = now
		return
	add_frame(_stats, now - _last_usec, _stats.sum_usec)
	_last_usec = now
	if _stats.sum_usec >= seconds * 1_000_000:
		_finish()


## Whole seconds measured so far (overlay 4's progress row).
func elapsed_s() -> int:
	return 0 if _stats.is_empty() else int(_stats.sum_usec / 1_000_000)


func _on_banked(_amount: int) -> void:
	if _measuring and not done:
		breaks += 1


func _place(tick: int) -> void:
	var p := path_point(tick, _top, _bottom, PATH_SPEED, Engine.physics_ticks_per_second)
	_player.global_position = Vector2(_x, p.x)
	_player.velocity = Vector2(0.0, p.y)  # the rig leads on the way down, as in a real dive
	if _flare_burning():
		flare.global_position = _inside(_player.global_position + FLARE_OFFSET)
	if is_instance_valid(cache):
		cache.global_position = _inside(_player.global_position + CACHE_OFFSET)


## Whether the flare is there to ride along: not freed, not burnt out (queued), not gone with a
## room World took out of the tree.
func _flare_burning() -> bool:
	return is_instance_valid(flare) and not flare.is_queued_for_deletion() and flare.is_inside_tree()


## The flare's upkeep, from FlareKeeper's tick. Made on any tick it is missing, once this life's
## chain has been seen held, at the player's light radius of that tick (FR15: the pre-toss radius);
## stuck at once (Flare.stick(), the seam for this), and carried along by _place().
func _keep_flare() -> void:
	if get_tree().paused or not _chain_held or _flare_burning():
		return
	if not is_instance_valid(_player) or _player.is_dead:
		return
	flare = world.current_room().spawn(FlareScene, _inside(_player.global_position + FLARE_OFFSET), {radius = _player.light_radius()}) as Flare
	flare.stick()
	flare.reset_physics_interpolation()  # AR6: its first placement is a teleport


## One tile inside the room, so a riding light never sits in the edge wall.
func _inside(p: Vector2) -> Vector2:
	var t := float(Room.TILE)
	return Vector2(clampf(p.x, _room_rect.position.x + t, _room_rect.end.x - t), clampf(p.y, _room_rect.position.y + t, _room_rect.end.y - t))


## D1: warns once when a solid cell lies under the player's body anywhere on the path; the run
## still goes ahead and the summary's `breaks` shows the damage (m1_shaft's middle ledge does this).
func _check_path(room: Room, player: Player) -> void:
	var half := Vector2(5, 10)
	var off := Vector2.ZERO
	var body := player.get_node_or_null(^"Body") as CollisionShape2D
	if body != null and body.shape is RectangleShape2D:
		half = (body.shape as RectangleShape2D).size / 2.0
		off = body.position
	var t := float(Room.TILE)
	var c0 := floori((_x + off.x - half.x) / t)
	var c1 := floori((_x + off.x + half.x - 0.01) / t)
	var r0 := floori((_top + off.y - half.y) / t)
	var r1 := floori((_bottom + off.y + half.y - 0.01) / t)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if room.is_solid(Vector2i(c, r)):
				push_warning("DevTools: --perf: room '%s' blocks the path at row %d; the chain will break there" % [room.id, r])
				return


func _finish() -> void:
	var s := summary(_stats)
	s.merge({seconds = seconds, max_lit = _max_lit, max_sprites = _max_sprites, max_over = _max_over,
			chain = hold_chain, breaks = breaks, deaths = deaths, glow = glow, window = get_window().size,
			os = OS.get_name(), adapter = RenderingServer.get_video_adapter_name()})
	result = s
	done = true
	Log.info(Log.ROOM, "dev: " + summary_text(result))


# --- Pure (test_dev_args) -----------------------------------------------------------------------------

## Vector2(y, vy) at `tick`: from `top` down to `bottom` and back at `speed` px/s, starting downward.
## A span of 0 or less stays at the top.
static func path_point(tick: int, top: float, bottom: float, speed: float, tps: int) -> Vector2:
	var span := bottom - top
	if span <= 0.0:
		return Vector2(top, 0.0)
	var p := fmod(tick * speed / tps, 2.0 * span)
	if p <= span:
		return Vector2(top + p, speed)
	return Vector2(bottom - (p - span), -speed)


## Counters and one bucket per whole second: no per-frame array (a headless run makes thousands).
static func new_stats(run_seconds: int) -> Dictionary:
	var buckets := PackedInt32Array()
	buckets.resize(run_seconds)
	return {frames = 0, sum_usec = 0, worst_usec = 0, worst_at_usec = 0, slow = 0, buckets = buckets}


## One frame of `dt_usec` that started `at_usec` into the run (the previous frame's end). It counts
## in the second it starts in, so the run's last frame (the first to end past `seconds`) still lands
## in the last whole second.
static func add_frame(stats: Dictionary, dt_usec: int, at_usec: int) -> void:
	stats.frames += 1
	stats.sum_usec += dt_usec
	if dt_usec > stats.worst_usec:
		stats.worst_usec = dt_usec
		stats.worst_at_usec = at_usec
	if dt_usec > SLOW_FRAME_USEC:
		stats.slow += 1
	var b := at_usec / 1_000_000
	var buckets: PackedInt32Array = stats.buckets
	if b >= 0 and b < buckets.size():
		buckets[b] += 1
		stats.buckets = buckets  # a packed array is a value: write it back


## {frames, avg_fps, min_fps (the fewest frames in any whole second), worst_ms, worst_at_s, slow_frames}.
static func summary(stats: Dictionary) -> Dictionary:
	var buckets: PackedInt32Array = stats.buckets
	var low := 0
	for i in buckets.size():
		low = buckets[i] if i == 0 else mini(low, buckets[i])
	var secs: float = stats.sum_usec / 1_000_000.0
	return {frames = stats.frames, avg_fps = stats.frames / secs if secs > 0.0 else 0.0, min_fps = low,
			worst_ms = stats.worst_usec / 1000.0, worst_at_s = stats.worst_at_usec / 1_000_000.0, slow_frames = stats.slow}


## The one summary line, logged as `[room] dev: perf …` and shown in overlay 4 (D1's format).
static func summary_text(r: Dictionary) -> String:
	var w: Vector2i = r.window
	return ("perf %d s: %d frames, avg %.1f fps, min %d fps, worst %.1f ms at %.1f s, %d over %d ms; "
			+ "lights max %d/%d, sprites max %d, over %d; chain %d, breaks %d, deaths %d; glow %s; window %dx%d; %s, %s") % [
			r.seconds, r.frames, r.avg_fps, r.min_fps, r.worst_ms, r.worst_at_s, r.slow_frames, SLOW_FRAME_USEC / 1000,
			r.max_lit, BudgetLight.MAX_ON_SCREEN, r.max_sprites, r.max_over, r.chain, r.breaks, r.deaths,
			"on" if r.glow else "off", w.x, w.y, r.os, r.adapter]
