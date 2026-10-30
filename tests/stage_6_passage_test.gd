extends "res://tests/stage_6_playthrough.gd"
## Start at each real switch; then traverse with normal inputs and active course hazards.


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage._intro_left = 0.0
	stage._intro_panel.hide()
	var results: Array[Dictionary] = []
	for number in stage.ROOM.FINAL_ROOM:
		var passed := false
		for attempt in 3:
			_release()
			stage._load_room(number)
			stage.enemy.set_physics_process(false)
			stage.player.position = stage.room.exit_position - Vector2(0, 118)
			stage._previous_player = stage.player.position
			stage.player.velocity = Vector2.ZERO
			await _step(50)
			if not stage.room.exit_open:
				push_error("Switch did not open passage %d" % (number + 1))
				quit(1)
				return
			_jump_left = 0
			_dash_left = 0
			print("PASSAGE_BEGIN ", number + 1, " attempt=", attempt + 1)
			passed = await _play_passage()
			if passed:
				results.append({"room": number + 1, "title": stage.ROOM.PASSAGE_TITLES[number], "attempts": attempt + 1})
				break
		if not passed:
			push_error("Passage %d failed under normal inputs" % (number + 1))
			quit(1)
			return
		print("PASSAGE_OK ", number + 1)
	_release()
	DirAccess.make_dir_recursive_absolute("res://deliverables/stage6-course-feedback")
	FileAccess.open("res://deliverables/stage6-course-feedback/passages.json", FileAccess.WRITE).store_string(JSON.stringify({"scope": "各室の到着台から開始。敵AIを停止し、コースの移動ギミックは動かして通常入力で通過。通し攻略や人の評価ではない。", "rooms": results}, "\t"))
	print("STAGE_6_PASSAGE_TEST_OK (12 passages)")
	quit()
