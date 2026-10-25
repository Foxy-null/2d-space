extends SceneTree

var failed := false
var stage: Node2D
var player: PlayerController
var respawns := 0
var upper_bounces := 0
var upper_strength := 1.0
var upper_jump_delay := 20
var upper_dash_delay := 20


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var collection := root.get_node("CollectionProgress")
	var test_path := "user://tower_route_%d.cfg" % OS.get_process_id()
	collection.save_path = test_path
	collection._collected.clear()
	await _run()
	for path in [test_path, test_path + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "wall_grab", "jump", "dash"]:
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
	_check(stage.checkpoints.get_child_count() == 18, "Eighteen checkpoints")
	_check(player.wall_actions_enabled and player.dash_enabled, "All movement abilities available")
	await _step(20)
	_check(player.is_on_floor(), "Spawn is on a safe platform")
	_check_signage()
	# テレポートなしで全区間を通過し、各区間で既習ギミックをつなぐ。
	for section in 18:
		if section == 0:
			await _wall_course()
			_check(stage.checkpoint_index == 1, "The wall route reaches checkpoint 02")
			_check_signage()
			continue
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
		if section == 5:
			await _finale_course()
			continue
		if section < 12:
			await _upper_course(section)
		else:
			await _more_course(section)
		_check_signage()
	_check(respawns == 0, "The entire tower is traversable without respawning")
	await _step(90)
	_check(stage.completed, "Summit arrival switch completes the stage")
	_check(stage.camera.position.y < -3000, "Camera follows the ascent continuously")
	# 落下・リトライで最新地点に復帰し、能力とクリスタルが回復する。
	player.position.y = 1000
	await _step(3)
	_check(stage.checkpoint_index == 17 and player.position.y < -20000, "Fall returns to latest checkpoint")
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "Respawn restores movement resources")
	var crystal := stage.get_node("Items/Item4")
	var crystal_start: Vector2 = crystal.position
	# Keep the physical pickup fixture inside the current checkpoint bounds.
	crystal.global_position = player.global_position
	await _step(2)
	_check(not crystal.visible, "Collecting a crystal consumes it")
	crystal.position = crystal_start
	Input.action_press("reset")
	await _step(1)
	Input.action_release("reset")
	await _step(3)
	_check(crystal.visible and player.position.y < -20000, "R restores crystals at the latest checkpoint")
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


func _wall_course(grab_delay: int = 0, dash_delay: int = 20) -> void:
	var started := Engine.get_physics_frames()
	_release()
	Input.action_press("move_right")
	for frame in 90:
		await _step()
		if player.is_on_wall(): break
	_check(player.is_on_floor() and player.is_on_wall(), "The first wall can be reached safely by walking on the entrance")
	await _step(grab_delay)
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	var climbed := false
	for frame in 240:
		await _step()
		climbed = climbed or (player.is_wall_grabbing() and player.velocity.y < -100)
		if player.is_on_floor() and absf(player.position.y - 184) < 2: break
	_check(climbed and player.is_on_floor() and absf(player.position.y - 184) < 2, "A real wall climb reaches the broad first rest")
	_release()
	await _step(12)
	_check(player.is_dash_ready() and player.get_wall_stamina() > 2.9, "The broad rest refills dash and wall stamina")
	Input.action_press("move_right")
	for frame in 60:
		if player.position.x >= 680: break
		await _step()
	_release()
	await _step(12)
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	await _step(dash_delay)
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for frame in 180:
		if not player.is_dashing():
			Input.action_release("move_up")
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(player.position.x - 880) > 10:
				Input.action_press("move_right" if player.position.x < 880 else "move_left")
		await _step()
		if stage.checkpoint_index == 1 and player.is_on_floor(): break
	_release()
	_check(stage.checkpoint_index == 1 and player.is_on_floor(), "The first rest leads to safe checkpoint 02")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The opening wall section stays below thirty seconds")
	print("TOWER_WALL_SECONDS %.2f delays=%d/%d respawns=%d" % [seconds, grab_delay, dash_delay, respawns])


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


