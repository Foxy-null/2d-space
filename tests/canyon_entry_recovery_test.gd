extends "res://tests/canyon_entry_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	for index in [24, 25, 26]:
		await _setup(index)
		await _entry_begin()
		if failed: return
		await _pulse("reset")
		Input.action_release("wall_grab")
		await _step(10)
		_check_checkpoint(index, 1)
		if failed: return
	for index in [23, 24, 25, 26]:
		await _setup(index)
		var room: Node2D = stage.rooms.get_child(index)
		var barrier: Area2D = room.get_node("Hazards/ExitLower" if index == 23 else "Hazards/ExitLower1")
		var hits: Array[bool] = []
		barrier.player_hit.connect(func(): hits.append(true))
		# Position only this isolated boundary fixture; route proofs use real entrances.
		var left: bool = room.get_meta("exit_left", false)
		player.global_position = barrier.global_position + Vector2(120 if left else -120, 0)
		player.velocity = Vector2.ZERO
		player._contacts_valid = false
		Input.action_press("move_left" if left else "move_right")
		await _pulse("dash")
		for frame in 60:
			if respawns > 0: break
			await _step()
		_release_inputs()
		Input.action_release("wall_grab")
		await _step(10)
		_check(hits.size() == 1 and not stage.transitioning and not stage.completed, "The visible lower boundary causes exactly one real spike hit without advancing the room")
		_check_checkpoint(index, 1)
		await _pulse("jump")
		await _step(12)
		_check(player.velocity.y < 0, "A real jump works immediately after the spike respawn")
		await _pulse("reset")
		await _step(10)
		_check_checkpoint(index, 2)
		if failed: return
	_release_inputs()
	current_scene.queue_free()
	await _step(6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_ENTRY_RECOVERY_TEST_OK (", checks, " checks)")
	quit()


func _check_checkpoint(index: int, expected_respawns: int) -> void:
	var room: Node2D = stage.rooms.get_child(index)
	_check(respawns == expected_respawns and stage.room_index == index and stage.next_bumper == 0, "The actual reset restores only this checkpoint and reflection guidance")
	_check(player.position.distance_to(room.get_node("Spawn").global_position) < 8 and player.is_on_floor() and player.controls_enabled, "The restored player stands safely at the native entrance")
	_check(player.is_dash_ready() and is_equal_approx(player.get_wall_stamina(), player.wall_stamina_max), "The checkpoint restores both movement resources")
	if index == 26:
		_check(player.get_held_object() == null and room.get_node("Items/Parachute").position.distance_to(Vector2(160, 1655)) < 3, "The actual parachute returns to its native entrance after the reset")
