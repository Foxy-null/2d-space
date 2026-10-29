extends SceneTree

var player: PlayerController
var world: Node2D
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(600, 720), Vector2(2400, 40))
	_solid(Vector2(600, -20), Vector2(2400, 40))
	_solid(Vector2(820, 350), Vector2(40, 300))
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.get_node("Camera2D").enabled = false
	var short := await _height(1)
	var medium := await _height(8)
	var maximum := await _height(30)
	print("JUMP_HEIGHTS short=%.2f medium=%.2f held=%.2f" % [short, medium, maximum])
	_check(short < medium and medium < maximum, "Hold duration changes height continuously")
	_check(short < 45 and maximum > 100 and maximum < 119, "Short jump is small; held jump keeps the original discrete-physics maximum")
	var inverted := await _height(30, -1)
	_check(absf(maximum - inverted) < 3, "Inverted gravity preserves maximum jump height")
	var alias_short := await _height(1, 1, true)
	_check(absf(short - alias_short) < 3, "Holding Up cannot extend a short Space jump")
	await _reset()
	player.position = Vector2(400, 450)
	player.grant_air_jump()
	await _step(2)
	Input.action_press("jump")
	await _step()
	var full_air := player.velocity.y
	Input.action_release("jump")
	await _step()
	_check(full_air < -600 and player.velocity.y > -300, "Manual extra jump is also cut on release")
	await _reset()
	player.queue_free()
	await process_frame
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(782, 350)
	world.add_child(player)
	player.get_node("Camera2D").enabled = false
	Input.action_press("move_right")
	await _step(3)
	Input.action_press("jump")
	await _step()
	_check(player.velocity.y < -500 and player.velocity.x < -600, "Held wall kick keeps its full upward and sideways launch")
	Input.action_release("jump")
	await _step()
	_check(player.velocity.y > -250 and player.velocity.x < -500, "Wall kick release lowers height without cancelling the sideways kick")
	await _reset()
	player.position = Vector2(400, 450)
	player.launch_from_spring(Vector2(0, -650))
	await _step(10)
	_check(player.velocity.y < -300, "Spring launch is not cut by an unpressed Jump")
	Input.action_press("move_up")
	Input.action_press("dash")
	await _step(3)
	_check(player.is_dashing() and player.velocity.y == -player.dash_speed, "Upward dash does not inherit jump release cutting")
	await _reset()
	player.position = Vector2(400, 655)
	player.velocity = Vector2(0, 300)
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	var saw_short := false
	for frame in 20:
		await _step()
		if player.velocity.y < -50:
			saw_short = true
			_check(player.velocity.y > -300, "Released buffered jump is a short jump, not a full jump")
			break
	_check(saw_short, "Released jump buffer still fires on landing")
	_release()
	world.queue_free()
	await process_frame
	print("VARIABLE_JUMP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _height(held_frames: int, gravity := 1, hold_up := false) -> float:
	await _reset(gravity)
	if hold_up:
		Input.action_press("move_up")
		Input.action_press("jump_up")
	Input.action_press("jump")
	var start := player.position.y
	var height := 0.0
	for frame in 70:
		await _step()
		height = maxf(height, (start - player.position.y) * gravity)
		if frame + 1 == held_frames:
			Input.action_release("jump")
	_release()
	return height


func _reset(gravity := 1) -> void:
	_release()
	player.respawn()
	player.position = Vector2(400, 674 if gravity == 1 else 26)
	player.set_gravity_direction(gravity)
	await _step(5)


func _release() -> void:
	for action in ["jump", "jump_up", "move_up", "move_down", "move_right", "move_left", "dash", "wall_grab"]:
		Input.action_release(action)


func _solid(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)


func _step(count := 1) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("VARIABLE_JUMP: " + message)
