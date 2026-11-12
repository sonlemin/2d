extends Node2D
## The M1 test shaft: one hand-built vertical descent in the Edge of the Abyss palette.
## The layout below is the level. Each char is one 16 px tile:
##   #  wall          P  player spawn     c  walking crawler
##   .  empty         h  hovering crawler L  lurker (hidden; may sit inside a wall)
## A death reloads the scene, which resets the chain and every enemy.

const TILE := 16
const CrawlerScene := preload("res://scenes/actors/crawler.tscn")
const LurkerScene := preload("res://scenes/actors/lurker.tscn")
const TileTexture := preload("res://art/tile.png")
const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). F1 cycles it in game.
## Lower = more tension; too low and darkness turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # keeps the violet cast of the Edge palette

static var ambient_index := 1  # static: survives the scene reload on death
static var show_controls := true
static var best_chain := 0  # session stats for playtest notes (survive death reloads)
static var deaths := 0
static var checkpoint := Vector2.INF  # last ledge stood on: death respawns here, not at the top (F3 clears)
static var banked_embers := 0  # the haul: kept across deaths (only HELD embers are lost)

const LAYOUT: Array[String] = [
	"##############################",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..P.......................##",
	"##########..................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...........h......h.......##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##........h......h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...........h......h.......##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.........h......h.........##",
	"##..........................##",
	"#L..........................##",
	"##..........................##",
	"##..........................##",
	"##............h......h......##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........h......h........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...c..................c...##",
	"#########............#########",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##............h......h......##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##........h......h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................L#",
	"##......h......h............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.........h......h.........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.......h......h...........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"#L..........................##",
	"##..........h......h........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##........h......h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...........h......h.......##",
	"##..........................##",
	"##..........................##",
	"##..........c...............##",
	"##........##########........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##....h......h..............##",
	"##..........................##",
	"##..........................##",
	"##..................L.......##",
	"##........h......h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.............h......h.....##",
	"##..........................##",
	"##..........................##",
	"##.........h......h.........##",
	"##..........................##",
	"##......c..............c....##",
	"##############################",
	"##############################",
]

@onready var _walls: TileMapLayer = $Walls
@onready var _player: Player = $Player
@onready var _debug: Label = $Debug/Label
@onready var _darkness: CanvasModulate = $Darkness
@onready var _controls: Label = $Debug/Controls

var _deepest := 0.0
var _rim_material := _unshaded_material()

const HUD_COLOR := Color(1, 0.823529, 0.478431)
const LEDGE_RIM := Color(0.66, 0.71, 0.76, 0.45)  ## palette 3, dimmed: "you can stand here"
const ALERT_COLOR := Color(1, 0.35, 0.3)  ## top label turns red while any lurker is awake


func _ready() -> void:
	_apply_ambient()
	_controls.visible = show_controls
	_walls.tile_set = _make_tileset()
	_build()
	if checkpoint.is_finite():
		_player.position = checkpoint
	_player.died.connect(_on_player_died)
	_player.chain.banked.connect(func(amount: int) -> void: banked_embers += amount)
	var cam: Camera2D = _player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = LAYOUT[0].length() * TILE
	cam.limit_bottom = LAYOUT.size() * TILE


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # world
	var src := TileSetAtlasSource.new()
	src.texture = TileTexture
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	var h := TILE / 2.0
	var data := src.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return ts


func _build() -> void:
	var width := LAYOUT[0].length()
	for y in LAYOUT.size():
		var row := LAYOUT[y]
		assert(row.length() == width, "LAYOUT row %d has width %d, expected %d" % [y, row.length(), width])
		for x in row.length():
			var cell := Vector2i(x, y)
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"#":
					_walls.set_cell(cell, 0, Vector2i.ZERO)
					if y > 0 and LAYOUT[y - 1][x] != "#" and LAYOUT[y - 1][x] != "L":
						_add_ledge_rim(x, y)
				"P":
					_player.position = Vector2(center.x, (y + 1) * TILE - 12)  # feet on the tile below (body bottom = +12)
				"c", "h":
					var crawler: Crawler = CrawlerScene.instantiate()
					crawler.hover = row[x] == "h"
					crawler.position = center
					add_child(crawler)
				"L":
					if _is_wall(x - 1, y) or _is_wall(x + 1, y):
						_walls.set_cell(cell, 0, Vector2i.ZERO)  # in-wall lurker: no hole in the wall
					var lurker: Lurker = LurkerScene.instantiate()
					lurker.position = center
					add_child(lurker)


## A faint unshaded line on every floor surface, so places to land read even in the dark.
func _add_ledge_rim(x: int, y: int) -> void:
	var rim := ColorRect.new()
	rim.material = _rim_material
	rim.color = LEDGE_RIM
	rim.position = Vector2(x * TILE, y * TILE)
	rim.size = Vector2(TILE, 1)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rim)


func _is_wall(x: int, y: int) -> bool:
	return y >= 0 and y < LAYOUT.size() and x >= 0 and x < LAYOUT[y].length() and LAYOUT[y][x] == "#"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F1:
		ambient_index = (ambient_index + 1) % AMBIENT_LEVELS.size()
		_apply_ambient()
	elif key.physical_keycode == KEY_F2:
		show_controls = not show_controls
		_controls.visible = show_controls
	elif key.physical_keycode == KEY_F3:  # full run from the top
		checkpoint = Vector2.INF
		get_tree().reload_current_scene()


func _apply_ambient() -> void:
	var v := AMBIENT_LEVELS[ambient_index]
	_darkness.color = Color(v * AMBIENT_TINT.r, v * AMBIENT_TINT.g, minf(v * AMBIENT_TINT.b, 1.0))


func _process(_delta: float) -> void:
	_deepest = maxf(_deepest, _player.position.y / TILE)
	best_chain = maxi(best_chain, _player.chain.count)
	if _player.is_on_floor() and not _player.is_dead:
		checkpoint = _player.position  # the ground is the sanctuary: it is also where you come back
	var hunting := 0
	for l in get_tree().get_nodes_in_group("predator"):
		if l.state != Lurker.State.IDLE:
			hunting += 1
	_debug.text = "embers %d  (held +%d)   chain %d (best %d)   light %d%s   depth %d   alert %d   deaths %d" % [
		banked_embers, _player.chain.held, _player.chain.count, best_chain, int(_player.light_radius()),
		" SNUFF" if _player.chain.snuffed else "", int(_deepest), hunting, deaths]
	_debug.add_theme_color_override("font_color", ALERT_COLOR if hunting > 0 else HUD_COLOR)


func _on_player_died() -> void:
	deaths += 1
	await get_tree().create_timer(RESPAWN_DELAY, true, false, true).timeout
	if get_tree().current_scene == self:  # test harnesses add the shaft by hand; don't reload there
		get_tree().reload_current_scene()


static func _unshaded_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m
