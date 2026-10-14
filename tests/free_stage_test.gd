extends SceneTree

var failed := false
var checks := 0
var respawns := 0
var collected := 0
var dashes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Extras/FreeStage").pressed.emit()
	await _step(20)
	var stage := current_scene
	var player: PlayerController = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action):
		if action == "dash":
			dashes += 1
	)
	for crystal in stage.get_node("Objects").find_children("Crystal*", "Area2D", true, false):
		crystal.collected.connect(func(_body): collected += 1)
	_check(player.is_on_floor() and stage.checkpoint_index == 0, "Start on the first safe platform")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement is available")
	_check(stage.camera.is_current() and not player.get_node("Camera2D").enabled, "Use the course camera")
	_check(stage.get_node("HUD/Margin/Panel/Rows/Title").text.contains("流星ダッシュ"), "HUD names the dash course")
	_check(stage.get_node("Background/Backdrop").environment_theme == 0, "Reuse the space base background")
	_check(not stage.get_node("Goal").locked and not stage.completed, "The goal is ready at the start")
	_check(not stage.get_node("Terrain/Section6").has_node("Rest"), "The final chain has no recovery platform")
	# Traverse every section with normal inputs, without teleports or ability refills.
	for section in 6:
		_release()
		await _step(15)
		if section in [0, 5] and OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/free-stage%s.png" % ("" if section == 0 else "-hard"))
		var items: Node2D = stage.get_node("Objects/Section%d" % (section + 1))
		var crystal_index := 0
		var arrived := false
		var previous_dashes := dashes
		for frame in 900:
			_release()
			if stage.checkpoint_index > section or stage.completed:
				arrived = true
				break
			var target := Vector2(section * 1280 + (1420 if section < 5 else 1160), 580)
			if crystal_index < items.get_child_count():
				var crystal: Area2D = items.get_child(crystal_index)
				if not crystal.visible or player.position.x > crystal.global_position.x + 38:
					crystal_index += 1
					continue
				target = crystal.global_position
			elif player.position.x < section * 1280 + 1090:
				target = Vector2(section * 1280 + 1110, 580)
			var difference := target - player.position
			if absf(difference.x) > 12:
				Input.action_press("move_right" if difference.x > 0 else "move_left")
			if player.is_on_floor() and crystal_index < items.get_child_count():
				Input.action_press("jump")
			if section == 5 and crystal_index == items.get_child_count() and player.is_on_floor() and player.position.x < 7510:
				Input.action_press("jump")
			var aligned := absf(difference.y) < 30 or absf(absf(difference.x) - absf(difference.y)) < 45
			if not player.is_on_floor() and not player.is_dashing() and player.is_dash_ready() and aligned and absf(difference.x) < 180 and player.position.x < section * 1280 + 1050:
				if absf(difference.y) > absf(difference.x) * 0.42:
					Input.action_press("move_down" if difference.y > 0 else "move_up")
				Input.action_press("dash")
			await _step()
			if respawns > 0:
				break
		_release()
		print("区間 %d / 位置 %s / 緑 %d / ダッシュ %d / 復帰 %d" % [section + 1, player.position, collected, dashes - previous_dashes, respawns])
		_check(arrived, "Section %d must be traversable with normal inputs" % (section + 1))
		if not arrived:
			quit(1)
			return
	_check(respawns == 0, "The whole course is crossed without falls or forced respawns")
	_check(collected == 34 and dashes >= 24, "Progress uses every crystal and repeated dashes")
	_check(stage.completed and stage.get_node("Goal").is_pressed(), "Reach and press the goal")
	_check(stage.get_node("HUD/Completion").visible and player.controls_enabled, "Completion allows continued practice")
	_check(stage.camera.position.x > 640 and stage.camera.position.y == 360, "The camera follows horizontally")
	var spawn: Vector2 = stage.checkpoints.get_child(5).get_node("Spawn").global_position
	player.set_gravity_direction(-1)
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	_check(player.position.distance_to(spawn) < 2 and player.gravity_direction == 1, "R resets to the latest checkpoint and restores gravity")
	_check(player.is_dash_ready() and is_equal_approx(player.get_wall_stamina(), player.wall_stamina_max), "R restores resources")
	for crystal in stage.get_node("Objects").find_children("Crystal*", "Area2D", true, false):
		_check(crystal.visible, "Retry restores every dash crystal")
	_check(stage.completed, "Retry keeps completion for this session")
	for y in [-100, 850]:
		player.position.y = y
		await _step(3)
		_check(stage.checkpoint_index == 5 and player.position.distance_to(spawn) < 2, "Falling keeps the latest checkpoint")
	player.position.x += 100
	stage.get_node("HUD/Retry").pressed.emit()
	await _step(3)
	_check(player.position.distance_to(spawn) < 2, "The retry button returns to the latest checkpoint")
	stage.get_node("HUD/ReturnToStageSelect").pressed.emit()
	await _step(3)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return opens stage selection")
	current_scene.get_node("Margin/Content/Extras/FreeStage").pressed.emit()
	await _step(3)
	stage = current_scene
	_check(stage.checkpoint_index == 0 and not stage.completed and not stage.get_node("Goal").is_pressed(), "Re-entry starts fresh")
	_check(not stage.get_node("HUD/Completion").visible, "Re-entry hides completion")
	stage.player.position = stage.checkpoints.get_child(1).get_node("Spawn").global_position - Vector2(0, 100)
	await _step(2)
	_check(stage.checkpoint_index == 0, "Passing over a checkpoint in the air does not activate it")
	stage.player.respawn()
	await _step(3)
	_check(stage.player.position.distance_to(stage.checkpoints.get_child(0).get_node("Spawn").global_position) < 2, "An inactive checkpoint cannot change the respawn")
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("FREE_STAGE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FREE_STAGE: " + message)