func _finale_course(spring_delay: int = 40, jump_delay: int = 20, route: String = "combined") -> void:
	var started := Engine.get_physics_frames()
	var carried := player.get_held_object()
	_release()
	if carried != null:
		Input.action_press("wall_grab")
	Input.action_press("move_left")
	for frame in 90:
		await _step()
		if player.velocity.y < -1000:
			break
	_check(player.velocity.y < -1000, "The entrance spring launches the finale")
	for frame in spring_delay:
		if player.position.x <= 780:
			Input.action_release("move_left")
		await _step()
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for frame in 90:
		if not player.is_dashing():
			Input.action_release("move_up")
			if player.position.x > 680:
				Input.action_press("move_left")
			else:
				Input.action_release("move_left")
		await _step()
		if (route == "dash" and not stage.get_node("Items/Item12").visible and not player.is_dashing()) or (route != "dash" and player.is_air_jump_ready()):
			break
	Input.action_release("move_left")
	_check((route == "dash" or player.is_air_jump_ready()) and (route == "jump" or player.is_dash_ready()), "The first aerial dash reaches the chosen crystals")
	if route == "jump":
		await _step(4)
		Input.action_press("move_left")
	if route != "dash":
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		await _step(jump_delay)
	if route != "jump":
		Input.action_press("move_up")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
	for frame in 240:
		if not player.is_dashing():
			Input.action_release("move_up")
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(player.position.x - 360) > 10:
				Input.action_press("move_left" if player.position.x > 360 else "move_right")
			Input.action_release("jump")
		await _step()
		if stage.checkpoint_index == 6:
			break
	_release()
	if carried != null:
		Input.action_press("wall_grab")
	_check(stage.checkpoint_index == 6 and player.is_on_floor(), "The original crystal chain reaches checkpoint 07")
	_check(carried == null or player.get_held_object() == carried, "The finale preserves a companion carried from the previous section")
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(seconds <= 30, "The finale stays below thirty seconds")
	print("TOWER_FINALE_SECONDS %.2f delays=%d/%d route=%s respawns=%d" % [seconds, spring_delay, jump_delay, route, respawns])


func _upper_course(section: int) -> void:
	var started := Engine.get_physics_frames()
	match section:
		6:
			await _upper_wall_rest()
			await _upper_pulse("jump")
			await _step(upper_jump_delay)
			await _upper_dash()
			for frame in 40:
				await _step()
				if not player.is_dashing() and not stage.get_node("Items/UpperDash").visible:
					break
			_check(not stage.get_node("Items/UpperDash").visible, "The wall's upper flight really refills its dash")
			await _upper_dash()
			await _land_on(900, -4666)
		7:
			var keep_companion := player.get_held_object() != null
			_release()
			if keep_companion:
				Input.action_press("wall_grab")
			Input.action_press("move_right", upper_strength)
			await _await_launch()
			_horizontal(420)
			await _step(upper_jump_delay + 26)
			await _upper_pulse("dash")
			await _land_on(420, -5226)
			Input.action_press("move_left", upper_strength)
			await _await_launch()
			_release()
			if keep_companion:
				Input.action_press("wall_grab")
			await _step(upper_jump_delay + 10)
			await _upper_dash()
			await _land_on(360, -5626)
		8:
			await _grab_boot_companion()
			await _boot_transfer(480, "BootRight", 800, -6166)
			await _boot_transfer(790, "BootLeft", 450, -6706)
			await _walk_to(360)
		9:
			if player.get_held_object() == null:
				_release()
				Input.action_press("wall_grab")
				Input.action_press("move_right", upper_strength)
				for frame in 90:
					await _step()
					if player.get_held_object() != null:
						break
				_check(player.get_held_object() == stage.get_node("Items/UpperCompanion"), "The upper entrance provides its real retry companion")
			else:
				_check(player.get_held_object().extra_jump_count() == 1, "The preceding boots preserve the real companion")
			await _upper_companion_rest()
			_check(player.get_held_object() != null, "The wall kicks keep the companion through the midway rest")
			await _walk_to(690)
			await _upper_pulse("jump")
			_horizontal(900)
			await _step(upper_jump_delay)
			await _upper_pulse("jump")
			await _step(upper_dash_delay)
			await _upper_dash()
			await _land_on(900, -8426)
		10:
			upper_bounces = 0
			var bumper: Area2D = stage.get_node("Items/WindBumper")
			if not bumper.launched.is_connected(_on_upper_bounce):
				bumper.launched.connect(_on_upper_bounce)
			_horizontal(780)
			await _await_launch()
			for frame in 160:
				_horizontal(560)
				await _step()
				if upper_bounces > 0:
					break
			_check(upper_bounces == 1 and player.velocity.y < -1000, "The live descent hits the upper face of the suspended bumper")
			_horizontal(360)
			await _step(upper_jump_delay + 5)
			await _upper_dash()
			await _land_on(360, -9566)
		11:
			await _boot_transfer(460, "SummitBoot", 800, -10006)
			_horizontal(1080)
			await _await_launch()
			_horizontal(760)
			await _step(upper_jump_delay + 28)
			await _upper_dash()
			for frame in 90:
				if not player.is_dashing():
					_horizontal(760)
				await _step()
				if not stage.get_node("Items/SummitDash").visible and not player.is_dashing():
					break
			_check(not stage.get_node("Items/SummitDash").visible, "The last flight uses the visible dash crystal")
			await _upper_dash()
			await _land_on(500, -10726, 240)
			await _walk_to(420)
	_check(stage.checkpoint_index == section + 1, "Upper section %d reaches its actual arrival" % (section + 1))
	var seconds := float(Engine.get_physics_frames() - started) / 60.0
	_check(seconds < 30, "Each upper section keeps a short retry interval")
	print("TOWER_UPPER_%d_SECONDS %.2f at=%s respawns=%d" % [section + 1, seconds, player.position, respawns])


