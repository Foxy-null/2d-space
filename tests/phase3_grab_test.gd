extends SceneTree

var world: Node2D
var player: PlayerController
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _reset()
	await _grab_tests()
	await _collision_tests()
	await _throw_tests()
	await _jump_tests()
	await _heavy_tests()
	await _parachute_tests()
	await _environment_tests()
	await _button_tests()
	await _respawn_tests()
	print("PHASE3_GRAB_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("PHASE3: " + label)


func _near(value: float, expected: float, label: String) -> void:
	_check(absf(value - expected) < 0.2, "%s: %s expected %s" % [label, value, expected])


func _vector(value: Vector2, expected: Vector2, label: String) -> void:
	_check(value.distance_to(expected) < 0.2, "%s: %s expected %s" % [label, value, expected])


func _sync(count := 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _step(count := 1) -> void:
	for i in count:
		player.set_physics_process(true)
		await _sync(1)
		player.set_physics_process(false)
		if player.get_held_object() != null:
			_assert_shapes_clear(player.get_held_object())


func _reset(at := Vector2(400, 350)) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash", "jump", "wall_grab"]:
		Input.action_release(action)
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(1000, 720), Vector2(4000, 40))
	_solid(Vector2(1000, -20), Vector2(4000, 40))
	player = load("res://scenes/player.tscn").instantiate()
	player.position = at
	world.add_child(player)
	player.set_physics_process(false)
	await _sync()


func _solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = at
	world.add_child(body)
	return body


func _object(name := "jump_creature", offset := Vector2(40, 0)) -> Grabbable:
	var object: Grabbable = load("res://scenes/" + name + ".tscn").instantiate()
	object.position = player.position + offset
	world.add_child(object)
	# Freeze fixtures until grabbed/released; release tests run real rigid physics.
	object.freeze = true
	return object


func _hold(object: Grabbable) -> void:
	Input.action_press("wall_grab")
	_check(player.try_begin_grab(object), "grab " + object.carry_name)


func _grab_tests() -> void:
	await _reset(Vector2(400, 674))
	var settled := _object("heavy_object", Vector2(40, 0))
	settled.freeze = false
	await _sync(60)
	_hold(settled)
	await _reset()
	_check(InputMap.has_action("wall_grab"), "shared action")
	_near(player.grab_range, 60, "range default")
	var far := _object("heavy_object", Vector2(40, -40))
	var near := _object()
	await _sync()
	Input.action_press("wall_grab")
	await _step()
	_check(player.get_held_object() == near, "nearest valid object priority")
	_check(not player.is_wall_grabbing(), "object suppresses wall grab")
	await _step(3)
	_check(player.get_held_object() == near and near.freeze, "hold retains frozen body")
	Input.action_release("wall_grab")
	await _step()
	_check(player.get_held_object() == null and not near.freeze, "button release restores physics")
	far.free()
	await _reset()
	var outside := _object("jump_creature", Vector2(61, 0))
	await _sync()
	_check(not player.try_begin_grab(outside), "center outside grab range")
	await _reset()
	var object := _object()
	await _sync()
	Input.action_press("wall_grab")
	Input.action_press("dash")
	await _step()
	_check(player.is_dashing() and player.get_held_object() == null, "no new grab on dash frame")
	Input.action_release("dash")
	while player.is_dashing():
		object.position = player.position + Vector2(40, 0)
		await _step()
	object.position = player.position + Vector2(40, 0)
	await _sync()
	await _step()
	_check(player.get_held_object() == object, "held input grabs after dash ends")
	await _reset(Vector2(780, 350))
	_solid(Vector2(820, 350), Vector2(40, 300))
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	await _step(5)
	_check(player.is_wall_grabbing(), "no object falls back to wall grab")
	var blocked := _object("jump_creature", Vector2(-40, 0))
	await _sync()
	await _step()
	_check(player.get_held_object() == null and player.is_wall_grabbing(), "unsafe object falls back to wall grab")
	Input.action_release("move_right")
	player.facing_direction = -1
	await _step()
	_check(player.get_held_object() == blocked and not player.is_wall_grabbing(), "valid object takes priority over existing wall grab")


func _collision_tests() -> void:
	for at in [Vector2(400, 674), Vector2(400, 26)]:
		await _reset(at)
		player.set_gravity_direction(1 if at.y > 350 else -1)
		var carried := _object("heavy_object")
		await _sync()
		_hold(carried)
		Input.action_press("move_left")
		await _step(35)
		_check(carried.position.x < player.position.x, "turn beside actual floor/ceiling")
	for gravity in [1, -1]:
		for facing in [1, -1]:
			await _reset()
			player.facing_direction = facing
			player.set_gravity_direction(gravity)
			var object := _object("heavy_object", Vector2(40 * facing, 0))
			await _sync()
			_hold(object)
			_vector(object.position - player.position, Vector2(40 * facing, 0), "world carry offset")
			_check(object.is_position_safe(object.position, player), "player shape separation")
			player.set_gravity_direction(-gravity)
			await _step(2)
			_near(object.position.y - player.position.y, 0, "gravity does not flip offset")
			_near(object.rotation, 0, "gravity does not rotate object")
			Input.action_press("move_right" if facing < 0 else "move_left")
			await _step(30)
			_check(signf(object.position.x - player.position.x) == -facing, "safe facing turn completes")
	await _reset()
	var object := _object("jump_creature", Vector2(32, 0))
	_solid(Vector2(452, 350), Vector2(10, 200))
	await _sync()
	_hold(object)
	_check(object.position.x < 440 and object.position.x > 430, "wall forces safe inward offset")
	Input.action_press("move_right")
	await _step(30)
	_check(player.position.x < 420, "carry blocks player at wall")
	await _reset()
	object = _object()
	_solid(Vector2(440, 350), Vector2(4, 200))
	await _sync()
	_check(not player.try_begin_grab(object), "no safe carry space")
	await _reset()
	object = _object("jump_creature", Vector2(58, 0))
	_solid(Vector2(443, 350), Vector2(2, 200))
	await _sync()
	_check(not player.try_begin_grab(object), "cannot teleport object through thin wall")
	for movement in [Vector2(0, 900), Vector2(0, -900), Vector2(900, 0)]:
		await _reset()
		object = _object("heavy_object")
		_solid(Vector2(600, 350), Vector2(20, 300))
		await _sync()
		_hold(object)
		player.launch_from_spring(movement)
		await _step(35)
		_check(player.get_held_object() == object, "launch and floor ceiling solid contacts retain carry")
	await _reset()
	object = _object()
	await _sync()
	_hold(object)
	var obstruction := _solid(object.position, Vector2(100, 100))
	await _sync()
	_check(not player.release_grab() and player.get_held_object() == object, "unsafe release stays held")
	obstruction.free()
	await _sync()
	_check(player.release_grab(), "release retries when safe")
	await _reset()
	object = _object()
	var other := _object("heavy_object", Vector2(43, 0))
	await _sync()
	_check(not player.try_begin_grab(object), "other physics body prevents overlap")
	other.free()
	await _reset()
	object = _object()
	await _sync()
	_hold(object)
	player.position.x += 12
	_check(player.release_grab(), "small unsafe release corrects player overlap")
	_assert_shapes_clear(object)


func _throw_tests() -> void:
	for name in ["jump_creature", "heavy_object", "parachute_creature"]:
		for motion in [Vector2.ZERO, Vector2(79, 0), Vector2(80, 0), Vector2(-100, 0), Vector2(0, -100), Vector2(0, 100), Vector2(120, -160)]:
			await _reset()
			var object := _object(name)
			await _sync()
			_hold(object)
			var speed := 300.0 if name == "heavy_object" else 450.0
			_near(object.throw_speed, speed, "throw speed default")
			player.velocity = motion
			_check(player.release_grab(), "safe release")
			_vector(object.linear_velocity, motion + (motion.normalized() * speed if motion.length() >= 80 else Vector2.ZERO), "velocity direction / threshold / momentum")
	await _reset()
	var object := _object()
	await _sync()
	_hold(object)
	Input.action_release("wall_grab")
	Input.action_press("dash")
	await _step()
	_check(player.is_dashing() and player.get_held_object() == null, "same frame dash release")
	_near(object.linear_velocity.x, 1350, "dash throw from rest")
	for scene in ["spring", "pinball_spring"]:
		await _reset()
		object = _object()
		await _sync()
		_hold(object)
		var spring = load("res://scenes/" + scene + ".tscn").instantiate()
		spring.position = Vector2(400, 380)
		world.add_child(spring)
		player.velocity = Vector2(120, 500)
		spring._on_body_entered(player)
		var launch := player.velocity
		_check(launch.y < 0, scene + " launch")
		_check(player.get_held_object() == object, scene + " retain")
		_check(player.release_grab(), scene + " release")
		_vector(object.linear_velocity, launch + launch.normalized() * 450, scene + " throw")


func _jump_tests() -> void:
	await _reset()
	var object := _object()
	await _sync()
	_hold(object)
	_check(player.get_available_extra_jump_count() == 1, "creature only one")
	player.refill_from_crystal()
	_check(player.get_available_extra_jump_count() == 2, "crystal plus creature two")
	await _sync(1)
	_check(object.get_node("Count").text == "2" and object.get_node("Count").visible, "held label 2")
	player._jump_buffer_left = 0.1
	player._try_jump(false, false)
	_check(not player.is_air_jump_ready() and object.extra_jump_count() == 1, "crystal consumed first")
	await _sync(1)
	_check(object.get_node("Count").text == "1", "label 2 to 1")
	player._jump_buffer_left = 0.1
	player._try_jump(false, false)
	_check(player.get_available_extra_jump_count() == 0, "creature consumed next")
	await _sync(1)
	_check(object.get_node("Count").text == "0", "label 1 to 0")
	player.velocity = Vector2.ZERO
	_check(player.release_grab(), "drop used creature")
	await _sync(1)
	_check(not object.get_node("Count").visible, "free label hidden")
	_hold(object)
	_check(player.get_available_extra_jump_count() == 0, "regrab does not refill")
	player.refill_from_crystal()
	_check(object.extra_jump_count() == 0, "crystal cannot refill creature")
	player._refill_on_landing()
	_check(player.get_available_extra_jump_count() == 1 and not player.is_air_jump_ready(), "landing refills creature clears crystal")
	player._jump_buffer_left = 0.1
	player._try_jump(true, false)
	_check(object.extra_jump_count() == 1, "ground jump preserves creature")
	player._jump_buffer_left = 0.1
	player._try_jump(false, true)
	_check(object.extra_jump_count() == 1, "wall jump preserves creature")
	for scene in ["spring", "pinball_spring"]:
		object.consume_extra_jump()
		var spring = load("res://scenes/" + scene + ".tscn").instantiate()
		spring.position = player.position + Vector2(0, 30)
		world.add_child(spring)
		player.velocity = Vector2(0, 500)
		player._motion_frame = -2
		player._impact_frame = -2
		spring._on_body_entered(player)
		_check(player.get_available_extra_jump_count() == 2, scene + " restores both")
		spring.free()
	player.velocity = Vector2.ZERO
	player.release_grab()
	player._air_jump_ready = false
	player._jump_buffer_left = 0.1
	player._try_jump(false, false)
	_vector(player.velocity, Vector2.ZERO, "free creature cannot jump")


func _heavy_tests() -> void:
	await _reset()
	var object := _object("heavy_object")
	await _sync()
	_hold(object)
	_near(object.weight, 2, "heavy weight")
	_near(player.get_effective_move_speed(), 270, "heavy move")
	_near(player.get_effective_acceleration(true), 1950, "heavy ground acceleration")
	_near(player.get_effective_acceleration(false), 1275, "heavy air acceleration")
	_near(player.get_effective_jump_speed(), 552.5, "heavy jump")
	_near(player.move_speed, 360, "export unchanged")
	_near(player.jump_speed, 650, "jump export unchanged")
	_near(player.wall_climb_speed, 230, "climb unchanged")
	_near(player.wall_stamina_rest_rate, 1.0 / 3.0, "stamina unchanged")
	player._jump_buffer_left = 0.1
	player._try_jump(false, true)
	_near(player.velocity.y, -650, "wall jump unchanged")
	player._start_dash(true)
	_near(player.velocity.length(), 900, "dash speed unchanged")
	_near(player._dash_left, 0.15, "dash duration unchanged")
	player._jump_buffer_left = 0.1
	player._tick_dash(1.0 / 60.0, true)
	_near(player.velocity.x, 600, "superdash horizontal momentum")
	_near(player.velocity.y, -650, "superdash jump unchanged")
	_check(player.get_held_object() == object, "dash and superdash retain heavy")
	player.velocity = Vector2.ZERO
	player.release_grab()
	_near(player.get_effective_move_speed(), 360, "drop restores move")
	_near(player.get_effective_acceleration(true), 2600, "drop restores ground acceleration")
	_near(player.get_effective_acceleration(false), 1700, "drop restores air acceleration")
	_near(player.get_effective_jump_speed(), 650, "drop restores jump")


func _parachute_tests() -> void:
	for gravity in [1, -1]:
		await _reset()
		var object := _object("parachute_creature")
		await _sync()
		_hold(object)
		player.set_gravity_direction(gravity)
		player.velocity = Vector2(123, 800 * gravity)
		player._apply_parachute()
		_vector(player.velocity, Vector2(123, 180 * gravity), "relative fall cap and horizontal preservation")
		player.velocity = Vector2(123, -800 * gravity)
		player._apply_parachute()
		_vector(player.velocity, Vector2(123, -800 * gravity), "rising unchanged")
		player._start_dash(false)
		player.velocity = Vector2(0, 900 * gravity)
		player._apply_parachute()
		_near(player.velocity.y, 900 * gravity, "dash ignores parachute")
		player._dash_left = 0
		player._apply_parachute()
		_near(player.velocity.y, 180 * gravity, "dash end resumes parachute")
		for scene in ["spring", "pinball_spring"]:
			var spring = load("res://scenes/" + scene + ".tscn").instantiate()
			spring.position = player.position - Vector2(0, 30 * gravity)
			spring.rotation = PI if gravity > 0 else 0.0
			world.add_child(spring)
			player.velocity = Vector2(0, -500 * gravity)
			player._motion_frame = -2
			spring._on_body_entered(player)
			var launched := player.velocity
			_check(launched.y * gravity >= 800, scene + " downward launch fixture")
			player._apply_parachute()
			_vector(player.velocity, launched, scene + " immediate grace")
			_near(player._parachute_grace_left, 0.15, scene + " grace default")
			spring.free()
			await _step(11)
			_check(player.velocity.y * gravity <= 180.1, scene + " grace expires")
		for wind in [Vector2(900, 0), Vector2(0, -3000 * gravity), Vector2(0, 3000 * gravity)]:
			player.register_wind(world, wind, 1000)
			player.velocity = Vector2(0, 170 * gravity)
			await _step()
			_check(player.velocity.y * gravity <= 180.1, "wind final fall cap")
			if wind.x > 0:
				_check(player.velocity.x > 0, "horizontal wind")
			if wind.y * gravity < 0:
				await _step(15)
				_check(player.velocity.y * gravity < 0, "upwind can ascend")
		player.unregister_wind(world)
		player.velocity = Vector2.ZERO
		player.release_grab()
		player.velocity = Vector2(0, 800 * gravity)
		player._apply_parachute()
		_near(player.velocity.y, 800 * gravity, "drop immediately removes cap")


func _button(at: Vector2) -> Area2D:
	var button = load("res://scenes/pressure_button.tscn").instantiate()
	button.position = at
	world.add_child(button)
	return button


func _button_tests() -> void:
	await _reset(Vector2(400, 674))
	var button := _button(Vector2(440, 700))
	_near(button.required_weight, 2, "required weight default")
	_check(not button.include_player, "player excluded default")
	var changes: Array[bool] = []
	button.pressed_changed.connect(func(value: bool): changes.append(value))
	var heavy := _object("heavy_object", Vector2(40, 10))
	await _sync(5)
	_check(button.is_pressed(), "heavy on")
	button.refresh_weight()
	button.refresh_weight()
	_near(button.total_weight, 2, "no double count")
	heavy.position.x += 200
	await _sync(5)
	_check(not button.is_pressed() and changes == [true, false], "exit off and signal edges")
	button.position.x = 400
	await _sync(5)
	_near(button.total_weight, 0, "player ignored")
	button.include_player = true
	button.required_weight = 1
	await _sync(2)
	_check(button.is_pressed(), "include player")
	await _reset()
	button = _button(Vector2(500, 700))
	for i in 4:
		var light := _object("jump_creature")
		light.position = Vector2(460 + 26 * i, 688)
	await _sync(5)
	_near(button.total_weight, 2, "four light objects sum")
	_check(button.is_pressed(), "light objects on")
	await _reset(Vector2(400, 674))
	button = _button(Vector2(570, 700))
	heavy = _object("heavy_object")
	await _sync()
	_hold(heavy)
	player.velocity = Vector2(80, 0)
	_check(player.release_grab(), "heavy throw for button")
	for i in 120:
		await _sync(1)
		if button.is_pressed():
			break
	_check(button.is_pressed() and heavy.position.y > 675, "real thrown heavy lands on button")


func _respawn_tests() -> void:
	for name in ["heavy_object", "jump_creature", "parachute_creature"]:
		await _reset()
		var object := _object(name)
		var initial := object.global_transform
		await _sync()
		_hold(object)
		object.consume_extra_jump()
		player.launch_from_spring(Vector2(300, -500))
		player.respawn()
		_check(player.get_held_object() == null and object.carrier == null, "respawn clears carry")
		_check(not object.freeze and object.get_collision_exceptions().is_empty(), "respawn restores collision physics")
		_check(object.global_transform.is_equal_approx(initial), "respawn object transform")
		_vector(object.linear_velocity, Vector2.ZERO, "respawn linear velocity")
		_near(object.angular_velocity, 0, "respawn angular velocity")
		_near(player.get_effective_move_speed(), 360, "respawn no heavy modifier")
		_near(player._parachute_grace_left, 0, "respawn timer reset")
		_check(player.get_available_extra_jump_count() == 0, "respawn no creature ability")
		if name == "jump_creature":
			_check(object.extra_jump_count() == 1, "respawn creature resource reset")
	await _reset()
	var heavy := _object("heavy_object")
	var button := _button(Vector2(600, 700))
	heavy.position = Vector2(600, 684)
	await _sync(5)
	_check(button.is_pressed(), "respawn button fixture on")
	player.respawn()
	await _sync(5)
	_check(not button.is_pressed(), "respawn button returns off after physics sync")


func _environment_tests() -> void:
	for moving in [false, true]:
		await _reset()
		var object := _object()
		await _sync()
		_hold(object)
		var gate = load("res://scenes/gravity_gate.tscn").instantiate()
		gate.position = Vector2(460, 350)
		gate.moving_enabled = moving
		gate.move_offset = Vector2(-80, 0)
		world.add_child(gate)
		Input.action_press("move_right")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		await _step(4)
		_check(player.gravity_direction == -1 and player.get_held_object() == object, "actual static/moving gate retains carry")
	for gravity in [1, -1]:
		await _reset()
		var object := _object()
		await _sync()
		_hold(object)
		object.consume_extra_jump()
		player.refill_from_crystal()
		player.set_gravity_direction(gravity)
		for i in 80:
			await _step()
			if player.is_on_floor():
				break
		_check(player.is_on_floor() and player.get_available_extra_jump_count() == 1 and not player.is_air_jump_ready(), "actual gravity-relative landing refills only creature")


func _assert_shapes_clear(object: Grabbable) -> void:
	# Independent of the production space query and collision masks/exceptions.
	var held_shape: CollisionShape2D = object.get_node("CollisionShape2D")
	for body in world.find_children("*", "PhysicsBody2D", true, false):
		if body == object:
			continue
		for shape_node in body.get_children():
			if shape_node is CollisionShape2D and not shape_node.disabled:
				_check(not held_shape.shape.collide(held_shape.global_transform, shape_node.shape, shape_node.global_transform), "every frame shape separation from " + body.name)
