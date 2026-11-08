extends Node2D
## The M1 test shaft: one hand-built vertical descent in the Edge of the Abyss palette.
## The layout below is the level. Each char is one 16 px tile:
##   #  wall          P  player spawn     c  walking crawler
##   .  empty         h  hovering crawler L  lurker (hidden; may sit inside a wall)
## A death reloads the scene, which resets the chain and every enemy.

const TILE := 16
const CrawlerScene := preload("res://scenes/enemies/crawler.tscn")
const LurkerScene := preload("res://scenes/enemies/lurker.tscn")
const TileTexture := preload("res://art/tile.png")
const RESPAWN_DELAY := 0.6
## Ambient brightness of the dark (CanvasModulate value). F1 cycles it in game.
## Lower = more tension; too low and darkness turns into confusion (Pillar 2).
const AMBIENT_LEVELS: Array[float] = [0.07, 0.16, 0.28, 0.45]
const AMBIENT_TINT := Color(1.0, 0.86, 1.57)  # keeps the violet cast of the Edge palette

static var ambient_index := 1  # static: survives the scene reload on death

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
	"##...........h..............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...............h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...........h..............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##................h.........##",
	"##..........................##",
	"#L..........................##",
	"##..........................##",
	"##..........................##",
	"##............h.............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.................h........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...c..................c...##",
	"#########............#########",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##............h.............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##........h.................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................L#",
	"##.............h............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##.........h................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..............h...........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"#L..........................##",
	"##..........h...............##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...............h..........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##...........h..............##",
	"##..........................##",
	"##..........................##",
	"##..........c...............##",
	"##........##########........##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##....h.....................##",
	"##..........................##",
	"##..........................##",
	"##..................L.......##",
	"##........h.................##",
	"##..........................##",
	"##..........................##",
	"##..........................##",
	"##....................h.....##",
	"##..........................##",
	"##..........................##",
	"##................h.........##",
	"##..........................##",
	"##......c..............c....##",
	"##############################",
	"##############################",
]

@onready var _walls: TileMapLayer = $Walls
@onready var _player: Player = $Player
@onready var _debug: Label = $Debug/Label
@onready var _darkness: CanvasModulate = $Darkness

var _deepest := 0.0


func _ready() -> void:
	_apply_ambient()
	_walls.tile_set = _make_tileset()
	_build()
	_player.died.connect(_on_player_died)
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


func _is_wall(x: int, y: int) -> bool:
	return y >= 0 and y < LAYOUT.size() and x >= 0 and x < LAYOUT[y].length() and LAYOUT[y][x] == "#"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		ambient_index = (ambient_index + 1) % AMBIENT_LEVELS.size()
		_apply_ambient()


func _apply_ambient() -> void:
	var v := AMBIENT_LEVELS[ambient_index]
	_darkness.color = Color(v * AMBIENT_TINT.r, v * AMBIENT_TINT.g, minf(v * AMBIENT_TINT.b, 1.0))


func _process(_delta: float) -> void:
	_deepest = maxf(_deepest, _player.position.y / TILE)
	var hunting := 0
	for l in get_tree().get_nodes_in_group("predator"):
		if l.state != Lurker.State.IDLE:
			hunting += 1
	_debug.text = "chain %d   light %d px%s   depth %d   predators alert %d   [F1] bright %d/%d" % [
		_player.chain.count, int(_player.light_radius()),
		"  [SNUFF]" if _player.chain.snuffed else "", int(_deepest), hunting,
		ambient_index + 1, AMBIENT_LEVELS.size()]


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY, true, false, true).timeout
	if get_tree().current_scene == self:  # test harnesses add the shaft by hand; don't reload there
		get_tree().reload_current_scene()
