extends SceneTree

var failed := false
var checks := 0
var tutorial: Node
var player: PlayerController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	player = tutorial.get_node("Player")
	await _step(3)
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/tutorial.tscn", "Tutorial must be the default scene")
	_check(not player.wall_actions_enabled and not player.dash_enabled, "Only movement and jump start unlocked")
	var camera: Camera2D = tutorial.get_node("Camera2D")
	var fixed_position := camera.global_position
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step(5)
	_check(not player.is_dashing() and player.is_dash_ready(), "Locked dash must not consume a dash")
	Input.action_press("jump_up")
	await _step()
	_check(player.velocity.y < 0.0, "A locked dash key must not block W/stick-up jump")
	Input.action_release("jump_up")
	Input.action_release("dash")
	await _step(12)
	_check(camera.global_position == fixed_position, "Camera must stay fixed inside a room")
	_release_inputs()
	player.respawn()
	await _step(3)
	player.global_position = Vector2(511, 580)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	await _step(3)
	_check(not player.is_wall_grabbing(), "Wall grab must be locked in room 1")
	player.set("_coyote_left", 0.0)
	player.set("_jump_buffer_left", player.jump_buffer_time)
	await _step()
	_check(player.velocity.y >= 0.0, "Wall kick must be locked in room 1")
	_release_inputs()
	player.respawn()
	await _step(3)
	await _walk_room_one()
	_check(tutorial.room_index == 1, "Movement and jump must reach room 2")
	_check(player.wall_actions_enabled and not player.dash_enabled, "Room 2 unlocks walls only")
	_check(player.controls_enabled, "Controls resume after the camera slide")
	_check(camera.position == Vector2(1920, 360), "Camera must settle on room 2")
	await _climb_and_kick()
	await _cross_right_edge()
	_check(tutorial.room_index == 2 and player.dash_enabled, "Room 3 unlocks dash")
	await _dash_course()
	_check(tutorial.room_index == 3, "Dash course must reach the gravity room")
	await _gravity_course()
	await _test_respawn_and_backtrack()
	if OS.get_cmdline_user_args().has("--screenshots"):
		await _screenshots()
	_release_inputs()
	print("TUTORIAL_ROOMS_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _walk_room_one() -> void:
	Input.action_press("move_right")
	for frame in 450:
		if tutorial.room_index == 1:
			break
		Input.action_release("jump")
		if player.is_on_floor() and (player.is_on_wall() or (player.position.x > 700 and player.position.x < 760)):
			Input.action_press("jump")
		await _step()
	_release_inputs()
	await _finish_transition()


func _climb_and_kick() -> void:
	Input.action_press("move_right")
	for frame in 80:
		if player.is_on_wall():
			break
		await _step()
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	var climbed := false
	for frame in 110:
		await _step()
		if player.global_position.x > 1680 and player.is_on_floor():
			climbed = true
			break
	_check(climbed, "Room 2 wall must be climbable onto the rest ledge")
	_check(player.get_wall_stamina() > 2.9, "Rest ledge restores wall stamina")
	_release_inputs()
	# Probe the actual inner face of the wall-kick corridor.
	player.global_position = Vector2(1280 + 705, 350)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	player.set("_coyote_left", 0.0)
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	await _step(4)
	_check(player.is_on_wall() and player.is_wall_grabbing(), "Opposing wall must be grabbable")
	Input.action_release("move_left")
	Input.action_press("jump")
	await _step()
	_check(player.velocity.x > 400 and player.velocity.y < 0, "Wall kick must launch toward the opposite wall")
	_release_inputs()


func _dash_course() -> void:
	player.global_position = Vector2(2560 + 325, 614)
	player.velocity = Vector2(360, 0)
	player.set("_contacts_valid", false)
	Input.action_press("move_right")
	await _step(2)
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	await _step(17)
	Input.action_press("dash")
	await _step()
	_check(player.is_dashing(), "Dash must work in room 3")
	Input.action_release("dash")
	var landed := false
	for frame in 70:
		await _step()
		if player.is_on_floor() and player.global_position.x >= 2560 + 700:
			landed = true
			break
	_check(landed, "Jump and horizontal dash must cross the wide gap")
	_check(player.is_dash_ready(), "Landing restores dash")
	if not landed:
		_release_inputs()
		await _go_to_room(3)
		return
	for frame in 30:
		if player.global_position.x >= 2560 + 835:
			break
		await _step()
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	await _step(8)
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	Input.action_release("move_up")
	for frame in 160:
		if tutorial.room_index == 3:
			break
		await _step()
	_release_inputs()
	await _finish_transition()


func _gravity_course() -> void:
	Input.action_press("move_right")
	var inverted := false
	var restored := false
	for frame in 500:
		inverted = inverted or player.gravity_direction == -1
		restored = restored or (inverted and player.gravity_direction == 1)
		Input.action_release("jump")
		if player.gravity_direction == -1 and player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
		if tutorial.cleared.has(3):
			break
		await _step()
	_release_inputs()
	_check(inverted, "Walking through the red gate must invert gravity")
	_check(restored, "Ceiling route must reach the down gate")
	_check(tutorial.cleared.has(3) and not tutorial.completed, "Gravity lesson opens its exit but the main course continues")


func _test_respawn_and_backtrack() -> void:
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	_check(tutorial.room_index == 3 and player.global_position.x > 3840, "Reset returns to the current room")
	_check(player.gravity_direction == 1 and not tutorial.completed, "Reset restores gravity and clears completion")
	player.global_position.y = 780
	await _step(2)
	_check(player.global_position.y < 720 and tutorial.room_index == 3, "Falling returns to the current entrance")
	player.set_gravity_direction(-1)
	player.global_position.y = -60
	await _step(2)
	_check(player.gravity_direction == 1 and player.global_position.y > 0, "Inverted fall returns to the room entrance with down gravity")
	player.global_position.x = 3835
	await _step()
	await _finish_transition()
	_check(tutorial.room_index == 2, "Left edge returns to the previous room")
	_check(player.dash_enabled and player.wall_actions_enabled, "Learned actions stay unlocked when going back")
	var crystal: Area2D = tutorial.get_node("Rooms/Room3/DashCrystal")
	crystal.emit_signal("body_entered", player)
	_check(not crystal.visible, "Crystal can be consumed")
	player.respawn()
	await _step(2)
	_check(crystal.visible, "Retry restores the current room's crystal")
	_check(player.global_position.x > 2560 + 1150, "Backtracking checkpoint is the entrance on the right")
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	_check(player.is_dashing(), "Dash starts before crossing the edge")
	Input.action_release("dash")
	await _step(5)
	_release_inputs()
	await _finish_transition()
	_check(tutorial.room_index == 3 and not player.is_dashing() and player.is_dash_ready(), "Dash boundary crossing starts the next room in a safe, refilled state")


func _cross_right_edge() -> void:
	_release_inputs()
	player.global_position = Vector2(tutorial.room_index * 1280 + 1190, 610)
	player.velocity = Vector2.ZERO
	player.set("_contacts_valid", false)
	await _step(5)
	_check(tutorial.cleared.has(tutorial.room_index), "The lesson actions and an actual landing must open the exit")
	player.global_position = Vector2((tutorial.room_index + 1) * 1280 - 4, 614)
	player.velocity = Vector2(360, 0)
	Input.action_press("move_right")
	await _step(3)
	_check(tutorial.transitioning and not player.controls_enabled, "Boundary crossing freezes controls during the camera slide")
	_release_inputs()
	await _finish_transition()


func _go_to_room(index: int) -> void:
	tutorial.call("_transition_to", index)
	await _finish_transition()


func _finish_transition() -> void:
	for frame in 40:
		if not tutorial.transitioning:
			return
		await _step()
	_check(false, "Room transition timed out")


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tutorial")
	tutorial.furthest_room = 0
	for index in tutorial.rooms.get_child_count():
		tutorial.call("_set_room", index, false)
		player.respawn()
		await _step(2)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial/room_%d.png" % (index + 1))


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
		push_error("TUTORIAL_ROOMS: " + message + " (pos=%s room=%s)" % [player.global_position, tutorial.room_index])
