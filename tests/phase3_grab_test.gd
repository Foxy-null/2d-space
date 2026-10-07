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
	await _wall_grab_tests()
	await _collision_tests()
	await _throw_tests()
	await _jump_tests()
	await _indicator_tests()
	await _heavy_tests()
	await _parachute_tests()
	await _updraft_tests()
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
			_assert_held(player.get_held_object())


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
	var far := _object("heavy_object", Vector2(70, -40))
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
	var outside := _object("jump_creature", Vector2(92, 0))
	await _sync()
	_check(not player.try_begin_grab(outside), "Nearest collider edge outside grab range")
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
	var blocked := _object("jump_creature", Vector2(-55, 0))
	await _sync()
	await _step()
	_check(player.get_held_object() == null and player.is_wall_grabbing(), "nearby object does not interrupt wall grab")
	Input.action_release("wall_grab")
	await _step()
	_check(player.get_held_object() == null and not player.is_wall_grabbing(), "released grab does not pick up object")
	Input.action_press("wall_grab")
	await _step()
	_check(player.get_held_object() == blocked and not player.is_wall_grabbing(), "repress grabs behind player while facing wall")


func _grab_wall(gravity: int) -> void:
	await _reset(Vector2(780, 350))
	player.set_gravity_direction(gravity)
	_solid(Vector2(820, 350), Vector2(40, 300))
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	await _step(5)
	Input.action_release("move_right")
	_check(player.is_wall_grabbing(), "wall grab fixture g=%d" % gravity)


func _wall_grab_tests() -> void:
	for gravity in [1, -1]:
		for mode in [-1, 0, 1]:
			await _grab_wall(gravity)
			var object := _object("jump_creature", Vector2(-55, 0))
			await _sync()
			if mode != 0:
				Input.action_press("move_up" if mode * gravity < 0 else "move_down")
			await _step(3)
			_check(player.is_wall_grabbing() and player.get_held_object() == null, "wall climb/rest/descent ignores object g=%d mode=%d" % [gravity, mode])
			_check(not player.try_begin_grab(object), "direct grab respects wall hold")
			# Both input edges can arrive before the next physics tick.
			Input.action_release("wall_grab")
			Input.action_press("wall_grab")
			await _step()
			_check(player.get_held_object() == object and not player.is_wall_grabbing(), "rapid repress overrides wall grab")

		for reason in ["exhaustion", "jump", "dash"]:
			await _grab_wall(gravity)
			# Keep the pickup beyond the kick's first step so the fixture tests
			# carrying momentum rather than colliding with an unheld object.
			var object := _object("jump_creature", Vector2(-70, 0))
			await _sync()
			if reason == "exhaustion":
				player._wall_stamina = 0.001
			else:
				Input.action_press(reason)
			await _step()
			_check(not player.is_wall_grabbing(), "wall releases on " + reason)
			if reason == "dash":
				_check(player.is_dashing() and player.get_held_object() == null, "wall dash does not grab object")
			else:
				_check(player.get_held_object() == object, "grab on wall release frame: " + reason)
				if reason == "jump":
					_check(player.velocity.x < 0 and player.velocity.y * gravity < 0, "pickup preserves wall jump")
				else:
					_check(player._grab_exhausted and player.get_wall_stamina() == 0, "pickup does not refill exhausted stamina")

		for mantle in [true, false]:
			await _grab_wall(gravity)
			var axis: int = -gravity if mantle else gravity
			var object := _object("jump_creature")
			# Keep the pickup within reach without blocking the mantle's swept shape.
			object.position = Vector2(820 if mantle else 715, 350 + axis * (252 if mantle else 198))
			await _sync()
			Input.action_press("move_up" if axis < 0 else "move_down")
			for i in 65:
				await _step()
				if not player.is_wall_grabbing():
					break
			if mantle:
				_check(player.position.x > 800, "mantle completes before pickup g=%d pos=%s" % [gravity, player.position])
			else:
				_check((player.position.y - 350) * gravity > 176, "descent leaves wall before pickup g=%d" % gravity)
			_check(not player.is_wall_grabbing() and player.get_held_object() == object, "automatic pickup after wall edge g=%d mantle=%s" % [gravity, mantle])


