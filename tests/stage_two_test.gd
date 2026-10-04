extends SceneTree

var stage: Node2D
var player: PlayerController
var checks := 0
var failed := false
var actions: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_two.tscn")
	await _step(3)
	stage = current_scene
	player = stage.player
	player.movement_action.connect(func(action: String): actions[action] = true)
	_check(stage.rooms.get_child_count() == 5, "Stage 2 has five rooms")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement abilities start unlocked")
	var camera_position: Vector2 = stage.camera.position
	Input.action_press("move_right")
	await _step(15)
	_check(stage.camera.position == camera_position, "Camera stays fixed while moving inside a room")
	_release_inputs()
	player.respawn()
	await _step(3)
	await _dock()
	await _advance(0)
	await _gravity_corridor()
	await _advance(1)
	await _cargo()
	await _advance(2)
	await _wind_route()
	await _advance(3)
	await _core()
	_check(stage.completed and stage.cleared.size() == 5, "The physical final switch completes the stage")
	_check(stage.get_node("HUD/Completion").visible, "Completion is visible without leaving the stage")
	_check(actions.has("dash") and actions.has("creature_jump"), "The course uses dash and the creature's extra jump")
	await _retry_and_backtrack()
	if OS.get_cmdline_user_args().has("--screenshots"):
		stage = current_scene
		player = stage.player
		await _screenshots()
	_release_inputs()
	print("STAGE_TWO_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _dock() -> void:
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	var dashed := false
	for frame in 400:
		Input.action_release("jump")
		Input.action_release("dash")
		if player.is_on_floor() and (player.is_on_wall() or player.position.x > 340 and player.position.x < 390):
			Input.action_press("jump")
		if (not dashed and player.position.x > 450 or dashed and player.position.x > 590 and player.is_dash_ready()) and player.position.x < 680:
			# Stop climbing input so this is a horizontal dash across the gap.
			Input.action_release("move_up")
			Input.action_press("dash")
			dashed = true
		if player.position.x > 680:
			Input.action_press("move_up")
		if player.position.x >= 1150:
			Input.action_release("move_right")
		if stage.cleared.has(0):
			break
		await _step()
	_release_inputs()
	_check(stage.cleared.has(0), "Jump, dash and climb reach the dock's arrival switch")


func _gravity_corridor() -> void:
	Input.action_press("move_right")
	var inverted := false
	var restored := false
	for frame in 400:
		inverted = inverted or player.gravity_direction == -1
		restored = restored or inverted and player.gravity_direction == 1
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if _local_x() >= 1150:
			Input.action_release("move_right")
		if stage.cleared.has(1):
			break
		await _step()
	_release_inputs()
	_check(inverted and restored and stage.cleared.has(1), "Both real gravity gates lead through the ceiling route to the floor switch")


func _cargo() -> void:
	var door: CollisionShape2D = stage.get_node("Rooms/Room3/CargoDoor/Collision")
	_check(not door.disabled, "Cargo door begins closed")
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	for frame in 140:
		if _local_x() >= 430:
			break
		await _step()
	_check(player.get_held_object() != null and player.get_held_object().carry_name == "HEAVY", "Carry the heavy box to the plate")
	Input.action_release("move_right")
	await _step(20)
	Input.action_release("wall_grab")
	await _step(35)
	_check(stage.get_node("Rooms/Room3/PressureButton").is_pressed() and door.disabled, "Dropping the box on the actual plate opens the physical door")
	Input.action_press("wall_grab")
	await _step(3)
	_check(not door.disabled, "Picking the box back up closes the door")
	Input.action_release("wall_grab")
	await _step(35)
	Input.action_press("move_right")
	for frame in 200:
		Input.action_release("jump")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if _local_x() >= 1150:
			Input.action_release("move_right")
		if stage.cleared.has(2):
			break
		await _step()
	_release_inputs()
	_check(stage.cleared.has(2), "Cross the cargo door and press the arrival switch")


func _wind_route() -> void:
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	var lifted := false
	var reached_ledge := false
	var crossed := false
	for frame in 600:
		Input.action_release("jump")
		Input.action_release("dash")
		var x := _local_x()
		if x > 475 and not lifted:
			Input.action_release("move_right")
		if x > 370 and player.position.y < 280:
			lifted = true
			Input.action_press("move_right")
		if lifted and not reached_ledge and x > 550 and player.position.y < 290:
			Input.action_press("dash")
		if x > 750 and not reached_ledge:
			Input.action_release("move_right")
		if x > 650 and player.is_on_floor():
			reached_ledge = true
			Input.action_press("move_right")
		if reached_ledge and not crossed and x > 810 and player.is_on_floor():
			Input.action_press("jump")
			crossed = true
		if x >= 1150:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if stage.cleared.has(3):
			break
		await _step()
	_release_inputs()
	_check(lifted and reached_ledge and stage.cleared.has(3), "Holding the umbrella allows lifting, landing and gliding to the arrival switch")


func _core() -> void:
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	var extra_jumps := 0
	var launched := false
	var dash_crystal: Area2D = stage.get_node("Rooms/Room5/DashCrystal")
	var jump_crystal: Area2D = stage.get_node("Rooms/Room5/JumpCrystal")
	for frame in 500:
		Input.action_release("jump")
		Input.action_release("dash")
		var x := _local_x()
		launched = launched or x > 300 and player.velocity.y < -700
		if launched and player.velocity.y > -30 and not player.is_on_floor() and not player.is_dashing() and extra_jumps < 2 and (extra_jumps == 0 or x > 820):
			Input.action_press("jump")
			extra_jumps += 1
		if x > 600 and x < 930 and player.is_dash_ready() and not player.is_dashing():
			Input.action_press("dash")
		if x >= 1150:
			Input.action_release("move_right")
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if stage.cleared.has(4):
			break
		await _step()
	_release_inputs()
	_check(launched and stage.cleared.has(4), "Spring, extra jumps and dash cross the final gap to the core")
	_check(not dash_crystal.visible and not jump_crystal.visible, "The final route collects both actual crystals")


func _advance(index: int) -> void:
	Input.action_press("move_right")
	for frame in 60:
		if stage.transitioning:
			break
		await _step()
	_check(stage.transitioning and not player.controls_enabled, "Exit freezes controls during the camera slide")
	_release_inputs()
	await _step(40)
	_check(stage.room_index == index + 1 and player.controls_enabled, "Next room starts with controls restored")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and player.get_held_object() == null, "Room entry resets gravity, dash and carried objects")


