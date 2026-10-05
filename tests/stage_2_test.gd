extends SceneTree

var checks := 0
var failed := false
var course: Node
var player: PlayerController
var retries := 0
var refills := 0
var launches := 0
var dashes := 0
var superdashes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(3)
	course = current_scene
	player = course.player
	player.respawned.connect(func(): retries += 1)
	player.movement_action.connect(func(action):
		if action == "dash":
			dashes += 1
		elif action == "superdash":
			superdashes += 1)
	await _step(3)
	_check(course.rooms.get_child_count() == 5, "The course has five rooms")
	_check(player.dash_enabled and player.wall_actions_enabled and player.is_dash_ready(), "Movement abilities are available immediately")
	for room in course.rooms.get_children():
		var goal: ArrivalSwitch = room.get_node("Goal")
		_check(not goal.locked and goal.get_node("Case/Collision").disabled, "Arrival switches start unlocked without lesson requirements")
		for node in room.find_children("*", "Area2D", true, false):
			if node.has_signal("collected"):
				node.collected.connect(func(_body): refills += 1)
			if node.has_signal("launched"):
				node.launched.connect(func(_body): launches += 1)
	# An actual fall must retry only the current room.
	player.position.y = 800
	await _step(3)
	_check(course.room_index == 0 and retries == 1 and course.cleared.is_empty(), "Falling returns to the current room without clearing it")
	_check(player.position.distance_to(course.rooms.get_child(0).get_node("Spawn").global_position) < 2, "Retry uses the room entrance")
	# The closed exit must also block a player climbing above the visible screen.
	player.position = Vector2(1234, -26)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await _step(15)
	_release_inputs()
	_check(player.position.x < 1280 and course.cleared.is_empty(), "A closed exit cannot be crossed above the screen")
	player.respawn()
	await _step(3)
	for index in 5:
		_check(course.room_index == index, "The next room begins in order")
		_check(course.camera.position == Vector2(index * 1280 + 640, 360), "Camera settles on the active room")
		await _screenshot("room-%d" % (index + 1))
		var retries_before := retries
		var refills_before := refills
		var launches_before := launches
		await _run_room(index)
		_check(retries == retries_before, "Room %d can be completed with normal jumps and horizontal dashes" % (index + 1))
		_check(course.cleared.has(index), "Standing on the actual arrival switch clears room %d" % (index + 1))
		if index == 2:
			_check(refills > refills_before, "Room 3 physically collects a dash refill in flight")
		if index >= 3:
			_check(launches > launches_before, "Spring rooms physically launch the player")
		if index < 4:
			Input.action_press("move_right")
			for frame in 180:
				if course.room_index != index:
					break
				await _step()
			_release_inputs()
			await _step(35)
	_check(dashes >= 5, "The continuous route uses dashes")
	_check(superdashes == 0, "The entire course can be completed without Superdash")
	_check(course.completed and course.get_node("HUD/Completion").visible, "The fifth switch displays stage completion")
	await _step(60)
	_check(is_instance_valid(course) and player.controls_enabled and course.room_index == 4, "Completion keeps the course playable")
	await _screenshot("clear")
	# Reset after collecting the final room's crystal restores it and preserves completion.
	var crystal: Area2D = course.rooms.get_child(4).get_node("Crystal1")
	player.position = crystal.global_position
	player.velocity = Vector2.ZERO
	await _step(2)
	_check(not crystal.visible, "The reset probe physically consumes the crystal")
	Input.action_press("reset")
	await _step()
	_release_inputs()
	await _step(3)
	_check(course.room_index == 4 and crystal.visible and player.is_dash_ready(), "Reset restores the active room's refill and dash")
	_check(player.gravity_direction == 1 and not player.is_air_jump_ready() and player.get_wall_stamina() == player.wall_stamina_max, "Reset restores movement resources")
	_check(course.completed and course.get_node("HUD/Completion").visible, "Retry preserves a cleared course")
	Input.action_press("move_left")
	Input.action_press("jump")
	await _step(25)
	_release_inputs()
	await _step(35)
	_check(course.room_index == 3 and course.completed and not course.get_node("HUD/Completion").visible, "Cleared rooms remain available for backtracking")
	_check(player.is_on_floor() and player.controls_enabled, "The return entrance is safe and controls resume")
	var back := InputEventAction.new()
	back.action = "return_to_stage_select"
	back.pressed = true
	Input.parse_input_event(back)
	await _step(3)
	back.pressed = false
	Input.parse_input_event(back)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return input leaves the cleared stage for stage selection")
	current_scene.get_node("Margin/Content/Stages/Stage2").pressed.emit()
	await _step(3)
	_check(current_scene.room_index == 0 and current_scene.cleared.is_empty() and not current_scene.completed, "Re-entering stage 2 starts a fresh course")
	print("STAGE_2_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _run_room(index: int) -> void:
	var goal: ArrivalSwitch = course.rooms.get_child(index).get_node("Goal")
	var goal_jump := false
	var gap_jump := false
	for frame in 900:
		Input.action_release("jump")
		Input.action_release("dash")
		var x := player.position.x - index * 1280
		Input.action_press("move_right")
		if x >= 970:
			if x >= 1116:
				Input.action_release("move_right")
			if player.is_on_floor() and x >= 1005 and not goal_jump:
				Input.action_press("jump")
				goal_jump = true
		else:
			if index in [1, 2] and x >= 285 and player.is_on_floor() and not gap_jump:
				Input.action_press("jump")
				gap_jump = true
			var dash_now := index == 0 and x < 800 and frame % 26 == 0
			dash_now = dash_now or (index in [1, 2] and x >= 350 and not player.is_on_floor())
			dash_now = dash_now or (index == 3 and player.position.y < 470 and not player.is_on_floor())
			dash_now = dash_now or (index == 4 and player.position.y < 455 and not player.is_on_floor())
			if dash_now and player.is_dash_ready() and not player.is_dashing():
				Input.action_press("dash")
		await _step()
		if goal.is_pressed():
			break
	_release_inputs()
	await _step(3)
	_check(goal.is_pressed(), "The input route reaches room %d's switch" % (index + 1))


func _screenshot(label: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/%s.png" % label)


func _release_inputs() -> void:
	for action in ["move_right", "move_left", "jump", "dash", "reset"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_2: " + message)
		quit(1)
