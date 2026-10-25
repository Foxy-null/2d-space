extends "res://tests/stage_2_test.gd"

func _run() -> void:
	var first := 12
	var quick := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): first = int(arg.trim_prefix("--section=")) - 1
		if arg == "--strong": quick = true
	var profiles := [[1.0,20],[0.85,16],[0.85,24]]
	if quick: profiles = [[1.0,20]]
	for profile in profiles:
		_release()
		upper_strength = profile[0]
		upper_jump_delay = profile[1]
		upper_dash_delay = profile[1]
		Input.action_press("move_right", upper_strength)
		_check(is_equal_approx(Input.get_axis("move_left", "move_right"), upper_strength), "Programmatic action strength is the actual movement axis")
		_release()
		change_scene_to_file("res://scenes/stage_2.tscn")
		await _step(6)
		stage = current_scene
		player = stage.player
		player.respawned.connect(func():respawns += 1)
		stage._set_checkpoint(first)
		player.respawn()
		await _step(8)
		respawns = 0
		print("TOWER_MORE_PROFILE axis=",upper_strength," delay=",upper_jump_delay)
		for section in range(first, 18):
			await _more_course(section)
			if failed or respawns > 0:break
		_check(stage.completed and respawns == 0, "All six new sections form a continuous physical route")
		if failed:break
		current_scene.queue_free()
		await _step(3)
		OS.delay_msec(100)
	_release()
	print("TOWER_MORE_ROUTE_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)
