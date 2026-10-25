extends "res://tests/tutorial_launch_scroll_test.gd"


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://tutorial_launch_required_%d.cfg" % OS.get_process_id()
	_clear_progress()
	await _new_tutorial()
	var routes := 0
	for index in [6, 7]:
		strength = 1
		var mechanic := tutorial.rooms.get_child(index).get_node("FloorSpring" if index == 6 else "Pinball") as Area2D
		mechanic.collision_mask = 0
		for launch in [72, 230, 330 if index == 6 else 400]:
			for delay in [0, 24]:
				for grounded_dash in [false, true]:
					for direction in [Vector2.RIGHT, Vector2(1,-1), Vector2.UP, Vector2(-1,-1), Vector2.LEFT, Vector2(-1,1), Vector2.DOWN, Vector2(1,1)]:
						await _enter(index)
						await _move_to(launch)
						_check(player.is_on_floor() and player.is_dash_ready(), "The finite omission attempt starts on an actual original floor with a fresh Dash")
						if grounded_dash:
							Input.action_press("move_right")
							await _pulse("dash")
							await _step(4)
						await _pulse("jump")
						await _step(delay)
						_release()
						if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left")
						if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")
						await _pulse("dash")
						_check(not await _reaches_launch_loft_or_goal(index) and launch_counts[index] == 0, "The new shelf cannot replace the original launch: room=%d x=%d delay=%d groundDash=%s direction=%s" % [index+1, launch, delay, grounded_dash, direction])
						routes += 1
		mechanic.collision_mask = 1
		for axis in [1.0, 0.8, 0.4]:
			strength = axis
			for delay in [0, 16, 24]:
				await _enter(index)
				Input.action_press("move_right", strength)
				_check(is_equal_approx(Input.get_axis("move_left", "move_right"), strength), "The no-Dash comparison uses its actual analog action strength")
				await _until(func(): return launch_counts[index] > 0, 240, "The no-Dash comparison receives a real Spring or reflection")
				await _step(delay)
				await _pulse("jump")
				var reached := false
				for frame in 240:
					if respawns > 0 or tutorial.room_index != index: break
					_steer(950 if index == 6 else 140)
					Input.action_release("jump")
					if player.is_on_floor() and frame % 12 == 0: Input.action_press("jump")
					reached = reached or _scroll()._follower == player
					await _step()
				_check(not reached and not progress.has_scroll("tutorial", _launch_id(index)), "Launch momentum and real repeated floor Jumps cannot replace the optional upward Dash")
				routes += 1
	_release()
	_clear_progress()
	print("TUTORIAL_LAUNCH_REQUIRED_TEST_%s (%d checks, %d finite routes)" % ["FAILED" if failed else "OK", checks, routes])
	quit(1 if failed else 0)


func _reaches_launch_loft_or_goal(index: int) -> bool:
	for frame in 180:
		if respawns > 0 or tutorial.room_index != index: return false
		if _floor_named("ScrollDetour/Loft") or _floor_named("SpringLanding" if index == 6 else "Landing") or tutorial.cleared.has(index) or _scroll()._follower == player or progress.has_scroll("tutorial", _launch_id(index)):
			return true
		_steer(950 if index == 6 else 140)
		Input.action_press("wall_grab")
		await _step()
	return false
