class_name Gutters
extends Control
## The two HUD gutters either side of the 360 px play area (UX-DR18). Flat strips for now: the
## 1 px rules and the HUD arrive in Story 1.25, which also rebinds on World.player_spawned.

## DESIGN.md `gutter-violet` (m1_shaft is zone=violet). Palette tokens and the per-zone fill arrive
## in Story 1.18.
const PLACEHOLDER := Color("#07060b")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view_w := CameraRig.GUTTER_WIDTH * 2.0 + CameraRig.PLAY_WIDTH
	for x: float in [0.0, view_w - CameraRig.GUTTER_WIDTH]:
		var strip := ColorRect.new()
		strip.color = PLACEHOLDER
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.position = Vector2(x, 0.0)
		strip.size = Vector2(CameraRig.GUTTER_WIDTH, get_viewport_rect().size.y)
		add_child(strip)
