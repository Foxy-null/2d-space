extends SceneTree

var player: PlayerController
var wall: StaticBody2D
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	wall = StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 2400)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(640, 360)
	world.add_child(wall)
	player = load("res://scenes/player.tscn").instantiate()
	player.use_default_respawn_bounds = false
	world.add_child(player)
	player.set_physics_process(false)
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		for gravity in [1, -1, 2, -2]:
			for side in [-1, 1]:
				await _contact(gravity, side)
				var down := player.get_gravity_vector()
				var tangent := player.get_walk_axis()
				var before := player.global_position
				var stamina := player.get_wall_stamina()
				_release_directions()
				Input.action_press("jump")
				await _step()
				_check(absf(player.velocity.dot(tangent)) < 0.01 and player.velocity.dot(down) < -600, "Grab + jump launches straight against gravity")
				_check(stamina - player.get_wall_stamina() >= player.wall_climb_jump_cost, "Climb jumps consume wall stamina")
				_check(player.is_dash_ready() and not player.is_air_jump_ready(), "Climb jumps keep dash and air-jump resources")
				await _step(maxi(1, int(rate * 0.1)))
				_check((player.global_position - before).dot(down) < -55 and not player.is_wall_grabbing(), "Holding grab does not cancel the jump's ascent")
				Input.action_release("jump")
				var upward_speed := -player.velocity.dot(down)
				await _step()
				_check(-player.velocity.dot(down) < upward_speed * 0.5, "Releasing jump still shortens the arc")
				player.respawn()
				_check(not player._wall_climb_jumping, "Retry clears climb-jump state")
				await _contact(gravity, side)
				var normal := player.get_wall_normal()
				_press_direction(normal)
				Input.action_press("jump")
				await _step()
				_check(player.velocity.dot(normal) > 650 and not player._wall_climb_jumping, "Pressing away from the wall keeps the outward wall kick")
				await _contact(gravity, side)
				player._wall_stamina = 0
				player._grab_exhausted = true
				Input.action_press("jump")
				await _step()
				_check(not player._wall_climb_jumping and player.velocity.dot(tangent) * side > 0, "Exhaustion leaves the free outward kick available")
	Engine.physics_ticks_per_second = 60
	_release()
	print("WALL_CLIMB_JUMP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _contact(gravity: int, side: int) -> void:
	_release()
	player.respawn()
	player.set_gravity_direction(gravity)
	wall.rotation = PI / 2 if abs(gravity) == 2 else 0.0
	var normal := player.get_walk_axis() * side
	player.global_position = wall.position + normal * 40
	_press_direction(-normal)
	Input.action_press("wall_grab")
	await _step(8)
	_check(player.is_on_wall() and player.is_wall_grabbing(), "Establish a real wall hold")


func _press_direction(direction: Vector2) -> void:
	_release_directions()
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")


func _release_directions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _release() -> void:
	_release_directions()
	for action in ["jump", "jump_up", "dash", "wall_grab"]:
		Input.action_release(action)


func _step(count := 1) -> void:
	for frame in count:
		player.set_physics_process(true)
		await physics_frame
		await process_frame
		player.set_physics_process(false)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
