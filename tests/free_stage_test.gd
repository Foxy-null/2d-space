extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/free_stage.tscn")
	await _step(20)
	var stage := current_scene
	var player: PlayerController = stage.player
	var spawn: Vector2 = stage.get_node("Spawn").global_position
	_check(player.is_on_floor() and player.position.distance_to(spawn) < 2, "Start on the safe floor")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement is available")
	_check(stage.get_node("Camera2D").is_current() and not player.get_node("Camera2D").enabled, "Use the fixed room camera")
	_check(stage.get_node("HUD/Margin/Panel/Rows/Title").text == "自由制作ステージ", "HUD uses the unnumbered title")
	_check(stage.get_node("Background/Backdrop").environment_theme == 0, "Reuse the space base background")
	_check(not stage.get_node("Goal").locked and not stage.completed, "The goal is ready at the start")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/free-stage.png")
	# Walk and jump onto the goal without teleporting or refilling abilities.
	var jumped := false
	for frame in 300:
		Input.action_release("jump")
		if player.position.x < 1080:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
		if not jumped and player.position.x > 980 and player.is_on_floor():
			Input.action_press("jump")
			jumped = true
		await _step()
		if stage.completed:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(stage.completed and stage.get_node("Goal").is_pressed(), "Real inputs reach and press the goal")
	_check(stage.get_node("HUD/Completion").visible and player.controls_enabled, "Completion allows continued practice")
	_check(stage.get_node("Camera2D").position == Vector2(640, 360), "The camera stays fixed")
	# Objects added while authoring must also reset on retry.
	var crystal = load("res://scenes/refill_crystal.tscn").instantiate()
	crystal.position = Vector2(400, 400)
	stage.get_node("Objects").add_child(crystal)
	await _step(2)
	crystal._on_body_entered(player)
	_check(not crystal.visible, "Crystal can be collected")
	var gate = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(600, 400)
	gate.moving_enabled = true
	stage.get_node("Objects").add_child(gate)
	await _step(20)
	_check(gate.position.x > 600, "A placed moving gate moves")
	player.set_gravity_direction(-1)
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	_check(player.position.distance_to(spawn) < 2 and player.gravity_direction == 1, "R resets position and gravity")
	_check(player.is_dash_ready() and is_equal_approx(player.get_wall_stamina(), player.wall_stamina_max), "R restores resources")
	_check(crystal.visible and gate.position == Vector2(600, 400), "Retry restores crystals and moving gates")
	_check(stage.completed, "Retry keeps the completion of this play session")
	for y in [-300, 1020]:
		player.position.y = y
		await _step(3)
		_check(player.position.distance_to(spawn) < 2, "Leaving the screen vertically resets to the spawn")
	player.position.x += 100
	stage.get_node("HUD/Retry").pressed.emit()
	await _step(3)
	_check(player.position.distance_to(spawn) < 2, "The retry button returns to the spawn")
	stage.get_node("HUD/ReturnToStageSelect").pressed.emit()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return opens stage selection")
	current_scene.get_node("Margin/Content/Extras/FreeStage").pressed.emit()
	await _step(3)
	_check(not current_scene.completed and not current_scene.get_node("Goal").is_pressed(), "Re-entry starts fresh")
	_check(not current_scene.get_node("HUD/Completion").visible, "Re-entry hides completion")
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("FREE_STAGE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FREE_STAGE: " + message)
