extends "res://tests/stage_6_playthrough.gd"
## Scroll routes use normal inputs from checkpoint landmarks, with pursuit disabled.

var checks := 0


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://stage6_collection_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	progress._cleared.clear()
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(300)
	stage = current_scene
	var rooms: Array[int] = []
	var ids: Array[String] = []
	for number in stage.ROOM.ROOM_COUNT:
		stage._load_room(number)
		stage.enemy.set_physics_process(false)
		var scroll: Area2D = stage.room.scroll
		if scroll == null:
			continue
		rooms.append(number)
		_check(scroll.stage_id == "chaser" and scroll.scroll_id not in ids, "Each stage 6 scroll has a unique stable save ID")
		ids.append(scroll.scroll_id)
		_check(Rect2(Vector2.ZERO, stage.room.size).has_point(scroll.position), "Collectible stays within the unchanged room bounds")
		stage.enemy.position = scroll.position
		scroll._on_body_entered(stage.enemy)
		await _step(3)
		_check(scroll._follower == null and progress.get_count("chaser") == 0, "The pursuer cannot pick up or save the player collectible")
	_check(rooms == [0, 3, 5, 7, 9, 12] and ids.size() == progress.TOTALS.chaser, "Exactly six optional scrolls match the displayed total")
	stage._load_room(0)
	stage.enemy.set_physics_process(false)
	stage.player.set_physics_process(false)
	var origin: Vector2 = stage.room.scroll.position
	stage.player.position = origin
	stage.room.scroll._on_body_entered(stage.player)
	_check(stage.room.scroll._follower == stage.player and progress.get_count("chaser") == 0, "Airborne touch is pending rather than instantly saved")
	stage.retry_room()
	_check(stage.room.scroll._follower == null and stage.room.scroll.position == origin and progress.get_count("chaser") == 0, "Checkpoint retry returns the unconfirmed scroll to its original position")
	stage.player.set_physics_process(true)
	for number in rooms:
		_release()
		_jump_left = 0
		_dash_left = 0
		stage._load_room(number)
		stage.enemy.set_physics_process(false)
		if number != stage.ROOM.FINAL_ROOM:
			stage.player.position = stage.room.exit_position - Vector2(0, 118)
			stage._previous_player = stage.player.position
			await _step(50)
			_check(stage.room.exit_open, "Real arrival opens the room before its optional collection route")
		var scroll: Area2D = stage.room.scroll
		var x: float = stage.room.size.x - 1000
		var y: float = stage.room.exit_position.y
		var route: Array[Vector2] = []
		match number:
			0:
				route.assign([Vector2(x + 150, y - 26), Vector2(x + 350, y - 110)])
			3:
				_check(await _acquire("PARACHUTE"), "The wind route uses its real umbrella supply")
				route.assign([Vector2(x + 255, y - 170), Vector2(x + 540, y - 150)])
			5:
				route.assign([Vector2(x + 150, y - 26), Vector2(x + 400, y - 110)])
			7:
				route.assign([Vector2(x + 150, y - 26), Vector2(x + 280, y - 160)])
			9:
				route.assign([Vector2(x + 100, y - 26)])
			12:
				route.assign([Vector2(540, 1130), Vector2(800, 990), Vector2(1140, 830)])
		for target in route:
			_check(await _navigate(target, 950), "Normal-input scroll route reaches room %d waypoint %s" % [number + 1, target])
		_check(await _navigate(scroll.position + Vector2(0, 34), 950, true), "The collectible route ends on its actual landing platform")
		_release_movement()
		await _step(55)
		print("COLLECTION_LANDING room=", number+1, " player=",stage.player.position," floor=",stage.player.is_on_floor(), " scroll=",scroll.position," secured=",scroll._secured," follower=",scroll._follower," count=",progress.get_count("chaser"))
		_check(scroll._secured and progress.has_scroll("chaser", scroll.scroll_id), "A real safe landing secures the optional scroll in room %d" % (number + 1))
		stage.retry_room()
		_check(scroll._secured and scroll.modulate.a == 0.25, "A secured scroll stays collected after checkpoint retry")
		print("COLLECTION_ROUTE_OK ", number + 1)
	_release()
	_check(progress.get_count("chaser") == 6, "Every optional route contributes once to the six-scroll total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("chaser") == 6, "Collection survives reloading the save file")
	stage._load_room(0)
	_check(stage.room.scroll._secured, "Rebuilt rooms retain their collected state")
	stage._update_hud()
	_check(stage._collection.text == "巻物 6/6", "The stage HUD shows the persisted total")
	stage._clear_feedback()
	stage.free()
	stage = null
	change_scene_to_file("res://scenes/gallery.tscn")
	await _step(4)
	current_scene._select(current_scene.ENTRIES.size() - 1)
	_check(current_scene.description.text.contains("6 / 6") and current_scene.preview_world.get_child(0).has_method("_secure"), "Gallery uses the actual scroll scene and displays the saved stage 6 count")
	_check(progress.get_count("chaser") == 6, "Viewing a gallery preview cannot change collection progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("STAGE_6_COLLECTION_TEST_OK (%d checks)" % checks)
	quit()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
