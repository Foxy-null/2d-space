extends SceneTree

var world: Node
var player: PlayerController
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for pause in range(6, 18):
		await _tower_retry(pause)
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		for phase in [16, 20, 24]:
			await _fast_moving_gate(rate, phase)
	Engine.physics_ticks_per_second = 60
	_release()
	print("GIMMICK_RETRY_CONTACT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _tower_retry(pause: int) -> void:
	_clear()
	world = load("res://scenes/stage_2.tscn").instantiate()
	root.add_child(world)
	player = world.player
	world._enter_room(1, Vector2(950, 614))
	await _step(6)
	var launches := [0, 0]
	var spring: Area2D = world.rooms.get_child(1).find_children("*", "Area2D", false, false).filter(func(node): return node.has_signal("launched"))[0]
	spring.launched.connect(func(body):
		launches[0] += 1
		if body.position.x < TowerLandscape.origin(1).x + 1030:
			launches[1] += 1
	)
	Input.action_press("move_right")
	await _step(pause)
	Input.action_press("reset")
	await _step()
	_release()
	await _step(6)
	_check(launches[1] == 0 and player.position.distance_to(TowerLandscape.origin(1) + Vector2(950, 614)) < 3 and absf(player.velocity.y) < 1, "R at spring contact restores the entrance without a remote launch: %d" % pause)
	var before: int = launches[0]
	Input.action_press("move_right")
	for frame in 40:
		if launches[0] > before:
			break
		await _step()
	_release()
	_check(launches[0] == before + 1 and player.velocity.y < -900 and player.is_dash_ready(), "The same real spring works again immediately after retry: %d" % pause)


func _fast_moving_gate(rate: int, phase: int) -> void:
	_clear()
	world = Node2D.new()
	root.add_child(world)
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(400, 350)
	world.add_child(player)
	player.set_physics_process(false)
	await _step(3)
	var gate = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(300 + phase, 350)
	gate.move_offset = Vector2(400, 0)
	gate.move_speed = 2000
	gate.moving_enabled = true
	var shape: CollisionShape2D = gate.get_node("CollisionShape2D")
	shape.shape = shape.shape.duplicate()
	shape.shape.size = Vector2(4, 160)
	var entered := [0]
	gate.body_entered.connect(func(body):
		if body == player:
			entered[0] += 1
	)
	world.add_child(gate)
	await _step(20)
	_check(entered[0] == 1 and player.gravity_direction == -1, "A thin moving gate still applies a real fast contact: %dHz phase%d" % [rate, phase])


func _clear() -> void:
	_release()
	if is_instance_valid(world):
		world.free()


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)
