extends "res://tests/stage_5_test.gd"

var bounces := 0


func _run() -> void:
	for strength in [1.0, 0.85]:
		await _first_room()
		await _screenshot(1)
		var frames := 0
		while stage.room_index == 0 and respawns == 0 and frames < 600:
			_steer()
			if stage.next_bumper == 0:
				Input.action_release("jump")
			for action in ["move_left", "move_right"]:
				if Input.is_action_pressed(action):
					Input.action_press(action, strength)
			await _step()
			frames += 1
		_release_inputs()
		_check(stage.room_index == 1 and bounces > 0, "Walking down from the entrance naturally starts a successful bumper crossing")
		_check(frames <= 600, "The first crossing takes at most ten seconds")
		print("STAGE_5_ENTRY_CROSSING %.2fs strength=%.2f" % [frames / 60.0, strength])
	await _first_room()
	for bumper in stage._bumpers().get_children():
		bumper.monitoring = false
	# Deny the featured mechanic, then try ordinary jumps, superdash and delayed eight-way dashes.
	for launch_x in [90, 135, 170]:
		for delay in [0, 12, 24, 36, 48, 60]:
			for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
				_release_inputs()
				player.respawn()
				await _step(3)
				respawns = 0
				Input.action_press("move_right")
				while player.position.x < launch_x:
					await _step()
				Input.action_press("jump")
				for frame in 260:
					Input.action_release("dash")
					Input.action_release("move_up")
					Input.action_release("move_down")
					Input.action_release("move_left")
					Input.action_press("move_right")
					if frame == delay and not direction.is_zero_approx():
						Input.action_release("move_right")
						if direction.x != 0:
							Input.action_press("move_right" if direction.x > 0 else "move_left")
						if direction.y != 0:
							Input.action_press("move_down" if direction.y > 0 else "move_up")
						Input.action_press("dash")
					await _step()
					if respawns > 0 or stage.room_index != 0:
						break
				_check(stage.room_index == 0 and not stage.transitioning, "A jump/dash without any bumper cannot reach the exit: x%d delay%d %s" % [launch_x, delay, direction])
	_release_inputs()
	player.respawn()
	await _step(15)
	_check(player.position.distance_to(stage.get_node("Rooms/Room1/Spawn").position) < 5 and player.is_dash_ready(), "Retry restores the raised entrance and dash")
	_check(bounces == 0, "The negative traversal never received a bumper launch")
	print("STAGE_5_ENTRY_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _first_room() -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	respawns = 0
	bounces = 0
	player.respawned.connect(func(): respawns += 1)
	for bumper in stage._bumpers().get_children():
		bumper.launched.connect(func(_body): bounces += 1)
