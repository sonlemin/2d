extends SceneTree
## Renders the shaft and saves PNG screenshots. This needs a real renderer, not --headless:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/screenshot.gd -- <out_dir>
## Shot 1: spawn, chain 0 (small light). Shot 2: mid-shaft, chain 10, with a lurker telegraphing.

const ShaftScene := preload("res://scenes/shaft.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print(("saved " if err == OK else "FAILED ") + path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var shaft: Node2D = ShaftScene.instantiate()
	root.add_child(shaft)
	var player: Player = shaft.get_node("Player")
	await _frames(30)
	await _shoot(out.path_join("shaft_spawn_chain0.png"))

	# Hang the player near a lurker with a long chain and let the telegraph start.
	var lurker: Lurker = get_nodes_in_group("predator")[1]
	player.set_physics_process(false)
	player.global_position = lurker.global_position + Vector2(-120, 10)
	for i in 10:
		player.chain.add_hit()
	var light: PointLight2D = player.get_node("Light")
	light.texture_scale = player.light_radius() / Player.LIGHT_TEXTURE_HALF
	var cam: Camera2D = player.get_node("Camera")
	cam.reset_smoothing()
	await _frames(25)
	await _shoot(out.path_join("shaft_chain10_telegraph.png"))
	quit(0)
