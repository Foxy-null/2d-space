extends "res://tests/stage_6_playthrough.gd"
## Geometry-only input traversal. Setup fixtures isolate new paths from combat.
func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage.set_physics_process(false)
	for number in stage.ROOM.FINAL_ROOM:
		for alternate in (["upper", "lower", "approach"] if number == 1 else ["upper", "lower"]):
			_release()
			stage._load_room(number)
			stage.enemy.set_physics_process(false)
			stage.room.set_physics_process(false)
			for item in stage.room.get_node("Items").get_children():
				item.free()
			stage._intro_left = 0.0
			stage._intro_panel.hide()
			stage.player.controls_enabled = true
			stage.room.open_passage()
			var points: Array = stage.room.passage_route.duplicate()
			if alternate == "lower":
				points = stage.room.branch_route.duplicate()
			elif alternate == "approach":
				points = stage.room.approach_route.duplicate()
			stage.player.position = points.front()
			stage.player.velocity = Vector2.ZERO
			stage.player._contacts_valid = false
			_jump_left = 0
			_dash_left = 0
			_ground_run = true
			await _step(4)
			for point: Vector2 in points:
				if not await _navigate(point, 1200):
					push_error("ROUTE_FAILED room=%d alternate=%s point=%s" % [number + 1, alternate, point])
					quit(1)
					return
			print("ROUTE_OK room=%d alternate=%s" % [number + 1, alternate])
	_release()
	print("STAGE_6_ROUTES_TEST_OK (25 input-driven routes, combat isolated)")
	quit()
