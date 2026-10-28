extends "res://tests/stage_3_test.gd"


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://stage_3_navigation_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	var indices := [0, 6, 22, 23, 36] if screenshots else range(stage.rooms.get_child_count())
	for index in indices:
		var room: Node2D = stage.rooms.get_child(index)
		var direction: int = stage._exit_direction(room)
		_check(signf(room.get_node("Goal").position.x - room.get_node("Spawn").position.x) == direction, "The exit agrees with the actual course in room%d" % [index+1])
		for strength in ([1.0] if screenshots else [1.0, 0.8]):
			stage.cleared.clear()
			stage.completed = false
			stage._set_room(index, false)
			player.respawn()
			await _step(4)
			_check(player.facing_direction == direction, "The native entrance faces the first safe action")
			await _capture_navigation(index, "entrance")
			Input.action_press("move_left" if direction > 0 else "move_right", strength)
			await _step(40)
			_release_inputs()
			_check(stage.room_index == index and player.is_on_floor() and player.is_on_wall(), "Walking behind the entrance stops at visible terrain without returning")
			await _retry()
			_check(player.facing_direction == direction, "R restores the course-facing direction")
			if index > 0:
				# Isolate navigation from earning arrival, covered by the continuous playthrough.
				stage.cleared[index-1] = true
				para_strength = strength
				await _cross_room_boundary(false)
				var previous: Node2D = stage.rooms.get_child(index-1)
				_check(player.position.distance_to(previous.get_node("Return").global_position) < 5, "An intentional jump back reaches the preceding arrival floor")
				_check(player.facing_direction == -stage._exit_direction(previous), "Backtracking faces into the preceding room")
				await _retry()
				_check(player.position.distance_to(previous.get_node("Return").global_position) < 5, "R preserves the chosen return checkpoint")
			stage._set_room(index, false)
			player.respawn()
			await _step(3)
			stage._on_arrival(index)
			player.set_respawn_position(room.get_node("Return").global_position)
			player.respawn()
			await _step(4)
			_check(player.is_on_floor(), "The exit-side return checkpoint is supported by its real floor")
			await _capture_navigation(index, "arrival")
			if index < stage.rooms.get_child_count()-1:
				para_strength = strength
				var started := Engine.get_physics_frames()
				await _cross_room_boundary()
				if index in [22, 23, 24, 26, 28]:
					_check(Engine.get_physics_frames()-started < 110, "Room%d exits at the arrival floor instead of crossing empty space" % [index + 1])
				_check(stage.cleared.has(index), "Forward passage preserves the actual cleared room")
			else:
				Input.action_press("move_left", strength)
				await _step(90)
				_release_inputs()
				_check(stage.room_index == index and stage.completed and player.is_on_wall(), "The final left endpoint stays closed after completion")
			if failed:
				quit(1)
				return
	_release_inputs()
	current_scene.queue_free()
	await _step(4)
	if FileAccess.file_exists(progress.save_path):
		DirAccess.remove_absolute(progress.save_path)
	print("STAGE_3_NAVIGATION_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _capture_navigation(index: int, phase: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or index not in [0, 6, 22, 23, 36]:
		return
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-3-navigation")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/stage-3-navigation/room_%d_%s.png" % [index+1, phase]) == OK, "Capture the native terrain with hints hidden")
