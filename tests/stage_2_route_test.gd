extends SceneTree

var stage
var player: PlayerController
var deaths := 0
var retries := 0
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://tower_route_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	progress._cleared.clear()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await scene_changed
	await current_scene.get_node("StageIntro").tree_exited
	stage = current_scene
	player = stage.player
	player.respawned.connect(func():
		if not player.room_transfer_in_progress:
			if Input.is_action_pressed("reset"):
				retries += 1
			else:
				deaths += 1
	)
	await tick(6)
	for route in [[_a, 1], [_b, 2], [_c, 3], [_d, 4], [_e, 5], [_f, 6], [_g, 6]]:
		await route[0].call()
		release()
		_check(deaths == 0 and stage.room_index == route[1], "Continuous main route reaches room %d" % route[1])
		print("TOWER_MAIN_ROUTE ", route[1], " deaths=", deaths)
		if failed:
			break
	_check(progress.get_count("tower") == 0, "The main route needs no optional scroll")
	_check(progress.is_cleared("tower"), "The route boards the real rocket and saves completion")
	if "--record-clear" in OS.get_cmdline_user_args():
		await tick(180)
	elif not failed:
		for route in [[_b_scroll, 2, "spring_alcove"], [_x, 2, "crystal_cavern"], [_y, 3, "crumbling_cavern"], [_z, 5, "bumper_cavern"]]:
			deaths = 0
			await route[0].call()
			release()
			_check(deaths == 0 and stage.room_index == route[1] and progress.has_scroll("tower", route[2]), "Scroll route secures and returns: " + route[2])
			if failed:
				break
		_check(progress.get_count("tower") == 4, "All four scrolls remain saved after retry and return")
	for sound in root.get_node("GameAudio").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	OS.delay_msec(120)
	current_scene = null
	stage.queue_free()
	await tick(3)
	print("STAGE_2_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func tick(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func pos() -> Vector2:
	return player.position - TowerLandscape.origin(stage.room_index)


func raw() -> Vector2:
	return pos() / TowerLandscape.room_scale(stage.room_index)


func release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab"]:
		Input.action_release(action)


func steer(x: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var dx := x - pos().x
	if absf(dx) > 2:
		Input.action_press("move_right" if dx > 0 else "move_left", minf(absf(dx) / 35, 1))


func until(predicate: Callable, frames := 600) -> void:
	for frame in frames:
		if predicate.call() or deaths > 0 or failed:
			return
		await tick()
	_check(false, "Route stalled in room %d at drawing coordinate %s" % [stage.room_index, raw()])


func dash(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y < 0:
		Input.action_press("move_up")
	Input.action_press("dash")
	await tick()
	Input.action_release("dash")
	Input.action_release("move_up")


func walk_to(x: float, climb := false) -> void:
	var arrived := false
	if climb:
		Input.action_press("wall_grab")
		Input.action_press("move_up")
	for frame in 600:
		steer(x * TowerLandscape.room_scale(stage.room_index))
		await tick()
		if absf(raw().x - x) < 0.8 and player.is_on_floor():
			arrived = true
			break
		if deaths > 0 or failed:
			break
	release()
	await tick(3)

	_check(arrived or deaths > 0, "Walk reaches its intended ledge")


func jump_land(x: float, floor_y: float, dash_frame := -1, direction := Vector2.RIGHT) -> void:
	var landed := false
	Input.action_press("jump")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	for frame in 600:
		steer(x * TowerLandscape.room_scale(stage.room_index))
		if frame == dash_frame:
			await dash(direction)
			Input.action_press("move_up")
		await tick()
		var expected := TowerLandscape.foothold(stage.room_index, x, floor_y)
		if player.is_on_floor() and absf(pos().y - expected.y) < 12 and frame > 5:
			landed = true
			break
		if deaths > 0 or failed:
			break
	release()
	await tick(3)

	_check(landed or deaths > 0, "Jump lands on its intended platform")


func _a() -> void:
	await walk_to(17)
	await jump_land(63, 76)
	await walk_to(73)
	await jump_land(104, 48)
	await walk_to(115)
	await jump_land(190, 37, 20)
	await walk_to(207, true)
	Input.action_press("jump")
	await until(func(): return stage.room_index == 1)


func _b() -> void:
	await jump_land(40, 84)
	Input.action_press("jump")
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await tick(3)
	Input.action_release("jump")
	await until(func(): return player.is_on_wall() and raw().x > 55 and raw().y < 75)
	Input.action_press("jump")
	await tick(20)
	await dash(Vector2.RIGHT)
	Input.action_release("jump")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return stage.room_index == 2)


func _c() -> void:
	Input.action_press("jump")
	Input.action_press("move_left")
	await until(func(): return raw().x < 68)
	await dash(Vector2.UP)
	for frame in 180:
		steer(83 * TowerLandscape.room_scale(2))
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(3)
	await walk_to(88)
	Input.action_press("jump")
	Input.action_press("move_right")
	await tick(30)
	await dash(Vector2.RIGHT)
	await until(func(): return raw().x > 180 and pos().y > 80 * TowerLandscape.room_scale(2) + 26)
	_check(player.is_dash_ready(), "The green crystal refills the main-route dash")
	await dash(Vector2.RIGHT)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return stage.room_index == 3)


func _d() -> void:
	await walk_to(33)
	await jump_land(75, 201)
	await walk_to(119, true)
	Input.action_press("jump")
	await tick(20)
	await dash(Vector2.UP)
	for frame in 200:
		steer(145 * TowerLandscape.room_scale(3))
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(2)
	await walk_to(156)
	await jump_land(222, 77, 20, Vector2(1, -1))
	Input.action_press("jump")
	await tick(20)
	await dash(Vector2.UP)
	await until(func(): return stage.room_index == 4)


func _e() -> void:
	await walk_to(145, true)
	await walk_to(156)
	Input.action_press("jump")
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await tick(24)
	Input.action_release("jump")
	await until(func(): return player.is_on_wall() and pos().y < 83 * TowerLandscape.room_scale(4) + 10)
	Input.action_release("move_up")
	Input.action_press("jump")
	for frame in 150:
		steer(204 * TowerLandscape.room_scale(4) + 22)
		await tick()
		if pos().y > 83 * TowerLandscape.room_scale(4) and raw().x > 204:
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await until(func(): return player.is_on_wall() and player.get_wall_normal().x > 0)
	Input.action_press("move_up")
	await until(func(): return pos().y < 83 * TowerLandscape.room_scale(4) + 10)
	await dash(Vector2(1, -1))
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return player.is_on_wall() and raw().x > 270 and pos().y < 51 * TowerLandscape.room_scale(4) + 10)
	Input.action_release("move_up")
	Input.action_press("jump")
	Input.action_press("move_right")
	await until(func(): return stage.room_index == 5)


