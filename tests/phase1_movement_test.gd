extends SceneTree

const STEP := 1.0 / 60.0
var failed := false
var player: PlayerController
var world: Node2D
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	# Symmetric arena: floor y=700, ceiling y=0, wall x=800..840, y=200..500.
	_solid(Vector2(1000, 720), Vector2(4000, 40))
	_solid(Vector2(1000, -20), Vector2(4000, 40))
	_solid(Vector2(820, 350), Vector2(40, 300))
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	_test_input()
	await _test_dash()
	await _test_walls()
	await _test_jumps()
	await _test_crystal()
	await _test_edge_cases()
	_test_respawn()
	print("PHASE1_MOVEMENT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
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


func _step(count: int = 1) -> void:
	for i in count:
		player.set_physics_process(true)
		await physics_frame
		await process_frame
		player.set_physics_process(false)


func _reset(pos: Vector2 = Vector2(400, 350), gravity: int = 1) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab"]:
		Input.action_release(action)
	player.respawn()
	player.global_position = pos
	player.set_gravity_direction(gravity)
	await _step()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("PHASE1: " + message)


func _near(value: float, expected: float, message: String, tolerance: float = 0.1) -> void:
	_check(absf(value - expected) <= tolerance, "%s: got %.3f expected %.3f" % [message, value, expected])


func _test_input() -> void:
	_check(InputMap.has_action("dash"), "dash action")
	var key := false
	var pad := false
	for event in InputMap.action_get_events("dash"):
		if event is InputEventKey:
			key = key or event.physical_keycode == KEY_X
		if event is InputEventJoypadButton:
			pad = pad or event.button_index == JOY_BUTTON_B
	_check(key and pad, "X and B mapping")


func _test_dash() -> void:
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		await _reset()
		if direction.x != 0:
			Input.action_press("move_right" if direction.x > 0 else "move_left")
		if direction.y != 0:
			Input.action_press("move_down" if direction.y > 0 else "move_up")
		player.velocity = Vector2(-123, 345)
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		_check(player.is_dashing(), "dash starts %s" % direction)
		_check(player.velocity.distance_to(direction.normalized() * player.dash_speed) < 0.1, "8-way direction / old velocity discarded %s" % direction)
		_near(player.velocity.length(), player.dash_speed, "normalized dash speed")
		var speed := player.velocity
		await _step(2)
		_check(player.velocity.is_equal_approx(speed), "no gravity during dash")
		_check(not player.is_dash_ready(), "air dash consumed")
		_check(player.get_node("Visuals/Body").color == Color(1, 0.5, 0.15, 1), "used body orange")
		while player.is_dashing():
			await _step()
		_near(player.velocity.length(), player.dash_speed * player.dash_end_speed_ratio, "end momentum")
		Input.action_press("dash")
		await _step()
		_check(not player.is_dashing(), "cannot dash twice")
	await _reset()
	Input.action_press("move_left")
	await _step()
	Input.action_release("move_left")
	player.set_gravity_direction(-1)
	_check(player.facing_direction == -1, "gravity preserves left facing")
	Input.action_press("dash")
	await _step()
	_check(player.velocity.x == -player.dash_speed, "neutral dash uses left facing")
	await _reset()
	Input.action_press("move_right")
	await _step()
	Input.action_release("move_right")
	Input.action_press("dash")
	await _step()
	_check(player.velocity.x == player.dash_speed, "neutral right facing")
	await _reset(Vector2(740, 350))
	Input.action_press("move_right")
	Input.action_press("dash")
	Input.action_press("wall_grab")
	await _step()
	Input.action_release("dash")
	while player.is_dashing():
		await _step()
	_check(player.global_position.x <= 782.1, "dash wall collision")
	await _step()
	_check(player.is_wall_grabbing(), "grab immediately after dash collision")
	await _reset()
	var gate: Area2D = load("res://scenes/gravity_gate.tscn").instantiate()
	gate.position = Vector2(465, 350)
	world.add_child(gate)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	await _step(4)
	_check(player.gravity_direction == -1 and player.is_dashing(), "actual gate overlap keeps dash")
	_check(player.velocity == Vector2(player.dash_speed, 0), "gate preserves dash velocity")
	_check(gate.get_node("Glow").color.r > gate.get_node("Glow").color.b, "up gate red")
	gate.target_gravity = 1
	_check(gate.get_node("Glow").color.b > gate.get_node("Glow").color.r, "down gate cyan")
	_check(gate.get_node("Arrow").text == "↓", "gate arrow updates")
	_check(gate.get_node("Arrow").get_theme_color("font_color").b > gate.get_node("Arrow").get_theme_color("font_color").r, "arrow matches glow")
	gate.queue_free()
	for gravity in [1, -1]:
		await _reset(Vector2(400, 350), gravity)
		player._dash_ready = false
		player._air_jump_ready = true
		for i in 90:
			await _step()
			if player.is_on_floor():
				break
		_check(player.is_on_floor() and player.is_dash_ready(), "landing refills dash %d" % gravity)
		_check(not player.is_air_jump_ready(), "landing clears air jump")
		_check(player.get_node("Visuals/Body").color == Color(0.35, 0.92, 1, 1), "landing body cyan")


func _wall(gravity: int) -> void:
	await _reset(Vector2(780, 350), gravity)
	Input.action_press("move_right")
	await _step(3)
	Input.action_press("wall_grab")
	await _step()
	Input.action_release("move_right")
	_check(player.is_wall_grabbing(), "wall fixture grab %d" % gravity)


func _test_walls() -> void:
	for gravity in [1, -1]:
		for mode in [-1, 0, 1]:
			await _wall(gravity)
			if mode != 0:
				Input.action_press("move_down" if mode * gravity > 0 else "move_up")
			var before := player.get_wall_stamina()
			var start := player.position.y
			await _step(12)
			_near(before - player.get_wall_stamina(), 0.2 * (1.0 if mode < 0 else 1.0 / 3.0), "stamina rate g=%d mode=%d" % [gravity, mode], 0.005)
			if mode != 0:
				_check((player.position.y - start) * gravity * mode > 0, "gravity-relative climb/descent")
		await _wall(gravity)
		Input.action_press("move_up" if gravity > 0 else "move_down")
		var mantled := false
		for i in 65:
			await _step()
			if player.position.x > 800:
				mantled = true
				break
		_check(mantled, "REGRESSION mantle against gravity %d pos=%s" % [gravity, player.position])
		await _wall(gravity)
		player._wall_stamina = STEP / 6.0
		await _step()
		_check(not player.is_wall_grabbing() and player._grab_exhausted, "exhaustion releases grab")
		_check(player.velocity.y * gravity > 0, "exhausted falls with gravity")
		player.position.x = 730
		await _step(2)
		Input.action_press("move_right")
		await _step(18)
		_check(not player.is_wall_grabbing() and player.get_wall_stamina() == 0, "recontact cannot restore grab")
		player.position = Vector2(600, 350)
		Input.action_release("move_right")
		for i in 100:
			await _step()
			if player.is_on_floor():
				break
		_near(player.get_wall_stamina(), player.wall_stamina_max, "landing stamina reset")
		_check(not player._grab_exhausted, "landing unlocks grab")


func _test_jumps() -> void:
	for gravity in [1, -1]:
		for during in [true, false]:
			await _reset(Vector2(400, 674 if gravity > 0 else 26), gravity)
			await _step(2)
			Input.action_press("move_right")
			Input.action_press("dash")
			await _step()
			Input.action_release("dash")
			if not during:
				while player.is_dashing():
					await _step()
			Input.action_press("jump")
			await _step()
			_check(not player.is_dashing(), "superdash leaves dash state")
			_near(player.velocity.y, -gravity * player.jump_speed, "superdash jump speed")
			_near(player.velocity.x, player.dash_speed * player.dash_end_speed_ratio, "superdash momentum")
		await _reset(Vector2(400, 674 if gravity > 0 else 26), gravity)
		await _step(2)
		player.refill_from_crystal()
		Input.action_press("jump")
		await _step()
		_check(player.is_air_jump_ready(), "floor jump precedes air jump")
		await _wall(gravity)
		player.refill_from_crystal()
		Input.action_press("jump")
		await _step()
		_check(player.is_air_jump_ready() and absf(player.velocity.x) == player.wall_jump_speed, "wall jump precedes air jump")
		await _reset(Vector2(400, 350), gravity)
		player.refill_from_crystal()
		player.velocity.x = 600
		Input.action_press("jump")
		await _step()
		_near(player.velocity.y, -gravity * player.jump_speed, "air jump gravity direction")
		_near(player.velocity.x, 600 - player.air_acceleration * STEP, "air jump preserves horizontal momentum")
		_check(not player.is_air_jump_ready(), "air jump consumed")
	# Leave a real platform, then jump within coyote time.
	await _reset(Vector2(820, 174))
	await _step(2)
	Input.action_press("move_left")
	for i in 30:
		await _step()
		if not player.is_on_floor():
			break
	_check(player._coyote_left > 0, "coyote exists after leaving ledge")
	player.refill_from_crystal()
	Input.action_press("jump")
	await _step()
	_check(player.velocity.y < -600 and player.is_air_jump_ready(), "coyote jump priority")
	await _reset()
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	await _step(5)
	player.refill_from_crystal()
	Input.action_press("jump")
	await _step()
	Input.action_release("jump")
	while player.is_dashing():
		await _step()
	await _step()
	_check(not player.is_air_jump_ready() and player.velocity.y < -600, "dash jump buffer survives to air jump")


func _test_crystal() -> void:
	await _reset()
	var visor: Color = player.get_node("Visuals/Visor").color
	var crystal: Area2D = load("res://scenes/refill_crystal.tscn").instantiate()
	crystal.position = player.position
	world.add_child(crystal)
	player._dash_ready = false
	await _step(3)
	_check(player.is_dash_ready() and player.is_air_jump_ready(), "actual crystal overlap refills both")
	_check(not crystal.visible and crystal.get_node("CollisionShape2D").disabled and not crystal.monitoring, "crystal hidden and collision disabled")
	_check(player.get_node("Visuals/Body").color == Color(0.35, 0.92, 1, 1), "crystal restores cyan")
	_check(player.get_node("Visuals/Visor").color == visor, "visor unchanged")
	player._dash_ready = false
	crystal.body_entered.emit(player)
	_check(not player.is_dash_ready(), "duplicate pickup blocked")
	player.position.x = 550
	await _step(130)
	_check(not crystal.visible, "crystal waits respawn time")
	await _step(25)
	_check(crystal.visible and not crystal.get_node("CollisionShape2D").disabled and crystal.monitoring, "crystal respawns after 2.5 seconds")
	player.refill_from_crystal()
	player.refill_from_crystal()
	player._coyote_left = 0
	player._try_jump(false, false) # No buffer: cannot consume.
	player._jump_buffer_left = player.jump_buffer_time
	player._try_jump(false, false)
	_check(not player.is_air_jump_ready(), "multiple refills grant only one air jump")
	player._jump_buffer_left = player.jump_buffer_time
	player.velocity.y = 0
	player._try_jump(false, false)
	_check(player.velocity.y == 0, "no second air jump")
	crystal.queue_free()


func _test_respawn() -> void:
	player._dash_left = 0.1
	player._dash_ready = false
	player._air_jump_ready = true
	player._wall_stamina = 0
	player._grab_exhausted = true
	player._superdash_left = 0.1
	player._jump_buffer_left = 0.1
	player.set_gravity_direction(-1)
	player.respawn()
	_check(player.gravity_direction == 1 and player.up_direction == Vector2.UP, "respawn gravity")
	_check(player.is_dash_ready() and not player.is_air_jump_ready(), "respawn resources")
	_check(player.get_wall_stamina() == player.wall_stamina_max and not player._grab_exhausted, "respawn stamina")
	_check(not player.is_dashing() and player._superdash_left == 0 and player._jump_buffer_left == 0 and player._coyote_left == 0, "respawn transient states")
	_check(player.velocity == Vector2.ZERO and player.visuals.rotation == 0, "respawn velocity and rotation")
	_check(player.get_node("Visuals/Body").color == Color(0.35, 0.92, 1, 1), "respawn color")
	player.position.y = 1000
	player._physics_process(STEP)
	_check(player.position == player._spawn_position and player.velocity == Vector2.ZERO, "out-of-bounds respawn")


func _test_edge_cases() -> void:
	# Analog input must snap to the nearest octant, not merely normalize.
	await _reset()
	Input.action_press("move_right", 1.0)
	Input.action_press("move_down", 0.6)
	Input.action_press("dash")
	await _step()
	_check(player.velocity.distance_to(Vector2(1, 1).normalized() * player.dash_speed) < 0.1, "analog quantized to diagonal")
	var before := player.velocity
	player.set_gravity_direction(-1)
	_check(player.is_dashing() and player.velocity == before, "gravity change preserves diagonal dash")
	player.refill_from_crystal()
	_check(player.is_dashing() and player.velocity == before and player.is_dash_ready(), "crystal during dash preserves state")
	Input.action_release("dash")
	while player.is_dashing():
		await _step()
	_check(player.is_dash_ready(), "dash end does not erase crystal refill")
	var end_y := player.velocity.y
	await _step()
	_check(player.velocity.y < end_y, "new gravity applies after dash")
	for gravity in [1, -1]:
		await _reset(Vector2(400, 650 if gravity > 0 else 50), gravity)
		Input.action_press("move_down" if gravity > 0 else "move_up")
		Input.action_press("dash")
		await _step()
		Input.action_release("dash")
		await _step(3)
		_check(player.position.y <= 674.1 and player.position.y >= 25.9, "vertical dash cannot cross floor/ceiling")
		_check(player.is_on_floor() and player.is_dash_ready(), "landing during dash refills")
		await _wall(gravity)
		player._dash_ready = false
		await _step()
		_check(not player.is_dash_ready(), "wall grab never refills dash")
		# Hold against a wall without moving to measure full drain durations.
		player.wall_climb_speed = 0
		player._wall_stamina = player.wall_stamina_max
		Input.action_press("move_up" if gravity > 0 else "move_down")
		await _step(179)
		_check(player.is_wall_grabbing() and player.get_wall_stamina() < 0.03, "climbing stamina lasts approximately 3 seconds")
		await _step(2)
		_check(player._grab_exhausted and not player.is_wall_grabbing(), "climbing exhausts at 3 seconds")
		await _wall(gravity)
		player._wall_stamina = player.wall_stamina_max
		await _step(539)
		_check(player.is_wall_grabbing() and player.get_wall_stamina() < 0.01, "idle stamina lasts approximately 9 seconds")
		await _step(2)
		_check(player._grab_exhausted, "idle exhausts at 9 seconds")
		player.wall_climb_speed = 230
	await _reset(Vector2(400, 674))
	await _step(2)
	Input.action_press("dash")
	await _step()
	Input.action_release("dash")
	while player.is_dashing():
		await _step()
	await _step(9)
	Input.action_press("jump")
	await _step()
	_check(player.velocity.x < player.dash_speed * player.dash_end_speed_ratio, "expired superdash does not restore boost")
