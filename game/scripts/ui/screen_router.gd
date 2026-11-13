class_name ScreenRouter
extends Control
## One full-screen UI screen at a time (UX-DR23): opening one replaces the current one, never
## stacks on it. It sits after the gutters under World's UI layer, so a screen draws over them.
## No screens exist yet: the death card (1.29), the UI kit (1.31) and pause (1.34) open here.

var _current: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # an empty router must not eat clicks


## The router owns `screen` from here: it must come unparented. Opening the current one again
## keeps it (replacing it with itself would free it).
func open(screen: Control) -> void:
	assert(screen != null, "open() needs a screen; use close() to clear")
	if screen == _current:
		return
	assert(screen.get_parent() == null, "a screen is opened unparented: the router owns it")
	close()
	_current = screen
	add_child(screen)


## Frees the screen only while it is still the router's: one moved elsewhere is not ours to free.
func close() -> void:
	if is_instance_valid(_current) and _current.get_parent() == self:
		remove_child(_current)  # out of the tree now, not at the end of the frame
		_current.queue_free()
	_current = null


func current() -> Control:
	return _current
