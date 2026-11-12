class_name Clock
extends Node
## The only writer of Engine.time_scale (ADR-4): effects request a scale for a span of real time,
## and Engine.time_scale is always the assist factor times every active request's scale.
## - `Game.clock.request(&"hitstop", 0.05, 0.075)`: FR4, each hit freezes for 75 ms.
## - Re-requesting an active id refreshes it (latest scale and duration win). An id never
##   multiplies with itself, so a second pogo inside the freeze doesn't square the slow-down.
## - Timers ignore the time scale (else a 75 ms hitstop at x0.05 lasts 1.5 s) and pause with the
##   tree (AR36: a pause mid-hitstop resumes the freeze afterwards instead of eating it).

var _requests := {}  # StringName -> {scale: float, serial: int}
var _serial := 0
var _assist := 1.0  # E7's set_assist() multiplies in here


func request(id: StringName, scale: float, seconds: float) -> void:
	assert(scale > 0.0 and seconds > 0.0, "Clock.request(%s): scale and seconds must be > 0" % id)
	assert(is_inside_tree(), "Clock.request(%s): the Clock times requests on the tree" % id)
	_serial += 1
	_requests[id] = {scale = scale, serial = _serial}
	# Bind the serial, not the timer: a SceneTreeTimer can't be cancelled, so a refreshed
	# request's old timer still fires, and the serial check turns it into a no-op.
	get_tree().create_timer(seconds, false, false, true).timeout.connect(
			_on_expired.bind(id, _serial), CONNECT_ONE_SHOT)
	if Log.enabled(Log.CLOCK):
		Log.debug(Log.CLOCK, "%s x%.2f for %.3f s" % [id, scale, seconds])
	_apply()


func is_active(id: StringName) -> bool:
	return _requests.has(id)


## Death and leaving the tree must never strand the world in slow motion.
func clear() -> void:
	_requests.clear()
	_apply()


func _exit_tree() -> void:
	clear()


func _on_expired(id: StringName, serial: int) -> void:
	if _requests.has(id) and _requests[id].serial == serial:
		_requests.erase(id)
		_apply()


func _apply() -> void:
	var scale := _assist
	for r in _requests.values():
		scale *= r.scale
	Engine.time_scale = scale
