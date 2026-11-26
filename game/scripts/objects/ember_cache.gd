class_name EmberCache
extends Area2D
## The Ember Cache (FR24, Story 1.22): the carried embers a Normal death dropped, lying where the
## player last stood on clean floor. It burns amber because it holds your embers (sonlm, Q2), and
## its glow is a light predators sense like any other (AR28, AR29: a LightSource of kind `cache`,
## judged by Sensing), so it lures lurkers to it; hunting it is harmless (Lurker._harmful()).
## Touch it to carry its embers again (polled, never body_entered: AR30).
## The node is disposable (D7): it never decides anything about the slot. World spawns one when it
## builds the room the slot's cache lies in, and on any cache_changed (a recovery, a second death,
## a load, a reset) this node no longer stands for the slot's cache, so it goes dark and frees
## itself; the next build spawns whatever the slot holds.

var _taken := false  # at most one recovery per node

@onready var _light_source: LightSource = $LightSource


func _ready() -> void:
	# Shared and warmed by Fx.warm_up() (AR46: "small glows … cache core … are unshaded sprites").
	($Sprite as Sprite2D).material = Fx.unshaded()
	_light_source.radius_fn = _radius  # children are ready before the parent, as on the player
	Game.slot.cache_changed.connect(_on_cache_changed)  # a method: dropped with the node


## AR15: read on every call, so gear or a test seam bends it at once.
func _radius() -> float:
	return Game.tuning.f(&"cache_radius")


func _physics_process(_delta: float) -> void:
	if _taken:
		return
	for body in get_overlapping_bodies():
		if not body.is_in_group(&"player") or body.get(&"is_dead") != false:
			continue
		_taken = true
		var n := Game.slot.recover_cache(Game.dive)  # frees this node through cache_changed
		if n > 0 and body.has_method(&"popup_banked"):
			body.call(&"popup_banked", n)
		return


func _on_cache_changed(_room_id: StringName, _amount: int) -> void:
	_light_source.extinguish()  # a lurker hunting it heads home at once (H1)
	queue_free()
