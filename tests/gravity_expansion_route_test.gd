extends "res://tests/stage_3_test.gd"

var stick := 1.0
var wind_contacts := 0
var negative_trials := 0
var progress: Node
var captured: Dictionary = {}


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_expansion_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	if OS.get_cmdline_user_args().has("--underwall-only"):
		await _underwall_bypass()
		print("GRAVITY_UNDERWALL_TEST_", "FAILED" if failed else "OK")
		quit(1 if failed else 0)
		return
	var screenshots := OS.get_cmdline_user_args().has("--screenshots")
	for strength in ([] if OS.get_cmdline_user_args().has("--scroll-only") else ([1.0] if screenshots else [1.0, 0.8])):
		stick = strength
		for index in [6, 7, 8]:
			await _fresh(index)
			await _capture("room_%d_entrance" % (index + 1))
			var started := Engine.get_physics_frames()
			await _course(index)
			if failed: break
			await _reach_goal()
			await _capture("room_%d_arrival" % (index + 1))
			if index == 6:
				await _return_seven_to_exit()
			var seconds := float(Engine.get_physics_frames() - started) / 60.0
			_check(respawns == 0 and stage.cleared.has(index) and seconds < 30, "The real entrance route clears within thirty seconds without death")
			_check(index != 8 or wind_contacts > 0, "The final route really crosses its wind")
			_check(progress.get_count("gravity") == 0, "The main route leaves the optional scroll untouched")
			print("GRAVITY_EXPANSION_ROOM_%d_SECONDS %.2f strength=%.2f" % [index + 1, seconds, stick])
			await _retry()
			_check(stage.room_index == index and stage.cleared.has(index), "R preserves each new cleared room and its current checkpoint")
			if failed: break
		if failed: break
	stick = 1.0
	if not failed and not screenshots and not OS.get_cmdline_user_args().has("--scroll-only"):
		for delay in [16, 24]:
			await _fresh(7)
			await _room_eight_course(delay)
			await _reach_goal()
			_check(respawns == 0 and stage.cleared.has(7), "Both crystal jumps tolerate an earlier or later takeoff")
	if not failed:
		await _scroll_detour()
	if not failed and not OS.get_cmdline_user_args().has("--scroll-only"):
		await _recoveries()
		if not screenshots:
			await _room_six_seam()
	if not failed and not screenshots and not OS.get_cmdline_user_args().has("--positive-only"):
		await _negative_routes()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release_inputs()
	print("GRAVITY_EXPANSION_ROUTE_TEST_%s (%d checks, %d negative trials)" % ["FAILED" if failed else "OK", checks, negative_trials])
	quit(1 if failed else 0)


func _fresh(index: int) -> void:
	_release_inputs()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage._set_room(index, false)
	player.respawn()
	await _step(4)
	actions.clear()
	respawns = 0
	wind_contacts = 0
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	player.respawned.connect(func(): respawns += 1)
	if index == 8:
		stage.rooms.get_child(index).get_node("ExitUpdraft").body_entered.connect(func(body):
			if body == player: wind_contacts += 1)
	var actual_scrolls := 0
	for room in stage.rooms.get_children():
		for node in room.find_children("*", "Area2D", true, false):
			if node.get_script() != null and node.get_script().resource_path == "res://scripts/scroll_collectible.gd": actual_scrolls += 1
	_check(actual_scrolls == progress.TOTALS["gravity"] and actual_scrolls == 8, "The placed scroll count matches the stage selection total")


func _course(index: int) -> void:
	match index:
		6: await _room_seven_course()
		7: await _room_eight_course()
		8: await _room_nine_course()


func _scroll_detour() -> void:
	await _fresh(6)
	await _capture("room_7_entrance")
	await _room_two_wall_course()
	var scroll: Area2D = stage.rooms.get_child(6).get_node("DetourScroll")
	for pending in ["retry", "death", "secure"]:
		_release_inputs()
		await _jump()
		await _step(12)
		Input.action_press("move_down")
		Input.action_press("dash")
		await _step()
		_release_inputs()
		await _until(func(): return is_instance_valid(scroll._follower), 90, "An inverted jump toward the side branch contacts the real scroll")
		if pending != "secure":
			if pending == "retry":
				await _retry()
			else:
				Input.action_press("move_right")
				await _until(func(): return player.position.x - 7680 > 680, 80, "Steer the pending scroll toward the real unsafe underside")
				_release_inputs()
				await _until(func(): return respawns > 0, 180, "The actual underside spikes cancel the unconfirmed pickup")
				await _step(4)
			_check(progress.get_count("gravity") == 0 and scroll.global_position == scroll._origin, "R or death before landing restores the unconfirmed scroll")
			respawns = 0
			await _room_two_wall_course()
		else:
			_release_inputs()
			await _until(func(): return progress.has_scroll("gravity", "inverted_return_02"), 100, "Returning to the safe underside confirms and saves the scroll")
	_check(respawns == 0 and player.is_on_floor() and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The optional round trip ends at the same safe rest with restored resources")
	await _capture("room_7_scroll")
	await _retry()
	_check(progress.get_count("gravity") == 1, "Confirmed collection survives R")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	_check(current_scene.get_node("Margin/Content/Stages/Stage3/Content/Collection/Count").text == "1 / 8", "Stage selection includes the new actual total before clearing the stage")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.has_scroll("gravity", "inverted_return_02"), "An unfinished-stage detour remains saved after leaving")


