extends "res://tests/gravity_room_three_jump_test.gd"

var roof_steps := 0


func _run() -> void:
	for delay in [16, 20, 24]:
		raw = 1.0
		await _prepare_room()
		_drive("move_right", true)
		await _until(func(): return player.is_on_floor() and player.position.y < 410 and _x() > 240, 180, "The roof attempt climbs the real launch-wall cap")
		_check(respawns == 0 and player.gravity_direction == 1, "The attempt starts above the real cap without gravity reversal")
		_drive("move_right")
		await _jump()
		await _step(delay)
		_aim(Vector2.UP)
		await _dash()
		_drive("move_right", true)
		var reached_roof := false
		for frame in 260:
			if respawns > 0:
				break
			if player.is_on_floor() and player.position.y < 100:
				reached_roof = true
				roof_steps += 1
				break
			await _step()
		if reached_roof:
			var supported := false
			for index in player.get_slide_collision_count():
				supported = supported or player.get_slide_collision(index).get_collider() == stage.rooms.get_child(2).get_node("MiddleCeiling")
			_check(supported and player.is_dash_ready() and player.gravity_direction == 1, "The actual middle roof physically supports the player and refills Dash without a gate")
			_drive("move_left")
			await _until(func(): return _x() <= 483, 100, "Brake on the actual middle roof")
			_release_inputs()
			await _step(20)
			raw = 0.55
			_drive("move_left")
			await _until(func(): return _x() < 451, 180, "Leave the actual roof edge with weak left input")
			raw = 1.0
			_drive("move_right")
			for frame in 180:
				if player.position.y >= 630 or respawns > 0:
					break
				await _step()
			if respawns == 0:
				_aim(Vector2(1, -1))
				await _dash()
				_drive("move_right", true)
				for frame in 300:
					alternative_landed = alternative_landed or _on_exit_floor()
					if respawns > 0 or alternative_landed or stage.cleared.has(2):
						break
					await _step()
		_release_inputs()
		_check(not alternative_landed and not stage.cleared.has(2) and not actions.has("air_jump"), "The confirmed roof refill, left drop and late diagonal Dash cannot reach the exit")
		_check(not reached_roof and respawns == 1 and _at_spawn(), "The higher roof prevents its refill and safely restores the current checkpoint")
		print("ROOM3_ROOF delay=%d roof=%s deaths=%d" % [delay, reached_roof, respawns])
	print("GRAVITY_ROOM_THREE_ROOF_TEST_%s (%d checks, roof_steps=%d)" % ["FAILED" if failed else "OK", checks, roof_steps])
	_release_inputs()
	stage.queue_free()
	await _step(3)
	quit(1 if failed else 0)