func _retry_and_backtrack() -> void:
	stage.call("_set_room", 3, false)
	player.respawn()
	await _step(3)
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	await _step(24)
	_check(player.get_held_object() != null, "Grab an object before retrying")
	Input.action_press("reset")
	await _step()
	_release_inputs()
	var umbrella: Grabbable = stage.get_node("Rooms/Room4/Parachute")
	_check(umbrella.position.distance_to(Vector2(200, 530)) < 3 and umbrella.carrier == null, "Retry restores the umbrella's initial position and releases it")
	await _step(20)
	_check(player.get_held_object() == null and _local_x() < 100, "Retry restores the current room and releases its object")
	player.position.y = 800
	await _step(3)
	_check(stage.room_index == 3 and player.position.y < 720, "Falling retries the same room")
	player.set_gravity_direction(-1)
	player.position.y = -60
	await _step(3)
	_check(player.gravity_direction == 1 and _local_x() < 100, "Inverted falling retries with down gravity")
	player.position.x = 3 * 1280 - 5
	await _step(40)
	_check(stage.room_index == 2 and _local_x() > 1200, "The left edge returns to the previous room's right entrance")
	_check(stage.get_node("Rooms/Room3/CargoDoor/Collision").disabled, "A cleared cargo room remains traversable after retry and backtracking")
	stage.call("_set_room", 4, false)
	player.respawn()
	await _step(3)
	var crystal: Area2D = stage.get_node("Rooms/Room5/JumpCrystal")
	crystal.emit_signal("body_entered", player)
	_check(not crystal.visible, "Consume a room's crystal")
	player.respawn()
	await _step(3)
	_check(crystal.visible and not player.is_air_jump_ready() and stage.completed, "Retry restores crystals and keeps completion")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.call("_start_stage_two")
	await _step(3)
	_check(current_scene.room_index == 0 and current_scene.cleared.is_empty() and not current_scene.completed, "Re-entering stage 2 starts a fresh run")
	stage = current_scene
	player = stage.player
	var goal: ArrivalSwitch = stage.get_node("Rooms/Room1/Goal")
	_check(not goal.locked and goal.get_node("Bubble/Progress").text == "到着台", "Course arrival switches start ready without a lesson checklist")
	player.position = goal.global_position + Vector2(0, -140)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	for frame in 40:
		if goal.pressing:
			break
		await _step()
	_check(goal.pressing and not goal.is_pressed(), "Arrival has an intermediate pressing state")
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	await _step(20)
	_check(not goal.is_pressed() and not goal.pressing and goal.cap.position.y == 0 and stage.cleared.is_empty(), "Retry cancels an unfinished arrival press")


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-two")
	for index in 5:
		stage.call("_set_room", index, false)
		player.respawn()
		await _step(40)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-two/room_%d.png" % (index + 1))


func _local_x() -> float:
	return player.position.x - stage.room_index * 1280


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("STAGE_TWO: " + message + " (room=%d pos=%s)" % [stage.room_index + 1, player.position])
		quit(1)