func _negative_routes() -> void:
	# Finite input sweeps complement the uninterrupted nine-room playthrough.
	await _underwall_bypass()
	if failed: return
	for index in [6, 7, 8]:
		for direction in _directions():
			for delay in [0, 20, 40]:
				await _fresh(index)
				_drive("move_right", true)
				await _step(40)
				await _jump()
				await _step(delay)
				_set_direction(direction)
				Input.action_press("dash")
				await _step()
				Input.action_release("dash")
				_drive("move_right", true)
				var reached_exit := false
				for frame in 240:
					await _step()
					reached_exit = reached_exit or (_x() > 1050 and player.is_on_floor() and player.gravity_direction == 1 and player.position.y > 500)
					if respawns > 0 or reached_exit or stage.cleared.has(index): break
				_check(not reached_exit and not stage.cleared.has(index), "Entrance Dash, outer walls and ordinary climbs cannot reach the exit landing without the transfers")
				negative_trials += 1
				if failed: return


	for extras in [0, 1]:
		for direction in _directions():
			for delay in [12, 20, 28]:
				await _fresh(7)
				await _kick_gate(240, -1)
				await _cross_ceiling_pit(330, 470)
				_drive("move_right")
				await _until(func(): return player.is_on_floor() and _x() >= 760, 180, "Reach the real upper descent launch")
				_release_inputs()
				await _step(20)
				for jump in extras + 1:
					await _jump()
					await _step(delay)
				_set_direction(direction)
				Input.action_press("dash")
				await _step()
				Input.action_release("dash")
				_drive("move_right", true)
				var reached_exit := false
				for frame in 180:
					await _step()
					reached_exit = reached_exit or (_x() > 900 and player.is_on_floor() and player.gravity_direction == 1 and player.position.y > 550)
					if respawns > 0 or reached_exit or stage.cleared.has(7): break
				_check(not reached_exit and not stage.cleared.has(7) and actions.get("air_jump", 0) < 2, "Eight-direction Dash and wall grips cannot replace either required extra jump")
				negative_trials += 1
				if failed: return


func _recoveries() -> void:
	for index in [6, 7, 8]:
		await _fresh(index)
		_drive("move_right", true)
		await _until(func(): return respawns > 0, 600, "Walking and climbing without the required transfers falls into the actual pit")
		_release_inputs()
		await _step(4)
		_check(stage.room_index == index and player.position.distance_to(stage.rooms.get_child(index).get_node("Spawn").global_position) < 5, "A real pit death returns to the correct new-room entrance")
		_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Death restores gravity and movement resources")
		_check(progress.get_count("gravity") == 1, "A real pit death preserves the previously confirmed scroll")
		if failed: return


func _directions() -> Array[Vector2]:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


func _room_six_seam() -> void:
	await _fresh(6)
	await _room_seven_course()
	await _reach_goal()
	stage._set_room(5, true)
	stage._on_arrival(5)
	stage._set_room(6, false)
	await _step(2)
	Input.action_press("move_left")
	await _until(func(): return stage.room_index == 5, 90, "The former final boundary allows actual leftward backtracking")
	_release_inputs()
	await _step(25)
	_check(player.position.distance_to(stage.rooms.get_child(5).get_node("Return").global_position) < 12, "Returning from the new room uses the former final room's safe right entrance")
	Input.action_press("move_right")
	await _until(func(): return stage.room_index == 6, 90, "The same seam opens forward again after the prior arrival")
	_release_inputs()
	await _step(25)
	_check(stage.cleared.has(6) and not stage.completed, "The former final room stays intermediate in both directions")


func _underwall_bypass() -> void:
	await _fresh(6)
	_drive("move_right")
	await _until(func(): return player.is_on_floor() and player.gravity_direction == -1 and _x() > 430, 260, "Reach the actual inverted outer-ceiling launch")
	await _jump()
	await _until(func(): return _x() > 515, 60, "Jump left of the step before attempting the descent bypass")
	_release_inputs()
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	_release_inputs()
	await _until(func(): return not player.is_dashing() and player.position.y > 300, 40, "A real downward Dash passes below the step")
	_drive("move_left", true, true)
	await _until(func(): return player.is_wall_grabbing() and _x() < 470, 80, "Catch the real outer wall below its step")
	await _until(func(): return respawns > 0, 220, "The extended outer wall cannot be mantled beneath the room")
	_release_inputs()
	_check(respawns == 1 and not stage.cleared.has(6), "The under-wall refill bypass returns safely without reaching the exit")
	negative_trials += 1


func _set_direction(direction: Vector2) -> void:
	_release_inputs()
	if direction.x != 0: Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0: Input.action_press("move_down" if direction.y > 0 else "move_up")


func _drive(direction: String, grab := false, inverted := false) -> void:
	super._drive(direction, grab, inverted)
	if stage.room_index == 6:
		direction = "move_left" if direction == "move_right" else "move_right"
	Input.action_press(direction, stick)


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-expansion")
		root.get_texture().get_image().save_png("res://docs/screenshots/gravity-expansion/%s.png" % label)


func _step(count: int = 1) -> void:
	await super._step(count)
	if not OS.get_cmdline_user_args().has("--screenshots") or not is_instance_valid(stage) or not is_instance_valid(player):
		return
	var label := ""
	if stage.room_index == 7 and _x() > 700 and player.is_on_floor() and player.position.y < 0:
		label = "room_8_upper_rest"
	elif stage.room_index == 8 and _x() > 1050 and player.is_wall_grabbing() and player.gravity_direction == -1:
		label = "room_9_wind_wait"
	elif stage.room_index == 6 and player.position.y > 640 and is_instance_valid(stage.rooms.get_child(6).get_node("DetourScroll")._follower):
		label = "room_7_scroll_descent"
	if not label.is_empty() and not captured.has(label):
		captured[label] = true
		await _capture(label)