func _horizontal(target: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var offset := target - player.position.x
	if absf(offset) > 3:
		Input.action_press("move_right" if offset > 0 else "move_left", minf(absf(offset) / 45.0, 1.0) * upper_strength)


func _walk_to(target: float) -> void:
	for frame in 150:
		_horizontal(target)
		await _step()
		if absf(target - player.position.x) < 3 and absf(player.velocity.x) < 15:
			break
	_horizontal(player.position.x)
	await _step(6)
	_check(absf(player.position.x - target) < 5 and player.is_on_floor(), "Live walking reaches the upper launch position")


func _land_on(target_x: float, target_y: float, limit: int = 180) -> void:
	for frame in limit:
		if not player.is_dashing():
			Input.action_release("move_up")
			_horizontal(target_x)
		await _step()
		if player.is_on_floor() and absf(player.position.y - target_y) < 3:
			_horizontal(player.position.x)
			await _step(8)
			if player.is_on_floor() and absf(player.position.y - target_y) < 3:
				return
	_check(false, "A real upper flight lands at %s from %s" % [Vector2(target_x, target_y), player.position])


func _upper_pulse(action: String) -> void:
	Input.action_press(action)
	await _step()
	Input.action_release(action)


func _upper_dash() -> void:
	_horizontal(player.position.x)
	Input.action_press("move_up")
	await _upper_pulse("dash")


func _await_launch() -> void:
	for frame in 150:
		await _step()
		if player.velocity.y < -900:
			return
	_check(false, "Walking reaches the actual upper spring")


func _boot_transfer(launch_x: float, boot_name: String, target_x: float, target_y: float) -> void:
	await _walk_to(launch_x)
	await _upper_pulse("jump")
	_horizontal(target_x)
	await _step(upper_jump_delay)
	_check(not stage.get_node("Items/" + boot_name).visible and player.is_air_jump_ready(), "An upper jump really collects " + boot_name)
	await _upper_pulse("jump")
	await _step(upper_dash_delay)
	if boot_name in ["BootRight", "BootLeft"]:
		_check(player.get_held_object() != null, "The upper boots combine with a genuinely held companion")
		await _upper_pulse("jump")
		await _step(upper_dash_delay)
	await _upper_dash()
	await _land_on(target_x, target_y)


func _on_upper_bounce(_body: PlayerController) -> void:
	upper_bounces += 1


func _upper_wall_rest() -> void:
	_release()
	await _step(8)
	Input.action_press("move_right", upper_strength)
	for frame in 180:
		await _step()
		if player.is_on_wall():
			break
	_check(player.is_on_floor() and player.is_on_wall(), "Walk away from the dropped companion before grabbing the upper wall")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	for frame in 240:
		await _step()
		if player.is_on_floor() and player.position.y < -4250:
			break
	_release()
	_check(player.is_on_floor() and absf(player.position.y + 4306) < 3, "The upper wall has a real broad rest")
	await _walk_to(1030)


func _upper_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	await _step(20)
	var folder := "res://docs/screenshots/tower-expansion"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var captured := root.get_viewport().get_texture().get_image()
	_check(captured.save_png(folder + "/" + label + ".png") == OK, "The tower expansion screenshot saves")


func _upper_companion_rest() -> void:
	await _walk_to(610)
	await _upper_pulse("jump")
	Input.action_press("move_right", upper_strength)
	for frame in 600:
		if player.is_on_wall():
			var side := player.get_wall_normal().x
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if side > 0 else "move_left", upper_strength)
			await _upper_pulse("jump")
		await _step()
		if player.position.y < -8000:
			break
	await _land_on(620, -7986)


