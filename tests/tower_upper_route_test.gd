extends "res://tests/stage_2_test.gd"


func _run() -> void:
	if OS.get_cmdline_user_args().has("--visual-only"):
		await _visual_stops()
		return
	var profiles := [[1.0, 20], [0.85, 16], [0.85, 24]]
	if OS.get_cmdline_user_args().has("--screenshots"):
		profiles = [[1.0, 20]]
	for profile in profiles:
		upper_strength = profile[0]
		upper_jump_delay = profile[1]
		upper_dash_delay = profile[1]
		change_scene_to_file("res://scenes/stage_2.tscn")
		await _step(6)
		stage = current_scene
		player = stage.player
		player.respawned.connect(func(): respawns += 1)
		stage._set_checkpoint(6)
		player.respawn()
		await _step(6)
		respawns = 0
		for section in range(6, 12):
			await _upper_capture("entrance-%02d" % (section + 1))
			await _upper_course(section)
			if failed:
				quit(1)
				return
		_check(respawns == 0 and stage.completed, "The upper six sections are a real continuous route at strength %s and timing %s" % profile)
		await _upper_capture("summit")
	print("TOWER_UPPER_ROUTE_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)


func _visual_stops() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	stage = current_scene
	player = stage.player
	for checkpoint in range(6, 12):
		stage._set_checkpoint(checkpoint)
		player.respawn()
		await _step(20)
		_check(player.is_on_floor(), "Each visual fixture rests on a real checkpoint")
		await _upper_capture("entrance-%02d" % (checkpoint + 1))
	for stop in [[7, Vector2(365, -5228), "spring-branch-entrance"], [7, Vector2(-230, -5228), "spring-scroll"], [11, Vector2(198, -9568), "wind-branch-entrance"], [11, Vector2(-260, -9568), "wind-scroll"], [11, Vector2(500, -10728), "summit"]]:
		stage._set_checkpoint(stop[0])
		player.respawn()
		player.position = stop[1]
		stage._on_respawned()
		await _step(20)
		_check(player.is_on_floor(), "The visual branch/summit fixture has real floor contact")
		await _upper_capture(stop[2])
	print("TOWER_UPPER_VISUAL_TEST_", "FAILED" if failed else "OK")
	quit(1 if failed else 0)
