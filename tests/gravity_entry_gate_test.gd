extends "res://tests/stage_3_test.gd"


func _run() -> void:
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	var gate: Area2D = stage.rooms.get_child(0).get_node("UpGate")
	var collision: CollisionShape2D = gate.get_node("CollisionShape2D")
	var gate_rect := Rect2(collision.global_position - collision.shape.size * 0.5, collision.shape.size)
	var directions := [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for jump_first in [false, true]:
		for direction in directions:
			for delay in [0, 8, 16, 24]:
				await _try_wall_top(jump_first, direction, delay)
				if failed:
					quit(1)
					return
	_check(gate_rect.position.y < -52 and gate_rect.end.y >= 720, "The visible gate spans the legal floor and ceiling bypasses")
	_release_inputs()
	await _retry()
	_check(flips.has(-1), "The real bypass attempts encountered inverted gravity")
	_check(not stage.cleared.has(0), "Retrying the first gate does not clear the arrival switch")
	print("GRAVITY_ENTRY_GATE_TEST_%s (%d checks, 72 wall-top routes)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _try_wall_top(jump_first: bool, direction: Vector2, delay: int) -> void:
	_release_inputs()
	player.respawn()
	await _step(3)
	flips.clear()
	var before := respawns
	_drive("move_right", true)
	await _until(func(): return player.is_on_floor() and _x() > 640 and player.position.y < 400, 500,
		"Reach the elevated takeoff through actual wall climbing")
	_drive("move_right")
	if jump_first:
		await _jump()
	await _step(delay)
	if direction != Vector2.ZERO:
		_release_inputs()
		if direction.x != 0:
			Input.action_press("move_right" if direction.x > 0 else "move_left")
		if direction.y != 0:
			Input.action_press("move_down" if direction.y > 0 else "move_up")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		await _step(10)
		_drive("move_right")
	for frame in 360:
		if flips.has(-1) or respawns > before or _x() > 920:
			break
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		await _step()
	_check(not (_x() > 920 and flips.is_empty()),
		"No elevated route may bypass Up gravity (jump=%s, direction=%s, delay=%d)" % [jump_first, direction, delay])
	_check(not stage.cleared.has(0), "The attempted shortcut must not clear the arrival switch")
