class_name ScreenRouter
extends Control
## One full-screen UI screen at a time (UX-DR23): opening one replaces the current one, never
## stacks on it. It sits after the gutters under World's UI layer, so a screen draws over them.
## No screens exist yet: the death card (1.29), the UI kit (1.31) and pause (1.34) open here.

var _current: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # an empty router must not eat clicks


func open(screen: Control) -> void:
	close()
	_current = screen
	add_child(screen)


func close() -> void:
	if _current != null and is_instance_valid(_current):
		remove_child(_current)  # out of the tree now, not at the end of the frame
		_current.queue_free()
	_current = null


func current() -> Control:
	return _current
