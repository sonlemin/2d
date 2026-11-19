class_name Fx
## One-shot hit effects built in code (no art needed). Unshaded so they read in the dark.

const SPARK := Color(1.0, 0.82, 0.48)   ## chain-light amber

static var _unshaded_material: CanvasItemMaterial
static var _additive_material: CanvasItemMaterial


## Shared by every code-built effect, built once (project-context: cache materials as statics, never
## one per effect; AR46). Unshaded, so it reads in the dark.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded_material == null:
		_unshaded_material = CanvasItemMaterial.new()
		_unshaded_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_material


## Sprite glows (BudgetLight's fallback, Story 1.12): added onto the dark and unshaded, so a
## demoted light still shows as a glow instead of vanishing under the darkness.
static func additive() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _additive_material


## A burst of sparks where a crawler dies.
static func pop(parent: Node, pos: Vector2, amount := 14) -> void:
	var p := CPUParticles2D.new()
	p.material = unshaded()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.35
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = SPARK
	p.global_position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A floating "x5" over the hit, so the chain count is felt where the eyes are.
static func chain_popup(parent: Node, pos: Vector2, count: int, embers: int) -> void:
	popup(parent, pos, "x%d  +%d" % [count, embers], SPARK, 8 if count < 5 else 10)


## Floating text that rises and fades.
static func popup(parent: Node, pos: Vector2, text: String, color: Color, size := 8) -> void:
	var l := Label.new()
	l.material = unshaded()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 5
	parent.add_child(l)
	l.global_position = pos + Vector2(-10, -30)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
