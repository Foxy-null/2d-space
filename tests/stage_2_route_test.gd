extends SceneTree

var stage
var player: PlayerController
var deaths := 0
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
	if not failed:
		for detour in [[_x, 2, "crystal_cavern"], [_y, 3, "crumbling_cavern"]]:
			deaths = 0
			await detour[0].call()
			release()
			_check(deaths == 0 and stage.room_index == detour[1] and progress.has_scroll("tower", detour[2]), "The detour secures its scroll and physically returns: " + detour[2])
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


func release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab"]:
		Input.action_release(action)


func steer(x: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var dx := x - pos().x
	if absf(dx) > 2:
		Input.action_press("move_right" if dx > 0 else "move_left", minf(absf(dx) / 35, 1))


func until(predicate: Callable, frames := 180) -> void:
	for frame in frames:
		if predicate.call() or deaths > 0:
			return
		await tick()
	_check(false, "Route stalled in room %d at %s" % [stage.room_index, pos()])


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


func jump_to(x: float, dash_frame := -1) -> void:
	Input.action_press("jump")
	for frame in 120:
		steer(x * TowerLandscape.SCALE)
		if frame == dash_frame:
			Input.action_press("dash")
		if frame == dash_frame + 1:
			Input.action_release("dash")
		await tick()
		if deaths > 0 or (player.is_on_floor() and frame > 5):
			break
	release()
	await tick(3)


func _a() -> void:
	await jump_to(62)
	await jump_to(104)
	await jump_to(188, 4)
	Input.action_press("jump")
	await until(func(): return stage.room_index == 1)


func _b() -> void:
	Input.action_press("jump")
	Input.action_press("move_left")
	await tick(3)
	Input.action_release("jump")
	await until(func(): return pos().y < 95)
	await dash(Vector2.RIGHT)
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	for frame in 180:
		steer(157 * TowerLandscape.SCALE)
		await tick()
		if stage.room_index == 2 or deaths > 0:
			break


func _c() -> void:
	Input.action_press("move_left")
	Input.action_press("jump")
	await tick(14)
	Input.action_release("jump")
	await dash(Vector2.UP)
	for frame in 120:
		steer(83 * TowerLandscape.SCALE)
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(3)
	Input.action_press("jump")
	Input.action_press("move_right")
	await until(func(): return pos().x > 180 * TowerLandscape.SCALE - TowerLandscape.PLAYER_HALF_HEIGHT and pos().y > 80 * TowerLandscape.SCALE + TowerLandscape.PLAYER_HALF_HEIGHT)
	await dash(Vector2.RIGHT)
	await until(func(): return stage.room_index == 3)


func _d() -> void:
	await jump_to(112)
	Input.action_press("jump")
	await tick(10)
	await dash(Vector2.UP)
	for frame in 100:
		steer(143 * TowerLandscape.SCALE)
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(2)
	await jump_to(222)
	Input.action_press("jump")
	await until(func(): return stage.room_index == 4)


func _e() -> void:
	await jump_to(144)
	Input.action_press("jump")
	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	for frame in 100:
		if frame == 24:
			Input.action_release("jump")
		await tick()
		if player.is_on_wall() and pos().y < 147:
			break
	Input.action_release("jump")
	await tick()
	Input.action_press("jump")
	await tick(6)
	Input.action_release("wall_grab")
	await dash(Vector2(1, -1))
	Input.action_press("wall_grab")
	await until(func(): return player.is_on_wall() and pos().x > 450)
	Input.action_press("move_down")
	await until(func(): return pos().y >= 158)
	Input.action_release("move_down")
	Input.action_release("jump")
	await tick()
	Input.action_press("jump")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await tick()
	Input.action_release("jump")
	await until(func(): return player.is_on_wall() and pos().x < 400)
	Input.action_press("move_up")
	await until(func(): return pos().y < 130)
	Input.action_press("jump")
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_left")
	Input.action_press("move_right")
	await until(func(): return stage.room_index == 5)


func _f() -> void:
	var launches := [0, 0]
	var springs: Array = stage.rooms.get_child(5).get_children().filter(func(node): return node.has_signal("launched"))
	springs[0].launched.connect(func(_body): launches[0] += 1)
	springs[1].launched.connect(func(_body): launches[1] += 1)
	Input.action_press("jump")
	for frame in 100:
		steer(83 * TowerLandscape.SCALE)
		await tick()
		if launches[0] > 0:
			break
	Input.action_release("move_left")
	Input.action_press("move_right")
	await until(func(): return player.is_on_wall())
	Input.action_release("move_right")
	await until(func(): return pos().y > 127 and player.velocity.y > 0)
	await dash(Vector2.RIGHT)
	for frame in 130:
		steer(199 * TowerLandscape.SCALE)
		await tick()
		if launches[1] > 0 or deaths > 0:
			break
	Input.action_release("move_left")
	Input.action_press("move_right")
	Input.action_release("jump")
	await until(func(): return pos().y < 80)
	await dash(Vector2.RIGHT)
	await until(func(): return pos().x > 600 and pos().y > 200)
	Input.action_press("move_up")
	Input.action_press("wall_grab")
	await until(func(): return stage.room_index == 6)


func _g() -> void:
	Input.action_press("move_right")
	await until(func(): return stage.phase == stage.Phase.CLEAR, 250)


func _x() -> void:
	stage._enter_room(7, stage.connections[6][5])
	await tick(5)
	var crystals: Array = stage.rooms.get_child(7).get_children().filter(func(node): return node.has_signal("collected"))
	Input.action_press("move_left")
	await tick(7)
	Input.action_press("jump")
	for frame in 120:
		steer(112 * TowerLandscape.SCALE)
		await tick()
		if not crystals[1]._available or deaths > 0:
			break
	await dash(Vector2.LEFT)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	await until(func(): return player.is_on_floor())
	release()
	await tick(15)
	_check(not crystals[0]._available and not crystals[1]._available, "Both green diamonds refill the dash on the detour")
	await jump_to(190, 6)
	Input.action_press("move_right")
	await until(func(): return stage.room_index == 2)


func _y() -> void:
	stage._enter_room(8, stage.connections[7][5])
	await tick(5)
	await jump_to(74)
	Input.action_press("jump")
	await tick()
	Input.action_release("jump")
	await until(func(): return pos().y < 132)
	await dash(Vector2.RIGHT)
	for frame in 100:
		steer(169 * TowerLandscape.SCALE)
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(2)
	Input.action_press("move_right")
	Input.action_press("jump")
	for frame in 90:
		steer(250 * TowerLandscape.SCALE)
		if frame == 11:
			Input.action_release("jump")
		await tick()
		if (player.is_on_floor() and frame > 5) or deaths > 0:
			break
	release()
	# Wait on the permanent floor for the two crumbling boards to return.
	await tick(176)
	Input.action_press("jump")
	Input.action_press("move_left")
	await tick(3)
	Input.action_release("jump")
	await until(func(): return pos().y < 65)
	await dash(Vector2.LEFT)
	for frame in 100:
		steer(169 * TowerLandscape.SCALE)
		await tick()
		if player.is_on_floor() or deaths > 0:
			break
	release()
	await tick(2)
	Input.action_press("jump")
	await tick()
	Input.action_release("jump")
	await until(func(): return pos().y < 132)
	await dash(Vector2.LEFT)
	await until(func(): return stage.room_index == 3)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("TOWER_ROUTE: " + message)