func _collision_tests() -> void:
	for gravity in [1, -1]:
		await _reset()
		player.set_gravity_direction(gravity)
		var object := _object("heavy_object")
		# Low headroom is allowed while carrying, for either gravity direction.
		_solid(player.position + Vector2(0, -48 * gravity), Vector2(300, 20))
		await _sync()
		_hold(object)
		_assert_held(object)
		_check(not object.is_position_clear(object.position, player), "held shape may overlap ceiling")
		var before := player.position
		Input.action_press("move_left")
		await _step(8)
		_check(player.position.x < before.x - 3, "turn and move under low ceiling")
		_near(object.position.x, player.position.x, "turn does not swap carry side")
		player.set_gravity_direction(-gravity)
		_assert_held(object)
		_near(object.rotation, 0, "held object remains upright")

	for gravity in [1, -1]:
		await _reset()
		player.set_gravity_direction(gravity)
		var object := _object("jump_creature", Vector2(32, 0))
		_solid(Vector2(452, 350), Vector2(10, 700))
		await _sync()
		_hold(object)
		Input.action_press("move_right")
		await _step(20)
		_check(player.is_on_wall_only(), "carrying reaches wall for wall kick")
		_check(not player.is_wall_grabbing(), "carrying still forbids wall grab")
		_check(player.velocity.y * gravity <= player.wall_slide_speed + 0.1, "carrying wall slide")
		Input.action_press("jump")
		await _step()
		_check(player.velocity.x < 0 and player.velocity.y * gravity < 0, "actual input wall kick with item")
		_check(player.get_held_object() == object, "wall kick retains item")

	await _reset()
	var object := _object("jump_creature", Vector2(58, 0))
	_solid(Vector2(443, 350), Vector2(2, 200))
	await _sync()
	_check(not player.try_begin_grab(object), "thin wall blocks pickup")

	for gravity in [1, -1]:
		await _reset()
		player.set_gravity_direction(gravity)
		object = _object()
		_solid(player.position + Vector2(0, -48 * gravity), Vector2(200, 20))
		await _sync()
		_hold(object)
		var held_position := object.position
		_check(player.release_grab(), "release corrects embedded item")
		_check(object.position.distance_to(player.position) < held_position.distance_to(player.position), "release corrects toward player")
		_check(object.is_position_clear(object.position, player), "release outside solid geometry")
		_check(_overlaps_player(object), "release allows temporary player overlap")
		Input.action_release("wall_grab")
		await _step(30)
		_check(not _overlaps_player(object), "physics resolves release overlap")

	await _reset(Vector2(400, 350))
	object = _object()
	_solid(Vector2(400, 302), Vector2(200, 20))
	_solid(Vector2(400, 386), Vector2(200, 20))
	await _sync()
	_hold(object)
	_check(player.release_grab(), "release in low tunnel")
	Input.action_release("wall_grab")
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	for frame in 90:
		await _step()
		for body in world.get_children():
			if body is StaticBody2D:
				var shape: CollisionShape2D = body.get_child(0)
				_check(not player_shape.shape.collide(player_shape.global_transform, shape.shape, shape.global_transform), "release cannot push player through terrain")
	_check(not _overlaps_player(object), "low tunnel overlap resolves without input")
	_check(player.position.x < 398 and object.position.x > 402, "overlap gently moves both bodies apart")
	_check(player.get_collision_exceptions().is_empty() and object.get_collision_exceptions().is_empty(), "separation restores mutual collisions")

	await _reset()
	object = _object()
	_solid(Vector2(400, 302), Vector2(200, 20))
	await _sync()
	_hold(object)
	_check(player.release_grab(), "release before deletion")
	object.free()
	Input.action_release("wall_grab")
	await _step(2)
	_check(player._separating_objects.is_empty(), "deleted overlap body is discarded")

	await _reset()
	object = _object("heavy_object")
	await _sync()
	_hold(object)
	# A large item cannot be released in a tunnel that still fits the player.
	object.collider.shape = object.collider.shape.duplicate()
	object.collider.shape.size = Vector2(80, 80)
	var obstruction := _solid(Vector2(400, 290), Vector2(300, 60))
	_solid(Vector2(400, 400), Vector2(300, 40))
	await _sync()
	_check(not player.release_grab() and player.get_held_object() == object, "no free release position retains carry")
	Input.action_release("wall_grab")
	Input.action_press("move_right")
	var before := player.position
	await _step(8)
	_check(player.get_held_object() == object, "blocked release retries")
	_check(player.position.x > before.x + 3, "pending release does not lock movement")
	obstruction.free()
	await _sync()
	await _step(5)
	_check(player.get_held_object() == null, "automatic release when space opens")

	await _reset(Vector2(400, 674))
	object = _object("heavy_object", Vector2(40, 10))
	object.freeze = false
	await _sync(40)
	var start := object.position
	Input.action_press("move_right")
	await _step(35)
	_check(object.position.x > start.x + 10 and player.position.x > 410, "walking pushes a free item")
	_check(object.linear_velocity.x <= 125, "push speed is gentle")


