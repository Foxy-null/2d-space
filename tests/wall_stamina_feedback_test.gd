extends SceneTree

var failed := false
var player: PlayerController
var sprite: AnimatedSprite2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	sprite = player.get_node("Visuals/Body")
	sprite.set_process(false)
	var sweat: Node2D = sprite.get_node("WallSweat")
	_check(not sweat.visible, "No sweat on spawn")
	for gravity in [1, -1, 2, -2]:
		player.set_gravity_direction(gravity)
		if player._gravity_tween:
			player._gravity_tween.kill()
		var down := player.get_gravity_vector()
		player.visuals.rotation = Vector2.DOWN.angle_to(down)
		for side in [-1, 1]:
			player.facing_direction = side
			player._wall_grabbing = true
			player._wall_stamina = player.wall_stamina_max
			_set_input(-down)
			player.velocity = Vector2.ZERO
			sprite._process(0.15)
			_check(sweat.visible, "Climb input shows sweat even when movement is blocked")
			var offset := sweat.global_position - player.global_position
			_check(offset.dot(down) < -20.0, "Sweat stays above the head under all gravities")
			_check(offset.dot(player.get_walk_axis() * side) < -10.0, "Sweat stays opposite either wall")
			_check(sweat.global_scale.is_equal_approx(Vector2.ONE), "Sweat keeps its size under sprite scaling")
			_set_input(down)
			sprite._process(0.1)
			_check(not sweat.visible, "Descending does not show sweat")
			_set_input(Vector2.ZERO)
			sprite._process(0.1)
			_check(not sweat.visible, "Resting does not show sweat")
	player._wall_stamina = player.wall_stamina_max * 0.3
	sprite._process(0.2)
	_check(_tint() == 0.0, "Exactly 30 percent does not flash")
	player._wall_stamina = player.wall_stamina_max * 0.299
	sprite._process(0.2)
	_check(_tint() > 0.0, "Below 30 percent starts flashing while resting on a wall")
	var pulses: Array[int] = []
	for ratio in [0.299, 0.15, 0.001]:
		player._wall_grabbing = false
		sprite._process(0.0)
		player._wall_grabbing = true
		player._wall_stamina = player.wall_stamina_max * ratio
		var count := 0
		var previous := 0.0
		for frame in 600:
			sprite._process(1.0 / 60.0)
			var tint := _tint()
			_check(tint >= 0.0 and tint <= 1.0, "Flash strength stays bounded")
			if previous < 0.5 and tint >= 0.5:
				count += 1
			previous = tint
		pulses.append(count)
	_check(pulses[0] == 10, "Near 30 percent flashes once per second")
	_check(pulses[0] < pulses[1] and pulses[1] < pulses[2], "Flashing accelerates as stamina falls")
	_check(pulses[2] == 25, "Near empty flashes at most 2.5 times per second")
	player._dash_ready = false
	player._notify_resources()
	player.modulate.a = 0.55
	_set_input(-player.get_gravity_vector())
	sprite._process(0.15)
	_check(sweat.visible and _tint() > 0.0, "Sweat and low-stamina flashing can coexist")
	_check(sprite.material.get_shader_parameter("outfit_color") == PlayerController.DASH_USED_COLOR, "Dash outfit color survives fatigue")
	_check(is_equal_approx(player.modulate.a, 0.55) and sprite.modulate.a == 1.0, "Damage opacity flashing is preserved")
	_check(sweat.material == null and not sweat.use_parent_material, "Sweat keeps its blue color during the red flash")
	player._wall_grabbing = false
	sprite._process(0.1)
	_check(not sweat.visible and _tint() == 0.0, "Releasing the wall immediately clears both effects")
	player._wall_grabbing = true
	player.controls_enabled = false
	sprite._process(0.1)
	_check(not sweat.visible and _tint() == 0.0, "Disabled controls clear wall effects")
	player.controls_enabled = true
	sprite._process(0.1)
	player.respawn()
	_check(not sweat.visible and _tint() == 0.0, "Respawn immediately clears both effects")
	_set_input(Vector2.ZERO)
	print("WALL_STAMINA_FEEDBACK_TEST_%s (pulses per 10s: %s)" % ["FAILED" if failed else "OK", pulses])
	quit(1 if failed else 0)


func _set_input(direction: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if direction.x != 0.0:
		Input.action_press("move_right" if direction.x > 0.0 else "move_left")
	if direction.y != 0.0:
		Input.action_press("move_down" if direction.y > 0.0 else "move_up")


func _tint() -> float:
	return sprite.material.get_shader_parameter("fatigue_tint")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
