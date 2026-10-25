extends "res://tests/stage_5_test.gd"

var progress: Node
var bounces := 0


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	await _setup(12)
	var placed := 0
	for area in stage.find_children("*", "Area2D", true, false):
		if area.get_script() != null and area.get_script().resource_path == "res://scripts/scroll_collectible.gd": placed += 1
	_check(placed == 1 and placed == progress.TOTALS.canyon, "The selection total matches the actual placed canyon scrolls")
	for strength in [1.0, 0.8]:
		for index in [12, 13, 14]:
			await _setup(index)
			var started := Engine.get_physics_frames()
			var lowest := player.position.y
			var highest := player.position.y
			var saw_upper_room := false
			for frame in 1500:
				if stage.transitioning or stage.completed: break
				_steer(strength)
				await _step()
				lowest = maxf(lowest, player.position.y)
				highest = minf(highest, player.position.y)
				if index == 13 and not stage.transitioning and player.position.y < 400 and stage.camera.position.y < 600 and not saw_upper_room:
					saw_upper_room = true
					await _capture("room14_ascent")
				if respawns > 0 and not stage.transitioning: break
			_release_inputs()
			var seconds := float(Engine.get_physics_frames() - started) / 60
			_check(stage.transitioning or stage.completed, "The new room %d has a real input route at strength %.1f" % [index + 1, strength])
			_check(respawns == (0 if index == 14 else 1) and bounces >= 4, "The new application uses real reflections without dying")
			_check(seconds < 30, "Each new room keeps a short retry interval")
			if index == 13:
				_check(lowest > 1000 and highest < 300, "The tall room really climbs beyond a single screen")
				_check(saw_upper_room, "The camera reveals the upper room before its exit transition")
			print("CANYON_EXPANSION_ROOM_%d strength=%.1f %.2fs" % [index + 1, strength, seconds])
	_check(progress.get_count("canyon") == 0, "The mandatory routes leave the optional scroll untouched")
	await _setup(12)
	await _take_branch(0.8)
	await _land_at_rest(0.8)
	_check(progress.has_scroll("canyon", "turning_sky_01") and respawns == 0, "The complete collection branch also supports weaker horizontal input")
	progress._collected.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _setup(12)
	await _take_branch()
	_check(_scroll()._follower == player and not progress.has_scroll("canyon", "turning_sky_01"), "The optional left turn takes the airborne scroll without securing it")
	await _pulse("reset")
	await _step(6)
	_check(_scroll()._follower == null and not progress.has_scroll("canyon", "turning_sky_01"), "R restores the pending scroll")
	await _take_branch()
	stage.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(not progress.has_scroll("canyon", "turning_sky_01"), "Leaving the unfinished airborne branch does not save its scroll")
	await _setup(12)
	var started := Engine.get_physics_frames()
	await _take_branch()
	await _capture("scroll")
	await _land_at_rest()
	_check(progress.has_scroll("canyon", "turning_sky_01") and respawns == 0 and stage.room_index == 12, "The left branch returns through the third reflection to the real rest and secures its scroll")
	var seconds := float(Engine.get_physics_frames() - started) / 60
	_check(seconds < 30, "The complete collection route returns within thirty seconds")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "The branch's resting platform remains safe without input")
	await _capture("rest")
	_release_inputs()
	Input.action_press("move_left")
	Input.action_press("move_down")
	await _pulse("dash")
	for frame in 150:
		if respawns > 0: break
		await _step()
	_release_inputs()
	await _step(6)
	_check(respawns == 1 and player.is_on_floor() and stage.room_index == 12 and progress.has_scroll("canyon", "turning_sky_01"), "A real fall after confirmation retains the scroll and restores the room entrance")
	await _pulse("reset")
	await _step(6)
	_check(progress.get_count("canyon") == 1 and _scroll().modulate.a < 1, "R keeps one saved collectible and its faint revisit marker")
	stage.get_node("PauseMenu").return_to_select()
	await _step(5)
	_check(current_scene.get_node("Margin/Content/Stages/Stage5/Content/Collection/Count").text == "1 / 1", "Stage selection displays the actual canyon scroll count")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon") == 1, "The unfinished canyon's confirmed scroll survives reloading")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release_inputs()
	print("CANYON_EXPANSION_ROUTE_TEST_%s (%d checks, branch %.2fs)" % ["FAILED" if failed else "OK", checks, seconds])
	quit(1 if failed else 0)


func _setup(index: int) -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_5.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage.room_index = index
	stage._set_checkpoint()
	player.respawn()
	await _step(6)
	respawns = 0
	bounces = 0
	player.respawned.connect(func(): respawns += 1)
	for bumper in stage._bumpers().get_children():
		bumper.launched.connect(func(_body): bounces += 1)
	await _capture("room%d_entrance" % (index + 1))


func _take_branch(strength: float = 1.0) -> void:
	var before := respawns
	for frame in 500:
		if stage.next_bumper >= 2: break
		_steer(strength)
		await _step()
	_check(stage.next_bumper == 2 and respawns == before, "The branch begins after two real reflections from the room entrance")
	for frame in 240:
		if _scroll()._follower == player: break
		_steer_to(_scroll().position, false, strength)
		await _step()
	_release_inputs()
	_check(_scroll()._follower == player and respawns == before, "Steering left above the main reflection really touches the optional scroll")


func _land_at_rest(strength: float = 1.0) -> void:
	for frame in 500:
		if progress.has_scroll("canyon", "turning_sky_01"): break
		if stage.next_bumper < 3:
			_steer(strength)
		else:
			_steer_to(Vector2(780, 634), false, strength)
		await _step()
	_release_inputs()
	await _step(15)


func _scroll() -> Area2D:
	return stage.rooms.get_child(12).get_node("Scroll")


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/canyon-expansion")
		root.get_texture().get_image().save_png("res://docs/screenshots/canyon-expansion/%s.png" % label)
