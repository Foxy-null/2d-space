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


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage3").pressed.emit()
	await _step(4)
	_check(current_scene.scene_file_path == "res://scenes/stage_3.tscn", "Stage 3 selection opens the tower")
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	_check(stage.checkpoints.get_child_count() == 6, "Six checkpoints")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement abilities available")
	await _step(20)
	_check(player.is_on_floor(), "Spawn is on a safe platform")
	# テレポートなしで全区間を、ジャンプ・壁掴み・登りで通過する。
	# アイテムを使い損ねても休憩足場経由で復帰できることも確認する。
	for section in 6:
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
		print("区間 %d 登頂確認 / 復帰 %d" % [section + 1, respawns])
	_check(respawns == 0, "The entire fallback route is traversable without respawning")
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
	stage.set_help_visible(true)
	var before := player.position
	Input.action_press("move_right")
	await _step(15)
	_check(player.position == before, "Help menu suspends player input")
	_release()
	stage.set_help_visible(false)
	stage._set_hints(true)
	stage._retry()
	await _step(3)
	_check(stage.hints_visible, "Retry preserves hint setting")
	stage._return_to_select()
	await _step(3)
	current_scene.get_node("Margin/Content/Stages/Stage3").pressed.emit()
	await _step(4)
	_check(current_scene.checkpoint_index == 0 and not current_scene.completed, "Re-entry starts a new climb")
	current_scene.queue_free()
	await _step(3)
	print("STAGE_3_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)
