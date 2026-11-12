extends Node
## Renders World and saves PNG screenshots. This needs a real renderer, not --headless:
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd <out_dir>
## Shot 1: spawn, chain 0 (small light). Shot 2: mid-shaft, chain 10, with a lurker telegraphing.
## It instances world.tscn (Story 1.6), so the shots show the real gutters, darkness and framing.

const WorldScene := preload("res://scenes/world/world.tscn")


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print(("saved " if err == OK else "FAILED ") + path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[1] if args.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var world: World = WorldScene.instantiate()
	add_child(world)
	var player := get_tree().get_first_node_in_group("player") as Player
	var cam := world.get_node("Camera") as CameraRig
	await _frames(30)
	await _shoot(out.path_join("shaft_spawn_chain0.png"))

	# Hang the player near a lurker with a long chain and let the telegraph start.
	# The second-highest lurker, picked by position (M1 took group index [1]).
	var lurkers := get_tree().get_nodes_in_group("predator")
	lurkers.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var lurker: Lurker = lurkers[1]
	player.set_physics_process(false)
	player.global_position = lurker.global_position + Vector2(-120, 10)
	player.velocity = Vector2.ZERO
	for i in 10:
		player.chain.add_hit()
	var light: PointLight2D = player.get_node("Light")
	light.texture_scale = player.light_radius() / Player.LIGHT_TEXTURE_HALF
	cam.snap()
	await _frames(25)
	await _shoot(out.path_join("shaft_chain10_telegraph.png"))
	world.queue_free()
	await _frames(1)
	Game.reset_for_tests()  # the chain above recorded a best chain on Game.slot
	print("PASS")
