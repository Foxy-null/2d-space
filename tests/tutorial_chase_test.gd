extends SceneTree

var tutorial
var player: PlayerController
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/tutorial.tscn")
	await _step(4)
	tutorial = current_scene
	player = tutorial.player
	var enemy: CharacterBody2D = tutorial.chaser
	var original_enemy := enemy.global_position
	await _step(30)
	_check(not enemy.active and enemy.global_position == original_enemy, "The final enemy stays inactive during other lessons")
	tutorial._set_room(tutorial.CHASE_ROOM, false)
	player.respawn()
	await _step(4)
	var room: Node2D = tutorial.rooms.get_child(tutorial.CHASE_ROOM)
	var goal: ArrivalSwitch = room.get_node("Goal")
	_check(tutorial.MAIN_ROOM_COUNT == 17 and tutorial.rooms.get_child_count() == 18, "Escape ends the main course before optional Superdash")
	_check(tutorial.CHASE_DURATION <= 5.0 and enemy.move_speed < player.move_speed, "The beginner lesson has a short timer and a slower pursuer")
	_check(enemy.collision_layer == 0 and not enemy is PlayerController and not enemy.is_in_group("grabbable"), "The pursuer cannot press the arrival switch or be carried")
	_check(enemy.get_node("Body").sprite_frames == load("res://assets/characters/jump-creature-frames.tres"), "Enemy reuses the green creature's existing animation")
	await _step(330)
	_check(not tutorial._chase_started and tutorial._chase_elapsed == 0.0 and goal.locked, "Reading the instructions does not start the chase or unlock the switch")
	Input.action_press("move_right")
	await _step(25)
	Input.action_release("move_right")
	_check(tutorial._chase_started and tutorial._chase_elapsed > 0.0 and enemy.active, "Moving away from the entrance starts the countdown and pursuit")
	_check(enemy.global_position.x > original_enemy.x + 10.0 and enemy.velocity.x > 0.0, "The enemy actually pursues the moving player")
	player.global_position = enemy.global_position
	await _step(2)
	_check(player.global_position.distance_to(room.get_node("Spawn").global_position) < 1.0, "Capture returns the player to this room's entrance")
	_check(enemy.position == Vector2(80, 614) and not enemy.active and tutorial._chase_elapsed == 0.0, "Capture resets the enemy and countdown")
	_check(goal.locked and not tutorial.seen.has("escape") and not tutorial.completed, "Capture keeps the final switch sealed and the stage incomplete")
	# Isolate unlock/capture/press states; the extension test traverses this room with real inputs.
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.global_position = room.global_position + Vector2(400, 614)
	tutorial._chase_started = true
	tutorial._chase_elapsed = tutorial.CHASE_DURATION - 0.02
	await _step(3)
	_check(not goal.locked and tutorial.seen.has("escape"), "Surviving the full countdown removes the seal")
	_check(not goal.is_pressed() and not tutorial.completed and not tutorial.cleared.has(tutorial.CHASE_ROOM), "Time alone never clears the tutorial")
	enemy.global_position = player.global_position
	await _step(2)
	_check(goal.locked and tutorial._chase_elapsed == 0.0 and not tutorial.seen.has("escape"), "Capture after unlocking re-seals the switch and restarts the full lesson")
	tutorial._chase_started = true
	tutorial._chase_elapsed = 1.0
	tutorial.transitioning = true
	await _step(12)
	_check(tutorial._chase_elapsed == 1.0, "Room transitions do not consume escape time")
	tutorial.transitioning = false
	player.set_physics_process(true)
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	await _step(2)
	_check(tutorial._chase_elapsed == 0.0 and not enemy.active and goal.locked, "R resets the chase and seal")
	player.global_position = room.global_position + Vector2(400, 800)
	await _step(3)
	_check(player.global_position.distance_to(room.get_node("Spawn").global_position) < 1.0 and tutorial._chase_elapsed == 0.0, "Falling also returns to the beginning of the escape lesson")
	player.set_physics_process(false)
	player.global_position = room.global_position + Vector2(400, 614)
	tutorial._chase_started = true
	tutorial._chase_elapsed = tutorial.CHASE_DURATION - 0.02
	await _step(3)
	enemy.global_position = goal.global_position - Vector2(0, 116)
	await _step(30)
	_check(not goal.is_pressed() and not tutorial.completed, "The enemy at an unlocked switch cannot complete the tutorial")
	enemy.reset_for_respawn()
	player.global_position = goal.global_position - Vector2(0, 160)
	player.velocity = Vector2.ZERO
	player._contacts_valid = false
	player.set_physics_process(true)
	await _step(55)
	_check(goal.is_pressed() and tutorial.completed and tutorial.cleared.has(tutorial.CHASE_ROOM), "The player must land on and press the unlocked switch to clear")
	_check(not enemy.active and tutorial.get_node("HUD/Completion").visible, "Clear stops the enemy and shows the existing completion card")
	player.respawn()
	await _step(4)
	_check(goal.is_pressed() and not enemy.active and tutorial.completed, "Retry after completion preserves safe free practice")
	if OS.get_cmdline_user_args().has("--screenshots"):
		tutorial.cleared.clear()
		tutorial.completed = false
		player.respawn()
		await _step(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/tutorial/escape.png")
	print("TUTORIAL_CHASE_TEST_OK (%d checks)" % checks)
	current_scene.queue_free()
	await _step(3)
	quit()


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("TUTORIAL_CHASE: " + message)
		quit(1)
