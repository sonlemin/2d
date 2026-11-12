class_name Crawler
extends CharacterBody2D
## Chain fuel. A slash or pogo kills it. Walkers patrol a ledge and turn at walls and edges.
## Hoverers float in the open shaft, drifting side to side so a dive can string them together.

# Walk speed, gravity and the hover drift are Game.tuning keys (crawler_*, AR15).

## Per instance: the spawner sets it before add_child (shaft.gd now, room spawn args from 1.5/1.6).
var hover := false

var _dir := -1.0
var _t := 0.0
var _home := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite
@onready var _edge_ray: RayCast2D = $EdgeRay


func _ready() -> void:
	add_to_group("enemy")
	_home = position
	reset_phase()


## Desync hoverers by position, not randomness: the abyss is hand-built and must play the same every time.
func reset_phase() -> void:
	_t = fposmod(_home.x * 0.37 + _home.y * 0.11, Game.tuning.f(&"crawler_hover_period"))


func _physics_process(delta: float) -> void:
	var t := Game.tuning
	if hover:
		_t += delta
		position.x = _home.x + sin(_t / t.f(&"crawler_hover_period") * TAU) * t.f(&"crawler_hover_drift")
		return
	velocity.y = minf(velocity.y + t.f(&"crawler_gravity") * delta, 400.0)
	_edge_ray.position.x = 7.0 * _dir
	if is_on_floor() and (is_on_wall() or not _edge_ray.is_colliding()):
		_dir = -_dir
		_edge_ray.position.x = 7.0 * _dir
	velocity.x = t.f(&"crawler_walk_speed") * _dir
	_sprite.flip_h = _dir > 0.0
	move_and_slide()


func take_hit() -> void:
	Fx.pop(get_parent(), global_position)
	queue_free()
