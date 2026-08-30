extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node("Player") as PlayerController
	assert(player != null)

	for _frame in 120:
		if player.is_on_floor():
			break
		await physics_frame
	assert(player.is_on_floor())

	var start_x := player.global_position.x
	Input.action_press("ui_right")
	for _frame in 10:
		await physics_frame
	Input.action_release("ui_right")
	assert(player.global_position.x > start_x)

	Input.action_press("ui_accept")
	await physics_frame
	Input.action_release("ui_accept")
	await physics_frame
	assert(player.velocity.y < 0.0)

	player.set_gravity_direction(-1, false)
	assert(player.gravity_direction == -1 and player.up_direction == Vector2.DOWN)
	player.set_gravity_direction(1, false)
	assert(player.gravity_direction == 1 and player.up_direction == Vector2.UP)

	print("BASE_SYSTEM_TEST_OK")
	quit()