func _grab_boot_companion() -> void:
	if player.get_held_object() != null:
		return
	_release()
	Input.action_press("wall_grab")
	Input.action_press("move_right", upper_strength)
	for frame in 90:
		await _step()
		if player.get_held_object() != null:
			break
	_check(player.get_held_object() == stage.get_node("Items/BootCompanion"), "The zigzag provides its real companion on the safe entrance")


func _more_walk(target: float) -> void:
	for frame in 500:
		_horizontal(target)
		await _step()
		if absf(target - player.position.x) < 3 and absf(player.velocity.x) < 15: break
	_horizontal(player.position.x)
	await _step(6)
	_check(absf(player.position.x - target) < 5 and player.is_on_floor(), "Walking reaches the new launch at %s" % target)


func _more_climb(wall_name: String, from_right: bool = false) -> void:
	var wall: StaticBody2D = stage.get_node("Terrain/" + wall_name)
	var collision: CollisionShape2D = wall.get_node("Collision")
	var top: float = collision.to_global(collision.shape.get_rect().position).y
	_release()
	Input.action_press("move_left" if from_right else "move_right", upper_strength)
	if wall_name == "More13Wall":
		await _more_walk(380)
		Input.action_press("move_right", upper_strength)
		await _upper_pulse("jump")
	for frame in 180:
		await _step()
		if player.is_on_wall(): break
	_check(player.is_on_wall() and (player.is_on_floor() or wall_name == "More13Wall"), "The new wall is approached from the real floor")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	for frame in 240:
		await _step()
		if player.is_on_floor() and player.position.y < top: break
	_release()
	_check(player.is_on_floor() and absf(player.position.y - top + 26) < 3, "A live climb reaches " + wall_name)


func _more_refill(name: String, launch: float, target: Vector2) -> void:
	await _more_walk(launch)
	await _upper_pulse("jump")
	await _step(upper_jump_delay)
	await _upper_dash()
	for frame in 60:
		await _step()
		if not player.is_dashing() and not stage.get_node("Items/" + name).visible: break
	_check(not stage.get_node("Items/" + name).visible, "A real spent dash collects " + name)
	await _upper_dash()
	await _land_on(target.x, target.y - 26, 240)


func _more_spring(launch: float, target: Vector2) -> void:
	_horizontal(launch)
	await _await_launch_long()
	_horizontal(target.x)
	await _land_on(target.x, target.y - 26, 240)


func _await_launch_long() -> void:
	for frame in 500:
		await _step()
		if player.velocity.y < -900: return
	_check(false, "The long live traverse reaches its spring")


func _more_grab(name: String) -> void:
	Input.action_press("wall_grab")
	if player.get_held_object() != null: return
	for frame in 180:
		if player.get_held_object() != null: break
		_horizontal(stage.get_node("Items/" + name).position.x)
		await _step()
	_check(player.get_held_object() == stage.get_node("Items/" + name), "The actual new companion is acquired: " + name)


func _more_boot(launch: float, name: String, target: Vector2) -> void:
	await _more_walk(launch)
	await _upper_pulse("jump")
	_horizontal(target.x)
	await _step(upper_jump_delay)
	_check(player.is_air_jump_ready() and not stage.get_node("Items/" + name).visible, "The live jump collects " + name)
	await _upper_pulse("jump")
	await _step(upper_dash_delay)
	await _upper_pulse("jump")
	await _step(upper_dash_delay)
	await _upper_dash()
	await _land_on(target.x, target.y - 26, 240)


