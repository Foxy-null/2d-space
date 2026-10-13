extends SceneTree

var output := "res://docs/screenshots/art-review/round-1"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for i in arguments.size():
		if arguments[i] == "--output" and i + 1 < arguments.size():
			output = arguments[i + 1]
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://scenes/environment_preview.tscn")
	await _step(3)
	var preview := current_scene
	for i in 5:
		preview.set_environment(i)
		await _step(30)
		await _capture("environment_%d" % i)
		preview.player.set_gravity_direction(-1)
		preview.player.position = Vector2(150, 100)
		preview.player.velocity = Vector2.ZERO
		await _step(20)
		await _capture("environment_%d_inverted" % i)
		preview.player.respawn()
		await _step(3)
	preview.set_environment(3)
	preview.backdrop.motion_enabled = false
	for time in [119.98, 0.02, 2.0, 5.0, 8.0]:
		preview.backdrop.elapsed = time
		await _step(2)
		await _capture("lava_time_%.2f" % time)
	preview.set_environment(4)
	for time in [119.98, 0.02, 5.0]:
		preview.backdrop.elapsed = time
		await _step(2)
		await _capture("evil_time_%.2f" % time)
	# Every existing room is checked with its real camera, collision and HUD.
	for scene_path in ["res://scenes/tutorial.tscn", "res://scenes/stage_2.tscn"]:
		change_scene_to_file(scene_path)
		await _step(3)
		var stage := current_scene
		for i in stage.rooms.get_child_count():
			stage._set_room(i, false)
			stage.player.respawn()
			await _step(8)
			await _capture("%s_room_%02d" % ["tutorial" if stage.has_method("_mark") else "stage2", i + 1])
			if not stage.has_method("_mark"):
				stage.player.set_gravity_direction(-1)
				stage.player.position.y = 100
				stage.player.velocity = Vector2.ZERO
				await _step(12)
				await _capture("stage2_room_%02d_inverted" % (i + 1))
	# Locked -> unlocked -> physically pressed goal, with the actual original player.
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(3)
	var tutorial := current_scene
	var goal: ArrivalSwitch = tutorial.rooms.get_child(0).get_node("Goal")
	tutorial.player.position = goal.global_position + Vector2(0, -160)
	tutorial.player.velocity = Vector2.ZERO
	await _step(30)
	await _capture("goal_locked")
	tutorial._mark("jump")
	await _step(3)
	await _capture("goal_unlocking")
	await _step(40)
	await _capture("goal_pressed")
	print("ART_VISUAL_REVIEW_CAPTURED: " + output)
	quit()


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	assert(error == OK, "Screenshot failed: " + name)


func _step(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