func _overlaps_player(object: Grabbable) -> bool:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	return object.collider.shape.collide(object.collider.global_transform, shape.shape, shape.global_transform)

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


func _indicator_tests() -> void:
	await _reset()
	var indicator := player.get_node("Visuals/ExtraJumpIndicator")
	_check(not indicator.visible, "no initial extra jumps")
	player.refill_from_crystal()
	await _sync()
	_check(not indicator.visible and indicator.jump_count == 0, "dash crystal cannot add jump indicator")
	player.grant_air_jump()
	await _sync()
	_check(indicator.visible and indicator.jump_count == 1, "crystal visible without creature")
	var object := _object()
	await _sync()
	_hold(object)
	await _sync()
	_check(indicator.jump_count == 2, "grab adds creature to body indicator")
	player.velocity = Vector2.ZERO
	_check(player.release_grab(), "release unused creature")
	await _sync()
	_check(indicator.jump_count == 1 and indicator.scale == Vector2.ONE, "release removes creature and cancels pulse")
	player._start_dash(false)
	await _sync()
	_check(indicator.visible and indicator.jump_count == 1, "dash keeps jump indicator")
	player.set_gravity_direction(-1)
	await create_timer(0.25).timeout
	_check(absf(absf(indicator.global_rotation) - PI) < 0.01, "indicator follows inverted gravity")
	_check(indicator.scale.is_equal_approx(Vector2.ONE), "pulse settles to static size")
	player.respawn()
	await _sync()
	_check(not indicator.visible and indicator.jump_count == 0, "respawn clears indicator")


