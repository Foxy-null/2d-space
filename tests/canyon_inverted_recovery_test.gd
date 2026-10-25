extends "res://tests/canyon_inverted_route_test.gd"


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	for index in [27,28,29]:
		monitor_view = false
		await _setup(index)
		await _inverted_begin(0.8)
		_check(player.gravity_direction == -1,"The real Up gate changed gravity before reset")
		await _pulse("reset")
		await _step(12)
		_checkpoint(index,1)
		if failed: return
		await _inverted_begin(0.8)
		_release_inputs()
		Input.action_release("wall_grab")
		var room: Node2D = stage.rooms.get_child(index)
		var escape := "move_right" if room.get_meta("exit_left",false) else "move_left"
		Input.action_press(escape,0.8)
		for frame in 360:
			if respawns > 1: break
			await _step()
		_release_inputs()
		await _step(12)
		_checkpoint(index,2)
		if failed: return
		stage.set_hints_visible(true)
		monitor_view = true
		await _inverted_main(0.8,24)
		monitor_view = false
		_check((stage.completed and respawns==2) if index==29 else (stage.transitioning and stage.room_index==index+1 and respawns==3),"A weak-input native replay reaches its actual exit after R and death")
		if failed: return
	for index in [27,28,29]:
		for name in ["ExitRoof","ExitUpper","ExitLower"]:
			await _setup(index)
			var room: Node2D = stage.rooms.get_child(index)
			var barrier: Area2D = room.get_node("Hazards/"+name)
			var hits: Array[bool] = []
			barrier.player_hit.connect(func(): hits.append(true))
			var direction := 1.0 if room.get_meta("exit_left",false) else -1.0
			# Only this isolated hazard fixture sets position; the replay above uses real input.
			player.global_position = barrier.global_position + Vector2(direction*(380 if name=="ExitRoof" else 130),0)
			player.velocity = Vector2.ZERO
			player._contacts_valid = false
			Input.action_press("move_right" if direction<0 else "move_left")
			await _pulse("dash")
			for frame in 60:
				if respawns > 0: break
				await _step()
			_release_inputs()
			await _step(12)
			_check(hits.size()==1 and not stage.completed and not stage.transitioning,"The visible "+name+" produces one real hazard contact without exiting")
			_checkpoint(index,1)
			if failed: return
	_release_inputs()
	current_scene.queue_free()
	await _step(6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_INVERTED_RECOVERY_TEST_OK (",checks," checks)")
	quit()


func _checkpoint(index: int, expected: int) -> void:
	var room: Node2D = stage.rooms.get_child(index)
	_check(respawns==expected and stage.room_index==index and stage.next_bumper==0,"Only the current checkpoint and reflection guide reset")
	_check(player.global_position.distance_to(room.get_node("Spawn").global_position)<8 and player.is_on_floor() and player.controls_enabled,"The real checkpoint has a supported controllable entrance")
	_check(player.gravity_direction==1 and player.is_dash_ready() and is_equal_approx(player.get_wall_stamina(),player.wall_stamina_max),"The retry restores normal gravity, dash and stamina")
	if index==29:
		_check(player.get_held_object()==null and room.get_node("Items/Parachute").position.distance_to(Vector2(160,1655))<3,"The same native parachute returns to the entrance")
