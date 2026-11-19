extends Node
## Fx's shared materials (AR46, Story 1.12 D6): each one built once and reused, never one per effect,
## and the code-built effects free themselves. Story 1.16 grows this test (the accessibility gate,
## warm-up at room load, flash-rate declarations).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_fx.gd

var _fail := 0


func run() -> void:
	_test_materials()
	await _test_effects()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_materials() -> void:
	var u := Fx.unshaded()
	check(u != null and u == Fx.unshaded(), "Fx.unshaded() returns the same instance twice")
	check(u != null and u.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and u.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX,
			"...unshaded, mixed: reads in the dark (light_mode %d, blend_mode %d)" % [u.light_mode, u.blend_mode])
	var a := Fx.additive()
	check(a != null and a == Fx.additive(), "Fx.additive() returns the same instance twice")
	check(a != null and a.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and a.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"...unshaded and additive: a sprite glow adds onto the dark (light_mode %d, blend_mode %d)" % [a.light_mode, a.blend_mode])
	check(u != a, "the two are different instances")


## pop() and popup() put one child under the parent they are given (the room, AR23), drawn with the
## shared unshaded material; the sparks free themselves once they finish.
func _test_effects() -> void:
	var parent := Node2D.new()
	add_child(parent)
	Fx.pop(parent, Vector2(10, 10))
	var sparks: Array[Node] = parent.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	check(sparks.size() == 1 and sparks[0].material == Fx.unshaded(), "pop() adds one CPUParticles2D with Fx.unshaded() (got %s)" % [parent.get_children()])
	Fx.popup(parent, Vector2(10, 10), "x5", Color.WHITE)
	var labels: Array[Node] = parent.get_children().filter(func(n: Node) -> bool: return n is Label)
	check(labels.size() == 1 and labels[0].material == Fx.unshaded(), "popup() adds one Label with Fx.unshaded() (got %s)" % [parent.get_children()])
	# Lifetime 0.35 s of game time (probed: freed after about 0.36 s). The timer runs on game time
	# too, so a time scale left by another test stretches both alike. A freed object compares equal
	# to null, so the premise is checked first.
	var found := sparks.size() == 1
	var p: Node = sparks[0] if found else null
	await get_tree().create_timer(0.6, true, false, false).timeout
	check(found and not is_instance_valid(p), "...and the sparks free themselves after their lifetime (AR46: code-built FX free themselves)")
	parent.queue_free()
