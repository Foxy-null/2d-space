extends "res://tests/canyon_inverted_route_test.gd"

const LEFT_ROOMS := [15, 17, 19, 22, 25, 28]


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	await _setup(0)
	_check(player.facing_direction == 1, "A right-going room starts facing its course")
	var left_rooms: Array[int] = []
	for room in stage.rooms.get_children():
		if room.get_meta("exit_left", false): left_rooms.append(room.get_index())
	_check(left_rooms == LEFT_ROOMS, "The entrance regression covers every left-going canyon room")
	for strength in [1.0, 0.8]:
		for index in LEFT_ROOMS:
			await _entrance(index, strength)
			if failed: return
	await _continuous_entrance()
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_NAVIGATION_TEST_OK (", checks, " checks)")
	quit()


func _entrance(index: int, strength: float) -> void:
	await _setup(index)
	var facing: int = player.facing_direction
	Input.action_press("move_right", strength)
	_check(is_equal_approx(Input.get_axis("move_left", "move_right"), strength), "The mistaken entrance input uses the actual reported strength")
	await _step(120)
	_release_inputs()
	_check(respawns == 0 and stage.room_index == index and not stage.transitioning, "Holding right meets terrain without a retry or transfer: room%d strength=%.1f retries=%d" % [index + 1, strength, respawns])
	if failed: return
	_check(facing == -1, "A left-going entrance initially faces left: room%d" % [index + 1])
	_check(player.is_on_wall() and player.get_wall_normal().x < -0.8, "The entrance's back side is a physical wall")
	if strength == 1.0: await _capture("room%d_backstop" % [index + 1])
	var start := _x()
	Input.action_press("move_left", strength)
	for frame in 60:
		await _step()
		if start - _x() > 60 or respawns > 0: break
	_release_inputs()
	_check(start - _x() > 60 and respawns == 0 and stage.room_index == index, "Turning left safely steps into the real course")
	var before_reset := respawns
	await _pulse("reset")
	await _step(6)
	_check(respawns == before_reset + 1 and player.position.distance_to(stage.rooms.get_child(index).get_node("Spawn").global_position) < 5 and player.facing_direction == -1, "R restores this entrance and its left-facing direction")


func _continuous_entrance() -> void:
	await _course(24, 1.0, 20)
	if failed: return
	_check(stage.room_index == 25 and stage.transitioning and respawns == 1 and player.facing_direction == -1, "The real room25 route transfers into room26 facing left")
	var before := respawns
	Input.action_press("move_right")
	await _step(240)
	_release_inputs()
	_check(stage.room_index == 25 and respawns == before and not stage.transitioning and player.controls_enabled, "Holding right across the real transition never enters a respawn loop")
	_check(player.is_on_wall() and player.get_wall_normal().x < -0.8, "The real transition ends against entrance terrain")


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or stage.room_index not in [15, 25, 28]: return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-navigation")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/canyon-navigation/%s.png" % label) == OK, "Save the native entrance and course-side terrain")
