extends SceneTree

var failed := false
var stage: Node2D
var player: PlayerController
var respawns := 0


func _initialize() -> void:
	_run.call_deferred()


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "wall_grab", "jump", "dash"]:
		Input.action_release(action)


func _check_signage() -> void:
	# 旗の地形確認では、移動できるプレイヤーや生物を障害物として数えない。
	var excluded: Array[RID] = [player.get_rid()]
	for object in get_nodes_in_group("grabbable"):
		excluded.append(object.get_rid())
	for index in stage.checkpoints.get_child_count():
		var point: Node2D = stage.checkpoints.get_child(index)
		var mark := "↺ " if index == stage.checkpoint_index else ("✓ " if index < stage.checkpoint_index else "")
		_check(point.get_node("Label").text == mark + "%02d" % (index + 1), "Checkpoint marks distinguish unseen, current, and reached platforms")
		_check(point.get_node("Sign").visible and point.get_node("Sign").get_signal_connection_list("draw").size() == 1, "Every checkpoint keeps its static flag visible")
		var ray := PhysicsRayQueryParameters2D.create(point.position + Vector2(-110, -36), point.position + Vector2(-50, -36), 1, excluded)
		_check(root.world_2d.direct_space_state.intersect_ray(ray).is_empty(), "Checkpoint flag does not obstruct the route")
	var panel: Control = stage.get_node("HUD/Info")
	_check(panel.get_global_rect().end.x <= 600, "The HUD leaves the right half of the view clear")
	var status: String = stage.get_node("HUD/Info/Rows/Status").text
	_check(status.contains("高度") and status.contains("ダッシュ") and status.contains("追加ジャンプ"), "Movement resources and altitude stay visible")


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage2").pressed.emit()
	await _step(4)
	_check(current_scene.scene_file_path == "res://scenes/stage_2.tscn", "Stage 2 selection opens the tower")
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	_check(stage.checkpoints.get_child_count() == 6, "Six checkpoints")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement abilities available")
	await _step(20)
	_check(player.is_on_floor(), "Spawn is on a safe platform")
	_check_signage()
	# テレポートなしで全区間を通過し、バネとダッシュの区間では主題の経路を使う。
	for section in 6:
		if section == 1:
			await _spring_course()
			_check(stage.checkpoint_index == 2, "The spring route reaches the next checkpoint")
			_check_signage()
			continue
		if section == 2:
			await _dash_course()
			_check(stage.checkpoint_index == 3, "The dash chain reaches checkpoint 04")
			_check_signage()
			continue
		if section == 3:
			await _extra_jump_course()
			_check(stage.checkpoint_index == 4, "The extra-jump route reaches checkpoint 05")
			_check_signage()
			continue
		if section == 4:
			await _companion_course()
			_check(stage.checkpoint_index == 5, "The companion route reaches checkpoint 06")
			_check_signage()
			continue
		var xs: Array = [620, 360, 620, 900] if section % 2 == 0 else [640, 900, 640, 360]
		for ledge in 4:
			var target := Vector2(xs[ledge], 640 - section * 720 - (ledge + 1) * 180)
			var reached := false
			var release_frames := 0
			for frame in 300:
				Input.action_release("jump")
				var dx := target.x - player.position.x
				Input.action_release("move_left")
				Input.action_release("move_right")
				if absf(dx) > 12.0:
					Input.action_press("move_right" if dx > 0 else "move_left")
				if player.get_held_object() != null:
					release_frames = 30
				if release_frames > 0:
					Input.action_release("wall_grab")
					release_frames -= 1
				else:
					Input.action_press("wall_grab")
				Input.action_press("move_up")
				if player.is_on_floor() and player.position.y > target.y - 20:
					Input.action_press("jump")
				await _step()
				if absf(player.position.x - target.x) < 48 and player.position.y < target.y - 24:
					reached = true
					break
			_check(reached, "Reach section %d ledge %d via real movement; position %s" % [section + 1, ledge + 1, player.position])
			if not reached:
				_release()
				quit(1)
				return
			_release()
			# バネのある足場以外は着地を待つ。
			if section not in [1, 5] or ledge not in [0, 2]:
				await _step(40)
			if ledge == 3 and section < 5:
				_check(stage.checkpoint_index == section + 1, "Landing updates the checkpoint")
				_check_signage()
		print("区間 %d 登頂確認 / 復帰 %d" % [section + 1, respawns])
	_check(respawns == 0, "The entire tower is traversable without respawning")
	await _step(90)
	_check(stage.completed, "Summit arrival switch completes the stage")
	_check(stage.camera.position.y < -3000, "Camera follows the ascent continuously")
	# 落下・リトライで最新地点に復帰し、能力とクリスタルが回復する。
	player.position.y = 1000
	await _step(3)
	_check(stage.checkpoint_index == 5 and player.position.y < -2900, "Fall returns to latest checkpoint")
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Respawn restores movement resources")
	var crystal := stage.get_node("Items/Item4")
	crystal._on_body_entered(player)
	await _step(2)
	_check(not crystal.visible, "Collecting a crystal consumes it")
	Input.action_press("reset")
	await _step(1)
	Input.action_release("reset")
	await _step(3)
	_check(crystal.visible and player.position.y < -2900, "R restores crystals at the latest checkpoint")
	var camera_before: float = stage.camera.position.y
	Input.action_press("jump")
	await _step(1)
	Input.action_release("jump")
	await _step(8)
	_check(stage.camera.position.y < camera_before and absf(stage.camera.position.y - camera_before) < 150, "Camera scrolls smoothly during ascent")
	stage.get_node("PauseMenu").open()
	var before := player.position
	Input.action_press("move_right")
	await _step(15)
	_check(player.position == before, "Help menu suspends player input")
	_release()
	stage.get_node("PauseMenu").resume()
	stage.get_node("PauseMenu").toggle_hints()
	stage.get_node("PauseMenu").retry()
	await _step(3)
	_check(stage.hints_visible, "Retry preserves hint setting")
	_check_signage()
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").confirm_return()
	stage.get_node("PauseMenu").return_to_select()
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage2").pressed.emit()
	await _step(4)
	_check(current_scene.checkpoint_index == 0 and not current_scene.completed, "Re-entry starts a new climb")
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("STAGE_2_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _spring_course() -> void:
	var started := Engine.get_physics_frames()
	Input.action_press("move_right")
	for frame in 90:
		await _step()
		if player.velocity.y < -1000:
			break
	_check(player.velocity.y < -1000, "Walking onto the entrance spring starts the high leap")
	_release()
	# The broad inner landing gives the first launch a generous steering target.
	for frame in 150:
		var dx := 640.0 - player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 10:
			Input.action_press("move_right" if dx > 0 else "move_left")
		await _step()
		if player.is_on_floor() and absf(player.position.y + 556) < 2:
			break
	_release()
	_check(player.is_on_floor() and absf(player.position.y + 556) < 2, "The high spring reaches a safe inner rest")
	await _step(30)
	_check(player.is_on_floor(), "The inner rest permits a pause without relaunching")
	Input.action_press("move_left")
	for frame in 90:
		await _step()
		if player.velocity.y < -800:
			break
	_check(player.velocity.y < -800, "The second spring starts the smaller transfer")
	_release()
	for frame in 180:
		var dx := 400.0 - player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 10:
			Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_press("wall_grab")
		Input.action_press("move_up")
		await _step()
		if stage.checkpoint_index == 2:
			break
	_release()
	_check(stage.checkpoint_index == 2, "Spring steering reaches checkpoint 03 without a history lock")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The spring retry section stays below 30 seconds")
	print("TOWER_SPRING_ROUTE_SECONDS %.2f respawns=%d position=%s" % [seconds, respawns, player.position])


func _dash_course() -> void:
	var started := Engine.get_physics_frames()
	await _dash_launch()
	_release()
	Input.action_press("move_up")
	for name in ["Item3", "Item4"]:
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		for frame in 60:
			await _step()
			if not stage.get_node("Items/" + name).visible and not player.is_dashing():
				break
		_check(not stage.get_node("Items/" + name).visible, "A refilled upward dash reaches " + name)
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for frame in 120:
		if not player.is_dashing():
			Input.action_press("move_right")
			Input.action_press("wall_grab")
		await _step()
		if stage.checkpoint_index == 3:
			break
	_release()
	_check(stage.checkpoint_index == 3, "The fourth dash reaches checkpoint 04")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The dash chain stays below 30 seconds")
	print("TOWER_DASH_ROUTE_SECONDS %.2f respawns=%d position=%s" % [seconds, respawns, player.position])


func _dash_launch() -> void:
	_release()
	await _step(12)
	Input.action_press("move_right")
	for frame in 60:
		if player.position.x >= 450:
			break
		await _step()
	_release()
	await _step(12)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	await _step(26)
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for frame in 60:
		await _step()
		if not stage.get_node("Items/Item2").visible and not player.is_dashing():
			break
	_check(not stage.get_node("Items/Item2").visible, "The launch dash reaches the first crystal")
	for frame in 30:
		if player.position.x >= 740:
			break
		await _step()


func _extra_jump_course(jump_delay: int = 20, dash_delay: int = 20) -> void:
	var started := Engine.get_physics_frames()
	for leg in 2:
		_release()
		await _step(12)
		var launch_x := 950.0 if leg == 0 else 970.0
		for frame in 90:
			var dx := launch_x - player.position.x
			if absf(dx) < 10:
				break
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if dx > 0 else "move_left")
			await _step()
		if leg == 0:
			_release()
			await _step(12)
		Input.action_press("move_left" if leg == 1 else "move_right")
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		for frame in jump_delay:
			if leg == 0:
				Input.action_release("move_right")
			await _step()
		var crystal := stage.get_node("Items/Item%d" % (5 + leg))
		_check(not crystal.visible and player.is_air_jump_ready(), "The first jump collects the visible boot")
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		for frame in dash_delay:
			if leg == 0:
				Input.action_release("move_right")
			await _step()
		if leg == 0:
			_release()
		Input.action_press("move_up")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		var target := Vector2(1100, -1986) if leg == 0 else Vector2(350, -2266)
		for frame in 150:
			if not player.is_dashing():
				var dx := target.x - player.position.x
				Input.action_release("move_left")
				Input.action_release("move_right")
				if absf(dx) > 10:
					Input.action_press("move_right" if dx > 0 else "move_left")
			await _step()
			if player.is_on_floor() and absf(player.position.y - target.y) < 2:
				break
		_release()
		_check(player.is_on_floor() and absf(player.position.y - target.y) < 2, "Extra jump plus dash reaches the broad landing")
		await _step(30)
		_check(player.is_on_floor(), "The broad landing permits a pause")
	_check(stage.checkpoint_index == 4, "The extra-jump route reaches checkpoint 05")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The extra-jump section stays below 30 seconds")
	print("TOWER_EXTRA_JUMP_SECONDS %.2f delays=%d/%d respawns=%d" % [seconds, jump_delay, dash_delay, respawns])


