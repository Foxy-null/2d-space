extends SceneTree

const STEP := 1.0 / 60.0
var failed := false
var checks := 0
var world: Node2D
var player: PlayerController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_solid(Vector2(1000, 720), Vector2(4000, 40))
	_solid(Vector2(820, 350), Vector2(40, 300))
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await _sync()
	await _test_gates()
	await _test_springs()
	await _test_pinball()
	await _test_floor_springs()
	await _test_wind_vectors()
	await _test_wind_movement()
	await _test_wind_lifecycle()
	print("PHASE2_ENVIRONMENT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _solid(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.position = pos
	body.add_child(collider)
	world.add_child(body)


func _sync(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _step(count: int = 1) -> void:
	for i in count:
		player.set_physics_process(true)
		await _sync(1)
		player.set_physics_process(false)


func _reset(pos: Vector2 = Vector2(400, 350)) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab"]:
		Input.action_release(action)
	player.respawn()
	player.position = pos
	await _sync()


func _incident(value: Vector2) -> void:
	player.velocity = value
	player._motion_frame = -2


func _drain() -> void:
	player._dash_ready = false
	player._air_jump_ready = false
	player._wall_stamina = 0.0
	player._grab_exhausted = true
	player._notify_resources()


func _resources(label: String) -> void:
	_check(player.is_dash_ready(), label + " dash ready")
	_check(player.is_air_jump_ready(), label + " air jump ready")
	_near(player.get_wall_stamina(), player.wall_stamina_max, label + " stamina max")
	_check(not player._grab_exhausted, label + " grab available")
	_check(player.get_node("Visuals/Body").color == Color(0.35, 0.92, 1, 1), label + " body ready color")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("PHASE2: " + label)


func _near(value: float, expected: float, label: String) -> void:
	_check(absf(value - expected) < 0.1, "%s: %.3f expected %.3f" % [label, value, expected])


func _vector(value: Vector2, expected: Vector2, label: String) -> void:
	_check(value.distance_to(expected) < 0.1, "%s: %s expected %s" % [label, value, expected])


func _test_gates() -> void:
	await _reset()
	var gate = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(100, 350)
	world.add_child(gate)
	gate.set_physics_process(false)
	gate._physics_process(2.0)
	_vector(gate.position, Vector2(100, 350), "default gate stationary")
	gate.body_entered.emit(player)
	_check(player.gravity_direction == -1, "static up gate")
	_check(gate.get_node("Glow").color.r > gate.get_node("Glow").color.b, "up red")
	gate.target_gravity = 1
	gate.body_entered.emit(player)
	_check(player.gravity_direction == 1, "static down gate")
	_check(gate.get_node("Glow").color.b > gate.get_node("Glow").color.r, "down cyan")
	_near(gate.move_speed, 120, "gate default speed")
	_near(gate.endpoint_wait_time, 0.5, "gate default wait")
	_vector(gate.move_offset, Vector2(300, 0), "gate default offset")
	gate.move_offset = Vector2(90, -120)
	gate.move_speed = 150
	gate.moving_enabled = true
	for cycle in 2:
		gate._physics_process(0.5)
		_vector(gate.position, Vector2(145, 290), "arbitrary offset outbound")
		gate._physics_process(0.5)
		_vector(gate.position, Vector2(190, 230), "reaches B")
		gate._physics_process(0.25)
		_vector(gate.position, Vector2(190, 230), "wait B")
		gate.moving_enabled = false
		gate._physics_process(3.0)
		_vector(gate.position, Vector2(190, 230), "pause wait")
		gate.moving_enabled = true
		gate._physics_process(0.25)
		gate._physics_process(0.5)
		_vector(gate.position, Vector2(145, 290), "return from B")
		gate._physics_process(0.5)
		_vector(gate.position, Vector2(100, 350), "reaches A")
		gate._physics_process(0.5)
		_vector(gate.position, Vector2(100, 350), "wait A")
	gate.free()
	# A moving Area must trigger against a motionless CharacterBody.
	gate = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(280, 350)
	gate.move_offset = Vector2(120, 0)
	gate.moving_enabled = true
	world.add_child(gate)
	await _sync(65)
	_check(player.gravity_direction == -1, "moving gate enters stationary player")
	gate.moving_enabled = false
	player.set_gravity_direction(1)
	await _sync(5)
	_check(player.gravity_direction == 1, "gate does not retrigger while overlapping")
	gate.position = Vector2(200, 350)
	await _sync()
	gate.position = player.position
	await _sync()
	_check(player.gravity_direction == -1, "gate reentry triggers again")
	gate.free()
	await _reset()
	gate = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(485, 350)
	gate.moving_enabled = true
	gate.move_offset = Vector2(-300, 0)
	world.add_child(gate)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	await _step(3)
	_check(player.gravity_direction == -1 and player.is_dashing(), "moving gate preserves dash")
	_vector(player.velocity, Vector2(900, 0), "moving gate preserves dash velocity")
	gate.free()


func _test_springs() -> void:
	for angle in [0.0, PI, PI / 2, -PI / 2]:
		await _reset()
		var spring = load("res://scenes/spring.tscn").instantiate()
		spring.position = Vector2(400, 400)
		spring.rotation = angle
		world.add_child(spring)
		var normal := Vector2.UP.rotated(angle)
		var tangent := normal.orthogonal()
		player.position = spring.position + normal * 30
		_drain()
		_incident(tangent * 213 - normal * 12)
		await _sync()
		_vector(player.velocity, tangent * 213 + normal * 900, "actual rotated spring " + str(angle))
		_resources("spring " + str(angle))
		_near(spring.spring_speed, 900, "spring default")
		_incident(Vector2.ZERO)
		_drain()
		spring.body_entered.emit(player)
		await _sync()
		_vector(player.velocity, Vector2.ZERO, "no repeated launch in contact")
		_check(not player.is_dash_ready(), "no repeated refill in contact")
		player.position = spring.position + normal * 120
		await _sync()
		player.position = spring.position + normal * 30
		_incident(-normal)
		await _sync()
		_vector(player.velocity, normal * 900, "low speed reentry")
		player.position = spring.position - normal * 120
		await _sync()
		player.position = spring.position - normal * 4
		_incident(-normal * 100)
		_drain()
		await _sync()
		_check(not player.is_dash_ready(), "back side ignored")
		spring.free()
	await _reset()
	var spring = load("res://scenes/spring.tscn").instantiate()
	spring.position = Vector2(475, 350)
	spring.rotation = -PI / 2
	world.add_child(spring)
	var launch: Array[Vector2] = []
	spring.body_entered.connect(func(body):
		if body == player:
			launch.append(player.velocity)
	)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for i in 6:
		await _step()
		if not player.is_dashing():
			break
	_check(not player.is_dashing(), "actual spring stops dash")
	_check(launch.size() == 1, "one actual spring launch")
	if not launch.is_empty():
		_vector(launch[0], Vector2(-900, 0), "spring velocity wins over dash at contact")
	_resources("dash spring")
	_check(player._superdash_left == 0 and player._dash_direction == Vector2.ZERO, "spring clears transient dash state")
	spring.free()


func _test_pinball() -> void:
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		var normal := Vector2.UP.rotated(angle)
		var tangent := normal.orthogonal()
		for incident in [Vector2(0, 200), Vector2(-400, 800), Vector2(400, 800), Vector2(900, 1500)]:
			await _reset()
			var spring = load("res://scenes/pinball_spring.tscn").instantiate()
			spring.position = Vector2(400, 400)
			spring.rotation = angle
			world.add_child(spring)
			player.position = spring.position + normal * 30
			var incoming: Vector2 = tangent * incident.x - normal * incident.y
			_incident(incoming)
			_drain()
			await _sync()
			var expected := incoming.bounce(normal).normalized() * clampf(incoming.length(), 800, 1200)
			_vector(player.velocity, expected, "pinball reflection angle and speed")
			_check(player.velocity.dot(normal) > 0, "pinball always outward")
			_resources("pinball")
			await _sync(5)
			_vector(player.velocity, expected, "pinball no repeated reflection")
			spring.free()
	await _reset()
	var spring = load("res://scenes/pinball_spring.tscn").instantiate()
	spring.position = Vector2(400, 400)
	world.add_child(spring)
	_near(spring.minimum_bounce_speed, 800, "pinball minimum default")
	_near(spring.maximum_bounce_speed, 1200, "pinball maximum default")
	_near(spring.min_impact_normal_speed, 50, "pinball threshold default")
	player.position = Vector2(400, 370)
	_incident(Vector2(900, 49))
	_drain()
	await _sync()
	_vector(player.velocity, Vector2(900, 49), "shallow scrape ignored")
	_check(not player.is_dash_ready(), "shallow scrape does not refill")
	player.position.y = 250
	await _sync()
	player.position.y = 370
	_incident(Vector2(0, 50))
	await _sync()
	_vector(player.velocity, Vector2(0, -800), "threshold and reentry")
	# Actual diagonal dash contact, reflected before cancelling dash.
	spring.free()
	await _reset()
	spring = load("res://scenes/pinball_spring.tscn").instantiate()
	spring.position = Vector2(450, 430)
	world.add_child(spring)
	var launch: Array[Vector2] = []
	spring.body_entered.connect(func(body):
		if body == player:
			launch.append(player.velocity)
	)
	Input.action_press("move_right")
	Input.action_press("move_down")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for i in 7:
		await _step()
		if not player.is_dashing():
			break
	_check(not player.is_dashing(), "pinball ends dash")
	_check(launch.size() == 1, "one actual pinball launch")
	if not launch.is_empty():
		_vector(launch[0], Vector2(1, -1).normalized() * 900, "pinball uses incident diagonal dash")
	_resources("pinball dash")
	await _step(5)
	_check(launch.size() == 1, "pinball trajectory does not loop into surface")
	spring.free()


func _test_floor_springs() -> void:
	for scene in ["spring", "pinball_spring"]:
		await _reset(Vector2(400, 610))
		var spring = load("res://scenes/" + scene + ".tscn").instantiate()
		# Detection flush can occur after the same movement hits the floor.
		spring.position = Vector2(400, 715)
		world.add_child(spring)
		var floor_contact: Array[bool] = []
		spring.body_entered.connect(func(body):
			if body == player:
				floor_contact.append(player.is_on_floor())
		)
		_drain()
		_incident(Vector2(0, 900))
		for i in 12:
			await _step()
			if player.is_air_jump_ready():
				break
		_resources("floor " + scene)
		_check(floor_contact == [true], "actual floor collision precedes " + scene + " signal")
		_check(player.velocity.y < -700, "floor launch retains incident velocity")
		# Both legal orderings in one frame: refill after landing and before landing.
		player._refill_on_landing()
		_resources("same-frame landing after " + scene)
		await _step()
		_check(player.is_air_jump_ready() and not player.is_on_floor(), "cached landing cannot erase spring air jump")
		spring.free()
		player.position = Vector2(400, 670)
		_incident(Vector2(0, 400))
		await _step(3)
		_check(player.is_on_floor() and not player.is_air_jump_ready(), "later landing still clears air jump")
	# Recovery is usable immediately at a wall, not just displayed as ready.
	await _reset(Vector2(780, 350))
	_drain()
	player.launch_from_spring(Vector2(40, 0))
	Input.action_press("move_right")
	Input.action_press("wall_grab")
	await _step(4)
	_check(player.is_wall_grabbing(), "spring recovery unlocks immediate wall grab")
	player._wall_stamina = 0
	player._grab_exhausted = true
	player.refill_from_crystal()
	_check(player.get_wall_stamina() == 0 and player._grab_exhausted, "crystal does not inherit spring recovery")


func _test_wind_vectors() -> void:
	await _reset()
	var a := Node.new()
	var b := Node.new()
	world.add_child(a)
	world.add_child(b)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized()]:
		player.register_wind(a, direction * 900, 500)
		player.velocity = direction.orthogonal() * 700
		player._apply_wind(0.1)
		_vector(player.velocity, direction.orthogonal() * 700 + direction * 90, "wind direction")
		player._apply_wind(1)
		_near(player.velocity.dot(direction), 500, "wind projection cap")
		_near(player.velocity.dot(direction.orthogonal()), 700, "orthogonal speed untouched")
		player.velocity = direction * 900
		player._apply_wind(1)
		_vector(player.velocity, direction * 900, "wind does not truncate faster launch")
		player.set_gravity_direction(-1)
		player.velocity = Vector2.ZERO
		player._apply_wind(0.1)
		_vector(player.velocity, direction * 90, "wind independent of gravity")
	player.register_wind(a, Vector2(900, 0), 500)
	for other in [Vector2(900, 0), Vector2(-900, 0), Vector2(0, -900)]:
		player.register_wind(b, other, 500)
		player.velocity = Vector2.ZERO
		player._apply_wind(0.1)
		_vector(player.velocity, (Vector2(900, 0) + other) * 0.1, "wind sum / cancel / diagonal")
	player.unregister_wind(a)
	player.velocity = Vector2.ZERO
	player._apply_wind(0.1)
	_vector(player.velocity, Vector2(0, -90), "remove one contribution")
	player.unregister_wind(b)
	player.velocity = Vector2.ZERO
	player._apply_wind(1)
	_vector(player.velocity, Vector2.ZERO, "remove all wind")
	a.free()
	b.free()


func _test_wind_movement() -> void:
	var source := Node.new()
	world.add_child(source)
	await _reset(Vector2(400, 674))
	await _step(2)
	player.register_wind(source, Vector2(900, 0), 500)
	var start := player.position.x
	await _step(5)
	_check(player.position.x > start and player.is_on_floor(), "ground wind")
	Input.action_press("move_left")
	await _step(8)
	_check(player.velocity.x < 0, "input can oppose ground wind")
	await _reset()
	player.unregister_wind(source)
	player.register_wind(source, Vector2(900, 0), 500)
	await _step()
	_check(player.velocity.x > 0 and not player.is_on_floor(), "air wind")
	player.register_wind(source, Vector2(0, -900), 500)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	for i in 3:
		await _step()
		_vector(player.velocity, Vector2(900, 0), "dash ignores wind")
	while player.is_dashing():
		await _step()
	await _step()
	_near(player.velocity.y, (1900 - 900) * STEP, "wind resumes after dash")
	for gravity in [1, -1]:
		await _reset(Vector2(780, 350))
		player.unregister_wind(source)
		player.set_gravity_direction(gravity)
		Input.action_press("move_right")
		await _step(4)
		player.register_wind(source, Vector2(0, -gravity * 900), 500)
		player.velocity.y = gravity * 80
		await _step()
		_near(player.velocity.y * gravity, 80 + 1000 * STEP, "wall slide receives wind")
		Input.action_press("wall_grab")
		await _step(2)
		_check(player.is_wall_grabbing(), "wind grab fixture")
		_near(player.velocity.y, 0, "wall grab ignores wind")
		Input.action_release("wall_grab")
		await _step()
		_near(player.velocity.y * gravity, 1000 * STEP, "wind resumes immediately on grab release")
	player.unregister_wind(source)
	source.free()


func _test_wind_lifecycle() -> void:
	await _reset()
	var a = load("res://scenes/wind_area.tscn").instantiate()
	var b = load("res://scenes/wind_area.tscn").instantiate()
	a.position = player.position
	b.position = player.position
	b.wind_direction = Vector2(0, -7)
	world.add_child(a)
	world.add_child(b)
	await _sync()
	_near(a.wind_acceleration, 900, "wind acceleration default")
	_near(a.max_wind_speed, 500, "wind cap default")
	player.velocity = Vector2.ZERO
	player._apply_wind(0.1)
	_vector(player.velocity, Vector2(90, -90), "actual overlapping areas normalize and compose")
	a.wind_direction = Vector2.LEFT
	player.velocity = Vector2.ZERO
	player._apply_wind(0.1)
	_vector(player.velocity, Vector2(-90, -90), "Inspector direction change updates registered wind")
	a.wind_direction = Vector2.RIGHT
	a.area_size = Vector2(180, 160)
	await _sync()
	_vector(a.get_node("CollisionShape2D").shape.size, Vector2(180, 160), "Inspector size updates collider")
	a.position.x += 500
	await _sync()
	player.velocity = Vector2.ZERO
	player._apply_wind(0.1)
	_vector(player.velocity, Vector2(0, -90), "actual area exit removes only one")
	b.position.x += 500
	await _sync()
	_check(player._winds.is_empty(), "all actual areas exited")
	b.position = player.position
	await _sync()
	_check(player._winds.size() == 1, "wind reentry registers again")
	b.queue_free()
	await _sync()
	player.velocity = Vector2.ZERO
	player._apply_wind(0.1)
	_vector(player.velocity, Vector2.ZERO, "deleted area stops acceleration")
	_check(player._winds.is_empty(), "deleted area leaves no registration")
	a.free()
	# Weak-reference pruning also protects against sources without exit cleanup.
	var orphan := Node.new()
	world.add_child(orphan)
	player.register_wind(orphan, Vector2(900, 0), 500)
	orphan.free()
	player._apply_wind(0.1)
	_check(player._winds.is_empty(), "invalid source pruned safely")
	_vector(player.velocity, Vector2.ZERO, "invalid source cannot accelerate")
