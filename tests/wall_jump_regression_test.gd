extends SceneTree

var failed := false
var checks := 0
var player: PlayerController
var world: Node2D
var actions: Array[String] = []
var minimum_height_loss := INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 2400)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(820, 350)
	world.add_child(wall)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.movement_action.connect(func(action: String): actions.append(action))
	await physics_frame
	for tick_rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = tick_rate
		for gravity in [1, -1]:
			for side in [-1, 1]:
				for held_scene in ["", "heavy_object", "parachute_creature"]:
					await _repeat_kicks(tick_rate, gravity, side, held_scene, false)
					if held_scene == "parachute_creature":
						await _repeat_kicks(tick_rate, gravity, side, held_scene, true)
	print("WALL_JUMP_REGRESSION_TEST_%s (%d checks, minimum height loss %.2f px)" % ["FAILED" if failed else "OK", checks, minimum_height_loss])
	quit(1 if failed else 0)


func _step(count: int = 1) -> void:
	for frame in count:
		player.set_physics_process(true)
		await physics_frame
		await process_frame
		player.set_physics_process(false)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("WALL_JUMP: " + message)


func _repeat_kicks(tick_rate: int, gravity: int, side: int, held_scene: String, windy: bool) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab"]:
		Input.action_release(action)
	player.respawn()
	player.global_position = Vector2(820 + side * 40, -120 if gravity > 0 else 800)
	player.set_gravity_direction(gravity)
	var toward_wall := "move_right" if side < 0 else "move_left"
	Input.action_press(toward_wall)
	await _step(8)
	var label := "fps=%d g=%d side=%d held=%s wind=%s" % [tick_rate, gravity, side, held_scene, windy]
	_check(player.is_on_wall(), "initial contact " + label)
	var object: Grabbable
	if not held_scene.is_empty():
		object = load("res://scenes/" + held_scene + ".tscn").instantiate()
		object.position = player.position + Vector2(side * 40, 0)
		world.add_child(object)
		await physics_frame
		_check(player.try_begin_grab(object), "hold object " + label)
		Input.action_press("wall_grab")
	var wind: Node2D
	if windy:
		wind = Node2D.new()
		world.add_child(wind)
		player.register_wind(wind, Vector2(-side * 900, 0), 450)
	# Heavy objects slow the return enough that a second kick would leave the
	# playable vertical bounds; the first complete return still checks the arc.
	for cycle in (1 if held_scene == "heavy_object" else 3):
		player._wall_stamina = [1.25, 0.0, player.wall_stamina_max][cycle]
		player._grab_exhausted = player.get_wall_stamina() == 0.0
		var stamina := player.get_wall_stamina()
		var start_height := player.position.y * gravity
		var jump_action := "jump_up" if cycle == 1 else "jump"
		actions.clear()
		Input.action_press(jump_action)
		await _step()
		Input.action_release(jump_action)
		_check(actions == ["wall_jump"], "wall kick remains available " + label)
		_check(not player.is_on_wall() and player.velocity.x * side > 0 and player.velocity.y * gravity < 0, "kick leaves wall against gravity " + label)
		var returned := false
		for frame in tick_rate * 2:
			await _step()
			if player.is_on_wall():
				returned = true
				break
		_check(returned, "direction input returns to same wall " + label)
		_check(is_equal_approx(player.get_wall_stamina(), stamina), "wall kick is free " + label)
		var height_loss := player.position.y * gravity - start_height
		minimum_height_loss = minf(minimum_height_loss, height_loss)
		var no_gain := height_loss >= 1.0
		_check(no_gain, "same-wall cycle cannot gain height: %.2f px %s" % [start_height - player.position.y * gravity, label])
		if not returned or not no_gain:
			break
	if is_instance_valid(wind):
		player.unregister_wind(wind)
		wind.free()
	if is_instance_valid(object):
		object.free()
	Input.action_release("wall_grab")
