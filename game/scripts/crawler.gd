class_name Crawler
extends CharacterBody2D
## Chain fuel. A slash or pogo kills it. Walkers patrol a ledge and turn at walls and edges.
## Hoverers float in the open shaft, drifting side to side so a dive can string them together.

@export var hover := false
@export var walk_speed := 25.0
@export var gravity := 900.0
@export var hover_drift := 10.0         ## px amplitude of the side-to-side drift
@export var hover_period := 2.4         ## seconds per drift cycle

var _dir := -1.0
var _t := 0.0
var _home := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite
@onready var _edge_ray: RayCast2D = $EdgeRay


func _ready() -> void:
	add_to_group("enemy")
	_home = position
	# Desync hoverers by position, not randomness: the abyss is hand-built and must play the same every time.
	_t = fposmod(position.x * 0.37 + position.y * 0.11, hover_period)


func _physics_process(delta: float) -> void:
	if hover:
		_t += delta
		position.x = _home.x + sin(_t / hover_period * TAU) * hover_drift
		return
	velocity.y = minf(velocity.y + gravity * delta, 400.0)
	_edge_ray.position.x = 7.0 * _dir
	if is_on_floor() and (is_on_wall() or not _edge_ray.is_colliding()):
		_dir = -_dir
		_edge_ray.position.x = 7.0 * _dir
	velocity.x = walk_speed * _dir
	_sprite.flip_h = _dir > 0.0
	move_and_slide()


func take_hit() -> void:
	Fx.pop(get_parent(), global_position)
	queue_free()
