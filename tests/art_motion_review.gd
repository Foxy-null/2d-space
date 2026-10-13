extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/environment_preview.tscn")
	await process_frame
	await process_frame
	var preview := current_scene
	for theme in [3, 4, 0, 1, 2]:
		preview.set_environment(theme)
		preview.player.respawn()
		for frame in (300 if theme in [3, 4] else 120):
			if frame == 120:
				Input.action_press("move_right")
			if frame == 140:
				Input.action_press("jump")
			if frame == 145:
				Input.action_release("jump")
			if frame == 175:
				Input.action_release("move_right")
			if frame == 195:
				Input.action_press("dash")
			if frame == 200:
				Input.action_release("dash")
			if frame == 230:
				preview.player.respawn()
			if frame == 250:
				preview.player.set_gravity_direction(-1)
				preview.player.position = Vector2(150, 100)
				preview.player.velocity = Vector2.ZERO
			await process_frame
	change_scene_to_file("res://scenes/tutorial.tscn")
	await process_frame
	await process_frame
	var tutorial := current_scene
	var goal: ArrivalSwitch = tutorial.rooms.get_child(0).get_node("Goal")
	tutorial.player.position = goal.global_position + Vector2(0, -160)
	tutorial.player.velocity = Vector2.ZERO
	for frame in 180:
		if frame == 60:
			tutorial._mark("jump")
		await process_frame
	print("ART_MOTION_REVIEW_RECORDED")
	quit()