func _more_bounce(launch: float, bumper_name: String, target: Vector2) -> void:
	upper_bounces = 0
	var bumper: Area2D = stage.get_node("Items/" + bumper_name)
	if not bumper.launched.is_connected(_on_upper_bounce): bumper.launched.connect(_on_upper_bounce)
	_horizontal(launch)
	await _await_launch_long()
	for frame in 180:
		_horizontal(bumper.position.x)
		await _step()
		if upper_bounces > 0: break
	_check(upper_bounces == 1 and player.velocity.y < -1000, "The real suspended bumper reflects the descent upward")
	_horizontal(target.x)
	await _step(upper_jump_delay + 5)
	await _upper_dash()
	await _land_on(target.x, target.y - 26, 240)


func _more_course(section: int) -> void:
	var started := Engine.get_physics_frames()
	match section:
		12:
			await _more_walk(390)
			await _more_climb("More13Wall")
			await _more_refill("More13Dash", 700, Vector2(700, -11800))
			await _more_spring(1900, Vector2(1450, -12460))
			await _more_walk(1450)
		13:
			await _more_bounce(1300, "More14Bumper", Vector2(800, -13600))
			await _more_spring(-800, Vector2(-400, -14260))
			await _more_walk(-400)
		14:
			await _more_grab("More15Companion")
			await _more_boot(350, "More15BootA", Vector2(900, -14800))
			await _more_boot(1350, "More15BootB", Vector2(850, -15340))
			await _more_walk(600)
			await _more_climb("More15Wall", true)
			await _more_walk(650)
		15:
			await _more_air_rest()
			await _more_refill("More16Dash", 1400, Vector2(1200, -18080))
			await _more_walk(1200)
		16:
			await _more_grab("More17Companion")
			await _more_bounce(1050, "More17Bumper", Vector2(500, -19220))
			await _more_boot(200, "More17Boot", Vector2(900, -19760))
			await _more_spring(1600, Vector2(1300, -20420))
			await _more_walk(1300)
		17:
			await _more_grab("More18Companion")
			await _more_boot(1200, "More18Boot", Vector2(800, -20960))
			await _more_walk(450)
			await _more_climb("More18Wall", true)
			_horizontal(230)
			await _await_launch_long()
			_horizontal(-50)
			await _step(upper_jump_delay + 28)
			await _upper_dash()
			for frame in 90:
				if not player.is_dashing(): _horizontal(-50)
				await _step()
				if not stage.get_node("Items/More18Dash").visible and not player.is_dashing(): break
			_check(not stage.get_node("Items/More18Dash").visible, "The last flight really uses its dash refill")
			await _upper_dash()
			await _land_on(-100, -22346, 240)
			for frame in 240:
				_horizontal(-400)
				Input.action_release("jump")
				if player.is_on_floor() and player.is_on_wall(): Input.action_press("jump")
				if player.position.x < -345: _horizontal(player.position.x)
				await _step()
				if stage.completed: break
	_release()
	var seconds := (Engine.get_physics_frames() - started) / 60.0
	_check(stage.completed if section == 17 else stage.checkpoint_index == section + 1, "The live new section reaches its next checkpoint: %d" % (section + 1))
	_check(seconds < 30, "Each new checkpoint remains within thirty seconds")
	print("TOWER_MORE_%02d seconds=%.2f position=%s respawns=%d" % [section + 1, seconds, player.position, respawns])


func _more_wall_rest(with_companion: bool = true) -> void:
	if with_companion: await _more_grab("More16Companion")
	await _more_walk(650)
	await _upper_pulse("jump")
	Input.action_press("move_right", upper_strength)
	for frame in 650:
		if player.is_on_wall():
			var side := player.get_wall_normal().x
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if side > 0 else "move_left", upper_strength)
			await _upper_pulse("jump")
		await _step()
		if (player.is_on_floor() and player.position.y < -17140) or player.position.y < -17170: break
	await _land_on(650, -17166, 240)
	if failed: return


func _more_air_rest() -> void:
	await _more_wall_rest()
	await _more_walk(750)
	await _upper_pulse("jump")
	_horizontal(1050)
	await _step(upper_jump_delay)
	await _upper_pulse("jump")
	await _step(upper_dash_delay)
	await _upper_dash()
	await _land_on(1050, -17606, 240)
