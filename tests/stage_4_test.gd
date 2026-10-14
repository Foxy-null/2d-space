extends SceneTree

var failed := false
var respawns := 0
var stage: Node2D
var player: PlayerController
var collected := 0
var inversions := 0


func _initialize() -> void:
	_run.call_deferred()


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(action)


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage4").pressed.emit()
	await _step(20)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	player.gravity_changed.connect(func(_up): inversions += 1)
	for room in stage.rooms.get_children():
		for item in room.get_node("Items").get_children():
			if item.has_signal("collected"):
				item.collected.connect(func(_body): collected += 1)
	_check(player.is_on_floor(), "Safe entrance")
	# 各部屋をテレポート・能力補充なしで、実入力だけで渡る。
	for section in 6:
		var room: Node2D = stage.rooms.get_child(section)
		var crystal_index := 1
		var arrived := false
		for frame in 700:
			_release()
			if stage.transitioning:
				await _step()
				continue
			if stage.room_index > section or stage.completed:
				arrived = true
				break
			_check(stage.camera.position == Vector2(section * 1280 + 640, 360), "Camera stays fixed inside each room")
			var target := Vector2(section * 1280 + (1270 if section < 5 else 1160), 470)
			if crystal_index > 6 and player.position.x < section * 1280 + 1090:
				target = Vector2(section * 1280 + 1100, 450)
			if crystal_index <= 6:
				var crystal: Area2D = room.get_node("Items/Crystal%d" % crystal_index)
				if not crystal.visible or player.position.x > crystal.global_position.x + 38:
					crystal_index += 1
					continue
				target = crystal.global_position
			var difference := target - player.position
			if absf(difference.x) > 12:
				Input.action_press("move_right" if difference.x > 0 else "move_left")
			if player.is_on_floor() and crystal_index <= 6 and target.y < 470:
				Input.action_press("jump")
			if section == 5 and crystal_index > 6 and player.is_on_floor() and player.position.x < 7520:
				Input.action_press("jump")
			if not player.is_on_floor() and not player.is_dashing() and player.is_dash_ready() and player.position.x < section * 1280 + 1090 and absf(difference.x) < 155:
				if absf(difference.y) > absf(difference.x) * 0.42:
					Input.action_press("move_down" if difference.y > 0 else "move_up")
				Input.action_press("dash")
			await _step()
			if respawns > section and stage.room_index == section:
				break
		_release()
		print("部屋 %d / 位置 %s / 緑 %d / 反転 %d / 復帰 %d" % [section + 1, player.position, collected, inversions, respawns])
		_check(arrived, "Room %d must be traversable" % (section + 1))
		if not arrived:
			quit(1)
			return
	_check(respawns == 5, "Only room transitions respawn the player")
	_check(collected >= 24 and inversions >= 12, "Route uses crystals and gravity gates")
	# 上下への脱落は最終部屋の入口へ戻す。
	for y in [-100, 850]:
		player.position.y = y
		await _step(3)
		_check(stage.room_index == 5 and absf(player.position.x - 6510) < 2, "Fall keeps checkpoint")
		_check(player.gravity_direction == 1 and player.is_dash_ready(), "Retry resets gravity and dash")
		for item in stage.rooms.get_child(5).get_node("Items").get_children():
			_check(item.visible, "Retry restores crystals")
	stage.set_help_visible(true)
	var before := player.position
	await _step(15)
	_check(player.position == before and not player.controls_enabled, "Help pauses movement")
	stage.get_node("HUD/Help/Rows/Hints").button_pressed = true
	_check(stage.get_node("HUD/Hint").visible, "Hints can be enabled")
	stage.get_node("HUD/Help/Rows/Retry").pressed.emit()
	await _step(3)
	_check(player.controls_enabled and stage.hints_visible, "Retry closes help and keeps hints")
	player.position.x += 60
	Input.action_press("reset")
	await _step()
	Input.action_release("reset")
	await _step(3)
	_check(absf(player.position.x - 6510) < 2, "R returns to the current entrance")
	stage.get_node("HUD/Help/Rows/Return").pressed.emit()
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage4").pressed.emit()
	await _step(3)
	_check(current_scene.room_index == 0 and not current_scene.completed, "Re-entry starts fresh")
	current_scene.queue_free()
	await _step(3)
	# fixed-fpsの高速実行後、音声スレッドにも解放を処理する時間を渡す。
	OS.delay_msec(100)
	print("STAGE_4_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)
