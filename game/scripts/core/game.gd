extends Node
## The `Game` autoload (AR9, AR11): references to session-long state, never rules.
## Stories 1.3 and 1.4 add tuning, settings, slot, dive and devices. It keeps the same instances
## all session and resets them in place, because subscribers hold on to them.

var clock := Clock.new()


func _init() -> void:
	clock.name = "Clock"
	add_child(clock)