func _f() -> void:
	var launches := [0, 0]
	var springs: Array = stage.rooms.get_child(5).get_children().filter(func(node): return node.has_signal("launched"))
	springs[0].launched.connect(func(_body): launches[0] += 1)
	springs[1].launched.connect(func(_body): launches[1] += 1)
	await walk_to(33)
	Input.action_press("jump")
	for frame in 180:
		steer(83 * TowerLandscape.room_scale(5))
		await tick()
		if launches[0] > 0 or deaths > 0:
			break
	Input.action_release("move_left")
	Input.action_press("move_right")
	await until(func(): return raw().x > 122 and player.velocity.y > 0)
	await dash(Vector2.RIGHT)
	for frame in 200:
		steer(199 * TowerLandscape.room_scale(5))
		await tick()
		if launches[1] > 0 or deaths > 0:
			break
	Input.action_release("move_left")
	Input.action_press("move_right")
	Input.action_release("jump")
	await until(func(): return player.velocity.y >= 0)
	await dash(Vector2.RIGHT)
	for frame in 250:
		steer(303 * TowerLandscape.room_scale(5))
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(2)
	await walk_to(315)
	await jump_land(400, 138)
	Input.action_press("jump")
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await until(func(): return stage.room_index == 6)


func _g() -> void:
	Input.action_press("move_right")
	await until(func(): return stage.phase == stage.Phase.CLEAR, 600)