func _companion_course(jump_delay: int = 20, dash_delay: int = 20) -> void:
	var started := Engine.get_physics_frames()
	var companion: Grabbable = stage.get_node("Items/Item20")
	Input.action_press("wall_grab")
	Input.action_press("move_right")
	for frame in 90:
		await _step()
		if player.get_held_object() == companion:
			break
	_check(player.get_held_object() == companion, "The safe entrance allows grabbing the companion")
	for leg in 2:
		var launch_x := 450.0 if leg == 0 else 740.0
		for frame in 90:
			var dx := launch_x - player.position.x
			if absf(dx) < 10:
				break
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if dx > 0 else "move_left")
			await _step()
		_release()
		Input.action_press("wall_grab")
		await _step(12)
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		await _step(jump_delay)
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		await _step(dash_delay)
		Input.action_press("move_up")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		var target := Vector2(600, -2696) if leg == 0 else Vector2(860, -2986)
		for frame in 150:
			if not player.is_dashing():
				var dx := target.x - player.position.x
				Input.action_release("move_left")
				Input.action_release("move_right")
				if absf(dx) > 10:
					Input.action_press("move_right" if dx > 0 else "move_left")
			await _step()
			if player.is_on_floor() and absf(player.position.y - target.y) < 2:
				break
		_release()
		Input.action_press("wall_grab")
		_check(player.is_on_floor() and absf(player.position.y - target.y) < 2, "Carried extra jump plus dash reaches the one-way landing")
		await _step(30)
		_check(player.get_held_object() == companion and companion.extra_jump_count() == 1, "Landing keeps the companion and refills its jump")
	_check(stage.checkpoint_index == 5, "The carried route reaches checkpoint 06")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The companion section stays below 30 seconds")
	print("TOWER_COMPANION_SECONDS %.2f delays=%d/%d respawns=%d" % [seconds, jump_delay, dash_delay, respawns])
