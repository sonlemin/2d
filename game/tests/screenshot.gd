extends Node
## Renders m1_shaft and saves PNG screenshots. This needs a real renderer, not --headless:
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd <out_dir>
## Shot 1: spawn, chain 0 (small light). Shot 2: mid-shaft, chain 10, with a lurker telegraphing.
## The room is loaded standalone (Story 1.5), so this test lights the scene itself.

const RoomHarness := preload("res://tests/room_harness.gd")
## shaft.gd's ambient at the default brightness (level 1: 0.16 × the Edge palette's violet tint).
## World owns the ambient from 1.6/1.7; shaft.gd is not preloaded here.
const AMBIENT := Color(0.16 * 1.0, 0.16 * 0.86, 0.16 * 1.57)


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
	var darkness := CanvasModulate.new()
	darkness.color = AMBIENT
	add_child(darkness)
	var parts := RoomHarness.build(self, &"m1_shaft")
	var player: Player = parts.player
	await _frames(30)
	await _shoot(out.path_join("shaft_spawn_chain0.png"))

	# Hang the player near a lurker with a long chain and let the telegraph start.
	# The second-highest lurker, picked by position (M1 took group index [1]).
	var lurkers := get_tree().get_nodes_in_group("predator")
	lurkers.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var lurker: Lurker = lurkers[1]
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
	RoomHarness.free_all(parts)
	darkness.queue_free()
	print("PASS")
