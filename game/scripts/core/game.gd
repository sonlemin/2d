extends Node
## The `Game` autoload (AR9, AR11): references to session-long state, never rules.
## Story 1.4 adds settings, slot, dive and devices. It keeps the same instances all session and
## resets them in place, because subscribers hold on to them: gear changes call
## `tuning.apply_gear()`, never a new Tuning.

var clock := Clock.new()
var tuning := Tuning.new()  ## AR15: every bendable gameplay number; actors read it each tick


func _init() -> void:
	clock.name = "Clock"
	add_child(clock)