func _jump_tests() -> void:
	await _reset()
	var object := _object()
	await _sync()
	_hold(object)
	_check(player.get_available_extra_jump_count() == 1, "creature only one")
	player.grant_air_jump()
	_check(player.get_available_extra_jump_count() == 2, "crystal plus creature two")
	await _sync(1)
	var indicator := player.get_node("Visuals/ExtraJumpIndicator")
	_check(indicator.jump_count == 2 and indicator.visible, "body indicator 2")
	player._jump_buffer_left = 0.1
	player._try_jump(false, false)
	_check(not player.is_air_jump_ready() and object.extra_jump_count() == 1, "crystal consumed first")
	await _sync(1)
	_check(indicator.jump_count == 1 and indicator.visible, "body indicator 2 to 1")
	player._jump_buffer_left = 0.1
	player._try_jump(false, false)
	_check(player.get_available_extra_jump_count() == 0, "creature consumed next")
	await _sync(1)
	_check(indicator.jump_count == 0 and not indicator.visible, "body indicator hidden at zero")
	player.velocity = Vector2.ZERO
	_check(player.release_grab(), "drop used creature")
	await _sync(1)
	_check(not object.has_node("Count"), "creature has no duplicate counter")
	_hold(object)
	_check(player.get_available_extra_jump_count() == 0, "regrab does not refill")
	player.refill_from_crystal()
	_check(player.get_available_extra_jump_count() == 0, "dash crystal cannot refill player or creature jumps")
	var crystal: Area2D = load("res://scenes/jump_crystal.tscn").instantiate()
	crystal.position = player.position
	world.add_child(crystal)
	await _sync()
	_check(player.is_air_jump_ready() and object.extra_jump_count() == 0, "jump crystal grants player jump without refilling creature")
	crystal.free()
	player._refill_on_landing()
	_check(player.get_available_extra_jump_count() == 2 and player.is_air_jump_ready(), "landing refills creature preserves crystal")
	player._jump_buffer_left = 0.1
	player._try_jump(true, false)
	_check(object.extra_jump_count() == 1, "ground jump preserves creature")
	player._jump_buffer_left = 0.1
	player._try_jump(false, true)
	_check(object.extra_jump_count() == 1, "wall jump preserves creature")
	for scene in ["spring", "pinball_spring"]:
		for ready in [false, true]:
			object.consume_extra_jump()
			player._air_jump_ready = ready
			var spring = load("res://scenes/" + scene + ".tscn").instantiate()
			spring.position = player.position + Vector2(0, 30)
			world.add_child(spring)
			player.velocity = Vector2(0, 500)
			player._motion_frame = -2
			player._impact_frame = -2
			spring._on_body_entered(player)
			_check(player.get_available_extra_jump_count() == int(ready) and object.extra_jump_count() == 0, scene + " preserves player jump and cannot refill creature")
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
	_near(object.weight, 8, "heavy weight")
	_near(object.mass, 8, "heavy physical mass")
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
	_near(player.velocity.y, -player.wall_jump_up_speed, "heavy does not reduce wall jump")
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


