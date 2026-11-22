class_name Gutters
extends Control
## The two HUD gutters either side of the 360 px play area (UX-DR18). Flat strips: their fill and
## the clear colour follow the active zone's gutter role (Story 1.18, UX-DR4). The 1 px rules and
## the HUD arrive in Story 1.25, which also rebinds on World.player_spawned.
## First colour: Gutters is World's child, so this _ready runs before World's. It paints the
## current zone (the default, or the last one), then World's first room build sets the room's
## zone and `changed` repaints before the first frame is drawn.

var _strips: Array[ColorRect] = []


func _ready() -> void:
	theme = ThemeBuilder.theme()  ## every HUD element added under the gutters inherits the game font (AR40)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view_w := CameraRig.GUTTER_WIDTH * 2.0 + CameraRig.PLAY_WIDTH
	for x: float in [0.0, view_w - CameraRig.GUTTER_WIDTH]:
		var strip := ColorRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.position = Vector2(x, 0.0)
		strip.size = Vector2(CameraRig.GUTTER_WIDTH, get_viewport_rect().size.y)
		add_child(strip)
		_strips.append(strip)
	_apply_palette()
	Game.palette.changed.connect(_apply_palette)


## The fill, and the clear colour with it: a 352 px room leaves 4 px of clear colour either side
## of it inside the play area, and matching the gutter makes them one band. CanvasModulate never
## tints the clear colour. Set here so the colour has one home (D7).
func _apply_palette() -> void:
	var c := Game.palette.color(Palettes.Role.GUTTER)
	for strip in _strips:
		strip.color = c
	RenderingServer.set_default_clear_color(c)
