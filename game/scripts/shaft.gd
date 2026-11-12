extends Node2D
## The interim game: builds m1_shaft (rooms/l1/m1_shaft.txt) through RoomLoader and runs the M1
## loop around it: HUD label, F1 brightness, F3 restart, reload on death. World replaces it in 1.6
## and it is deleted in 1.7.
## A death reloads the scene, which resets the chain and every enemy and respawns you at P.
## Session state lives in `Game` (Story 1.4), so it survives the reload: Settings.brightness,
## the SlotState records and the DiveState carried embers.

const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). `Settings.brightness` picks the level;
## F1 cycles it until Story 1.7 retires the shaft; DevTools sets it from then until Options (1.36).
## Lower = more tension; too low and darkness turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # keeps the violet cast of the Edge palette

@onready var _player: Player = $Player
@onready var _debug: Label = $Debug/Label
@onready var _darkness: CanvasModulate = $Darkness

var _deepest := 0.0
var _room: Room

const HUD_COLOR := Color(1, 0.823529, 0.478431)
const ALERT_COLOR := Color(1, 0.35, 0.3)  ## top label turns red while any lurker is awake


func _ready() -> void:
	# The entry scene boots Game once: it loads settings.json and arms its writes (Story 1.4 D6).
	# A test harness adds the shaft by hand and is never the current scene, so tests can't touch
	# the real settings.json even through the shaft. The call moves to world.gd in Story 1.6.
	if get_tree().current_scene == self:
		Game.boot()
	_apply_ambient()
	# A method, not a lambda: the connection drops when the shaft is freed on reload.
	Game.settings.changed.connect(_on_setting_changed)
	_room = RoomLoader.load_room(&"m1_shaft")
	assert(_room != null, "m1_shaft failed to load: its content errors are above")
	add_child(_room)
	move_child(_room, _player.get_index())  # the player draws on top
	_player.position = _room.entry_position(&"spawn")  # anchors and stations set the respawn point from Story 1.24
	_player.died.connect(_on_player_died)
	_player.chain.banked.connect(_on_banked)
	_player.chain.changed.connect(_on_chain_changed)
	# D2: the 352 px room centred in the view; the side bands show the clear colour where the
	# gutters go in 1.6 (camera_rig.gd takes this over).
	var cam: Camera2D = _player.get_node("Camera")
	var b := _room.bounds()
	var view_w := get_viewport_rect().size.x
	cam.limit_left = int(b.position.x - (view_w - b.size.x) / 2.0)
	cam.limit_right = cam.limit_left + int(view_w)
	cam.limit_top = int(b.position.y)
	cam.limit_bottom = int(b.end.y)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F1:  # the changed signal applies it, and the change is saved
		Game.settings.set_value(&"brightness", (Game.settings.brightness + 1) % AMBIENT_LEVELS.size())
	elif key.physical_keycode == KEY_F3:  # restart from the top
		get_tree().reload_current_scene()


func _on_setting_changed(key: StringName) -> void:
	if key == &"brightness":
		_apply_ambient()


func _apply_ambient() -> void:
	var v := AMBIENT_LEVELS[Game.settings.brightness]
	_darkness.color = Color(v * AMBIENT_TINT.r, v * AMBIENT_TINT.g, minf(v * AMBIENT_TINT.b, 1.0))


## M1's "banked" embers are M2's carried ones: they survive a death, held embers don't.
func _on_banked(amount: int) -> void:
	Game.dive.add_carried(amount)


func _on_chain_changed(count: int) -> void:
	Game.slot.record_chain(count)


func _physics_process(_delta: float) -> void:
	# Falling through the floor hole never ends until 1.7 wires the down exit to the top (R16 loop).
	if not _player.is_dead and _player.position.y > _room.bounds().end.y + 32:
		_player.die()


func _process(_delta: float) -> void:
	_deepest = maxf(_deepest, _player.position.y / Room.TILE)
	var hunting := 0
	for l in get_tree().get_nodes_in_group("predator"):
		if l.state != Lurker.State.IDLE:
			hunting += 1
	_debug.text = "embers %d  (held +%d)   chain %d (best %d)   light %d%s   depth %d   alert %d   deaths %d" % [
		Game.dive.carried, _player.chain.held, _player.chain.count, Game.slot.best_chain, int(_player.light_radius()),
		" SNUFF" if _player.chain.snuffed else "", int(_deepest), hunting, Game.slot.deaths]
	_debug.add_theme_color_override("font_color", ALERT_COLOR if hunting > 0 else HUD_COLOR)


func _on_player_died() -> void:
	Game.slot.record_death()
	await get_tree().create_timer(RESPAWN_DELAY, true, false, true).timeout
	if get_tree().current_scene == self:  # test harnesses add the shaft by hand; don't reload there
		get_tree().reload_current_scene()