func _updraft_tests() -> void:
	for gravity in [1, -1]:
		for name in ["", "heavy_object", "jump_creature"]:
			await _reset()
			player.set_gravity_direction(gravity)
			if not name.is_empty():
				var carried := _object(name)
				await _sync()
				_hold(carried)
			player.register_wind(world, Vector2(0, -3000 * gravity), 1000)
			player.velocity = Vector2(0, 900 * gravity)
			await _step(3)
			_near(player.velocity.y * gravity, 450, "updraft halves terminal fall speed without parachute: " + name)
			player.velocity = Vector2.ZERO
			await _step(5)
			_check(player.velocity.y * gravity > 0, "strong updraft cannot lift without parachute: " + name)
			player.velocity = Vector2(0, -650 * gravity)
			await _step(2)
			_near(player.velocity.y * gravity, -650 + 1900 * 2.0 / 60.0, "jump momentum decays naturally without parachute")
			player.register_wind(world, Vector2(900, -3000 * gravity), 1000)
			player.velocity = Vector2(0, 900 * gravity)
			_near(player._apply_wind(0.1), 324, "diagonal crosswind preserved without parachute")
			_vector(player.velocity, Vector2(0, 450 * gravity), "updraft fall cap with crosswind")
			player.unregister_wind(world)
			player.velocity = Vector2(0, 900 * gravity)
			await _step()
			_near(player.velocity.y * gravity, 900, "leaving updraft restores normal fall cap")
		await _reset()
		player.set_gravity_direction(gravity)
		var object := _object("parachute_creature")
		await _sync()
		_hold(object)
		var updraft = load("res://scenes/wind_area.tscn").instantiate()
		updraft.position = player.position
		updraft.area_size = Vector2(200, 600)
		updraft.wind_direction = Vector2(0, -gravity)
		updraft.wind_acceleration = 3000
		world.add_child(updraft)
		await _sync()
		await _step(30)
		_near(player.velocity.y * gravity, -180, "parachute floats at slow rise cap in actual area")
		player.velocity = Vector2(123, -800 * gravity)
		player._apply_wind(0.1)
		_vector(player.velocity, Vector2(123, -800 * gravity), "updraft rise cap preserves faster launch")
		updraft.wind_direction = Vector2(900, -3000 * gravity)
		updraft.wind_acceleration = Vector2(900, -3000).length()
		player.velocity = Vector2(0, -180 * gravity)
		_near(player._apply_wind(0.1), 324, "rise cap preserves diagonal crosswind")
		_vector(player.velocity, Vector2(0, -180 * gravity), "rise cap with crosswind")
		updraft.wind_direction = Vector2(0, -gravity)
		updraft.wind_acceleration = 3000
		player.register_wind(world, Vector2(0, 3000 * gravity), 500)
		player.velocity = Vector2(0, -180 * gravity)
		await _step()
		_near(player.velocity.y * gravity, -180 + 1900.0 / 60.0, "opposing areas cancel lift before classification")
		player.unregister_wind(world)
		player.velocity = Vector2(0, -180 * gravity)
		Input.action_release("wall_grab")
		_check(player.release_grab(), "release parachute in updraft")
		_near(player.velocity.y * gravity, -180, "release preserves ascent inertia")
		await _step(5)
		_near(player.velocity.y * gravity, -180 + 1900 * 5.0 / 60.0, "released ascent decays naturally inside updraft")
		updraft.position.x += 600
		await _sync()
		_check(player._winds.is_empty(), "actual updraft exit unregisters")
		player.velocity = Vector2(0, 900 * gravity)
		await _step()
		_near(player.velocity.y * gravity, 900, "actual exit restores normal falling")


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
	_near(button.total_weight, 8, "no double count")
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
	await _sync(5)
	var bottom := heavy.position.y + (heavy.collider.shape as RectangleShape2D).size.y * 0.5
	_check(button.is_pressed() and bottom > 690, "real thrown heavy lands on button")
	await _reset(Vector2(400, 674))
	button = _button(Vector2(440, 700))
	heavy = _object("heavy_object", Vector2(40, 10))
	await _sync(5)
	_check(button.is_pressed(), "pickup from pressed button fixture")
	_hold(heavy)
	button.refresh_weight()
	_check(not button.is_pressed() and button.total_weight == 0, "pickup stops weight immediately despite cached overlaps")
	button.position = heavy.position + Vector2(0, 16)
	await _sync(5)
	_check(not button.is_pressed(), "held item overlapping button has no weight")
	_check(player.release_grab(), "release over button")
	await _sync(3)
	_check(button.is_pressed(), "released item counts again")


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
		_check(object.collision_layer == 1 and object.collision_mask == 1, "respawn restores collision layer and mask")
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
	await _reset()
	var object := _object()
	_solid(Vector2(400, 302), Vector2(200, 20))
	await _sync()
	_hold(object)
	_check(player.release_grab(), "overlap release before respawn")
	_check(not object.get_collision_exceptions().is_empty(), "overlap uses temporary separation exception")
	player.respawn()
	_check(object.get_collision_exceptions().is_empty() and player.get_collision_exceptions().is_empty(), "respawn clears separation exceptions")


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
		player.grant_air_jump()
		player.set_gravity_direction(gravity)
		for i in 80:
			await _step()
			if player.is_on_floor():
				break
		_check(player.is_on_floor() and player.get_available_extra_jump_count() == 2 and player.is_air_jump_ready(), "actual gravity-relative landing refills creature preserves crystal")


func _assert_held(object: Grabbable) -> void:
	_check(object.freeze and object.collision_layer == 0 and object.collision_mask == 0, "held body has no physical collisions")
	var half_height := (object.collider.shape as RectangleShape2D).size.y * 0.5
	var x := player.carry_offset.x + (player.facing_direction * 14.0 if is_finite(object.fall_speed_limit()) else 0.0)
	var y := (player.carry_offset.y + 20.0 - half_height) * player.gravity_direction
	_vector(object.position - player.position, Vector2(x, y), "Full-size held body meets raised palms")