func steer_until(x: float, predicate: Callable, frames := 200) -> void:
	for frame in frames:
		steer(x * TowerLandscape.room_scale(stage.room_index))
		await tick()
		if predicate.call() or deaths > 0 or failed:
			return
	_check(false, "Air route stalled at %s" % raw())


func collect_with_jump(x: float) -> void:
	release()
	await tick(3)
	Input.action_press("jump")
	for frame in 100:
		steer(x * TowerLandscape.room_scale(stage.room_index))
		await tick()
		if (player.is_on_floor() and frame > 5) or deaths > 0:
			break
	release()
	await tick(15)


func _b_scroll() -> void:
	stage._enter_room(2, stage.connections[1][5])
	Input.action_press("move_left")
	await until(func(): return stage.room_index == 1)
	release()
	await tick(20)
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await until(func(): return stage.room_index == 2)


func _x() -> void:
	stage._enter_room(7, stage.connections[6][5])
	await tick(5)
	await walk_to(168)
	var crystals: Array = stage.rooms.get_child(7).get_children().filter(func(node): return node.has_signal("collected"))
	Input.action_press("jump")
	Input.action_press("move_left")
	await tick(37)
	await dash(Vector2(-1, -1))
	await until(func(): return not crystals[1]._available and raw().x < 111)
	await dash(Vector2(-1, -1))
	await steer_until(61, func(): return not crystals[0]._available)
	await dash(Vector2(-1, -1))
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return player.is_on_floor())
	await collect_with_jump(16)
	await tick(155)
	await walk_to(36)
	Input.action_press("jump")
	await steer_until(61, func(): return not crystals[0]._available)
	await dash(Vector2(1, -1))
	await steer_until(112, func(): return not crystals[1]._available)
	await dash(Vector2(1, -1))
	await until(func(): return stage.room_index == 2)


func _y() -> void:
	stage._enter_room(8, stage.connections[7][5])
	await tick(5)
	await walk_to(40)
	await jump_land(74, 102)
	await walk_to(82)
	Input.action_press("jump")
	Input.action_press("move_right")
	await tick(26)
	await dash(Vector2.RIGHT)
	await steer_until(169, func(): return player.is_on_floor())
	release()
	await tick(2)
	Input.action_press("jump")
	await tick(20)
	await dash(Vector2.UP)
	Input.action_press("move_right")
	await until(func(): return raw().x > 187 and player.velocity.y >= 0)
	_check(player.is_dash_ready(), "The detour's green diamond restores the upward dash")
	await dash(Vector2.RIGHT)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return player.is_on_floor())
	await collect_with_jump(250)
	await tick(155)
	await jump_land(169, 101, 20, Vector2.LEFT)
	await jump_land(74, 102, 26, Vector2.LEFT)
	await jump_land(38, 102)
	Input.action_press("move_left")
	await until(func(): return stage.room_index == 3)


func _z() -> void:
	stage._enter_room(9, stage.connections[8][5])
	await tick(5)
	await walk_to(66)
	Input.action_press("jump")
	await steer_until(110, func(): return raw().y > 110 and player.velocity.y > 0)
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_press("move_left")
	Input.action_press("wall_grab")
	await until(func(): return player.is_on_wall() and player.get_wall_normal().x > 0)
	Input.action_press("move_down")
	await until(func(): return raw().y > 170)
	Input.action_release("move_down")
	await jump_land(169, 162)
	var launches := [0]
	stage.rooms.get_child(9).get_node("Bumper").launched.connect(func(_body): launches[0] += 1)
	Input.action_press("jump")
	await tick(10)
	await dash(Vector2(1, -1))
	await steer_until(TowerLandscape.BUMPER.x + 16 / TowerLandscape.room_scale(9), func(): return launches[0] > 0)
	Input.action_release("move_left")
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return player.is_on_floor())
	await collect_with_jump(350)
	_check(root.get_node("CollectionProgress").has_scroll("tower", "bumper_cavern"), "The actual bumper route reaches and secures the scroll")
	var before_retry := retries
	Input.action_press("reset")
	await tick()
	Input.action_release("reset")
	await tick(5)
	_check(retries == before_retry + 1, "Retry returns from the bumper scroll without losing its saved collection")
	Input.action_press("move_left")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await until(func(): return stage.room_index == 5)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("TOWER_ROUTE: " + message)
