extends SceneTree

const STAGE = preload("res://scripts/stage_6.gd")
const PLAYER = preload("res://scenes/player.tscn")
const BOX = preload("res://scenes/grabbable.tscn")
var checks := 0
var stage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(is_equal_approx(STAGE.capture_probability(3, 3), 0.1), "Full stamina retains a 10% capture risk")
	_check(is_equal_approx(STAGE.capture_probability(1.5, 3), 0.55), "Half stamina has a 55% capture risk")
	_check(STAGE.capture_probability(0, 3) == 1.0 and STAGE.capture_probability(-1, 3) == 1.0, "Empty stamina always loses a capture")
	_check(STAGE._segment_hits_rect(Vector2(-200, 0), Vector2(200, 0), Rect2(-10, -10, 20, 20)), "Fast crossings cannot skip projectile/hazard contact")
	_check(not STAGE._segment_hits_rect(Vector2(-200, 40), Vector2(200, 40), Rect2(-10, -10, 20, 20)), "Near misses do not count as hits")
	await _new_stage()
	_check(stage.enemy is PlayerController, "Enemy shares the real player controller")
	_check(stage.enemy.move_speed == stage.player.move_speed and stage.enemy.jump_speed == stage.player.jump_speed and stage.enemy.wall_stamina_max == stage.player.wall_stamina_max, "Initial enemy movement and stamina match the player")
	_check(not stage.enemy.is_in_group("player"), "Enemy cannot be mistaken for player progression")
	for number in 12:
		stage._load_room(number)
		await _step(3)
		_check(stage.room.get_node("Items").get_child_count() > 0, "Every room supplies a throwable object")
		_check(stage.room.route.size() >= 4, "Every room has a chase route")
		_check(stage._backdrop.environment_theme == (3 if number < 6 else 4), "Unused lava/evil environments are assigned")
		if OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-6")
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-6/room_%02d.png" % (number + 1))
		stage.enemy.position = stage.room.exit_rect.get_center()
		stage._previous_enemy = stage.enemy.position
		stage.enemy.set("active", false)
		stage.enemy.set_physics_process(false)
		stage.room.exit_open = true
		await _step(2)
		_check(stage.room_index == number and not stage.completed, "Enemy at an open exit never advances or clears the room")
		stage.enemy.set_physics_process(true)
	await _enemy_behavior()
	await _four_gravities()
	await _projectiles_and_retry()
	await _final_endings()
	await _capture_results()
	print("STAGE_6_TEST_OK (%d checks)" % checks)
	quit()


func _enemy_behavior() -> void:
	stage._load_room(0)
	await _step(3)
	stage.player.set_physics_process(false)
	_place(stage.player, Vector2(450, 794))
	stage.enemy.set("route", [Vector2(260, 794), Vector2(440, 740)] as Array[Vector2])
	stage._immunity_left = 999.0
	var actions: Array[String] = []
	var throws: Array[Grabbable] = []
	stage.enemy.movement_action.connect(func(action): actions.append(action))
	stage.enemy.object_released.connect(func(object, thrown):
		if thrown:
			throws.append(object)
	)
	var start: Vector2 = stage.enemy.position
	await _step(180)
	_check(stage.enemy.position.distance_to(start) > 60.0, "The autonomous enemy follows the course without player input")
	_check(actions.has("jump") or actions.has("wall_jump"), "The enemy uses real movement actions along its route")
	_check(not throws.is_empty(), "The enemy picks up shared stock and performs real throws")
	stage.enemy.set_physics_process(false)
	stage.enemy.respawn(false)
	stage.enemy.set("_pickup_left", 0.0)
	var stock: Grabbable = stage.room.get_node("Items").get_child(0)
	stock.reset_for_respawn()
	_place(stage.enemy, stock.position - Vector2(50, 0))
	await _step(3)
	_check(stage.enemy.try_begin_grab(stock), "Enemy can acquire shared stock before throwing")
	stage.enemy.velocity = Vector2(300, 0)
	stage.enemy.release_grab()
	await _step(3)
	_check(not stage.enemy.try_begin_grab(stock), "Enemy does not immediately pick its own projectile back up")
	stage.enemy.set_physics_process(true)
	stage.player.set_physics_process(true)


func _four_gravities() -> void:
	stage.get_node("World").process_mode = Node.PROCESS_MODE_DISABLED
	stage.set_physics_process(false)
	var arena := Node2D.new()
	arena.position = Vector2(-4000, -4000)
	root.add_child(arena)
	for rect in [Rect2(0, 0, 600, 20), Rect2(0, 580, 600, 20), Rect2(0, 0, 20, 600), Rect2(580, 0, 20, 600)]:
		var wall := StaticBody2D.new()
		wall.position = rect.get_center()
		var collision := CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = rect.size
		wall.add_child(collision)
		arena.add_child(wall)
	var actor: PlayerController = PLAYER.instantiate()
	actor.use_default_respawn_bounds = false
	actor.position = Vector2(300, 300)
	arena.add_child(actor)
	actor.get_node("Camera2D").enabled = false
	for direction in [1, -1, 2, -2]:
		actor.position = Vector2(300, 300)
		actor.velocity = Vector2.ZERO
		actor.set_gravity_direction(direction)
		actor._contacts_valid = false
		await _step(65)
		_check(actor.is_on_floor() and actor.get_floor_normal().dot(-actor.get_gravity_vector()) > 0.9, "All four gravity directions land against their own floor")
		var before := actor.position
		var action := "move_right" if abs(direction) == 1 else "move_down"
		Input.action_press(action)
		await _step(8)
		Input.action_release(action)
		_check((actor.position - before).dot(actor.get_walk_axis()) > 8.0, "Walking uses screen directions under every gravity")
		Input.action_press("jump")
		await _step()
		Input.action_release("jump")
		_check(actor.velocity.dot(actor.get_gravity_vector()) < -300.0, "Jump pushes away from the current floor")
	actor.set_physics_process(false)
	actor.position = Vector2(300, 300)
	actor.set_gravity_direction(2)
	var box: Grabbable = BOX.instantiate()
	box.directional_gravity_enabled = true
	box.position = Vector2(340, 300)
	arena.add_child(box)
	await _step(2)
	_check(actor.try_begin_grab(box), "Horizontal gravity still permits real grab validation")
	_check(box.gravity_direction == 2, "Held objects inherit the carrier's gravity")
	actor.velocity = Vector2(0, -120)
	_check(actor.release_grab(), "Objects can be thrown under horizontal gravity")
	await _step(8)
	_check(box.carrier == null and box.gravity_direction == 2 and box.linear_velocity.x > 20.0, "Released objects retain and accelerate under horizontal gravity")
	var gate: Area2D = stage.room.GATE.instantiate()
	gate.position = box.position
	gate.target_gravity = -2
	arena.add_child(gate)
	await _step(3)
	_check(box.gravity_direction == -2, "A free object crossing a real gate receives its new gravity")
	box.position += Vector2(1000, 0)
	box.set_gravity_direction(1)
	gate._on_body_entered(box)
	_check(box.gravity_direction == 1, "A queued overlap cannot apply old gravity after a distant respawn")
	actor.set_gravity_direction(-2)
	actor.apply_stun(0.3, Vector2.ZERO, 1.0)
	actor._refill_on_landing()
	_check(is_equal_approx(actor.get_wall_stamina(), 2.0), "Landing during damage cooldown does not erase stamina damage")
	arena.queue_free()
	await _step(2)
	stage.get_node("World").process_mode = Node.PROCESS_MODE_PAUSABLE
	stage.set_physics_process(true)


func _projectiles_and_retry() -> void:
	stage._load_room(0)
	await _step(3)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.enemy.position = Vector2(500, 794)
	stage._previous_enemy = stage.enemy.position
	var object: Grabbable = stage.room.get_node("Items").get_child(0)
	object.position = stage.enemy.position - Vector2(150, 0)
	object.linear_velocity = Vector2(1000, 0)
	stage._on_release(object, true, stage.player)
	object.position = stage.enemy.position + Vector2(150, 0)
	stage._check_projectiles()
	_check(stage.enemy.stun_left == 2.0 and stage._projectiles.is_empty(), "A swept player throw stuns the enemy once")
	object.position = stage.player.position - Vector2(150, 0)
	stage._on_release(object, true, stage.enemy)
	object.position = stage.player.position + Vector2(150, 0)
	stage._check_projectiles()
	_check(is_equal_approx(stage.player.get_wall_stamina(), 2.0) and stage.player.stun_left == 0.3, "Enemy throws remove one third stamina and stagger the player")
	stage._check_projectiles()
	_check(is_equal_approx(stage.player.get_wall_stamina(), 2.0), "The same throw cannot damage every frame")
	stage.player.respawn()
	_place(stage.player, Vector2(180, 550))
	_place(stage.enemy, Vector2(500, 550))
	var shot: Grabbable = BOX.instantiate()
	shot.position = Vector2(340, 550)
	stage.room.get_node("Items").add_child(shot)
	shot.linear_velocity = Vector2(-1000, 0)
	stage._on_release(shot, true, stage.enemy)
	await _step(18)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 2.0), "A real rigid-body impact damages the player even when collision stops the projectile")
	shot.queue_free()
	stage.enemy.stun_left = 0.0
	shot = BOX.instantiate()
	shot.position = Vector2(340, 550)
	stage.room.get_node("Items").add_child(shot)
	shot.linear_velocity = Vector2(1000, 0)
	stage._on_release(shot, true, stage.player)
	await _step(18)
	_check(stage.enemy.stun_left == 2.0, "A real rigid-body impact also stuns the enemy")
	shot.queue_free()
	stage.player.respawn()
	_check(stage.player.position == stage.room.spawn and stage.enemy.position == stage.room.enemy_spawn, "Retry resets both actors to room entrances")
	_check(stage.player.get_wall_stamina() == 3.0 and not stage.room.exit_open, "Retry resets resources and room progress")
	stage.player.set_physics_process(true)
	stage.enemy.set_physics_process(true)
	stage.set_help_visible(true)
	var before: Vector2 = stage.enemy.position
	await _step(5)
	_check(paused and stage.enemy.position == before, "Help pauses the chase and all world physics")
	stage.set_help_visible(false)
	_check(not paused, "Resume unpauses the world")
	# Removing stock must replenish the original supply, with a finite item count.
	for item in stage.room.get_node("Items").get_children():
		item.position += Vector2(350, 0)
	stage.room._restock()
	_check(stage.room.get_node("Items").get_child_count() > 2, "A shared supply replenishes stock taken away by the enemy")
	for attempt in 9:
		for item in stage.room.get_node("Items").get_children():
			item.position += Vector2(350, 0)
		stage.room._restock()
	_check(stage.room.get_node("Items").get_child_count() <= 12, "Repeated throws cannot create unlimited rigid bodies")
	for supply in stage.room.supplies:
		var nearby: Array = stage.room.get_node("Items").get_children().filter(func(item): return item.position.distance_to(supply.at) < 150.0)
		_check(not nearby.is_empty(), "Supply still replenishes after reaching the body cap")


func _final_endings() -> void:
	for result in ["封じ込め成功", "逃走成功"]:
		await _new_stage()
		stage._load_room(11)
		await _step(3)
		stage.player.set_physics_process(false)
		stage.enemy.set_physics_process(false)
		stage.enemy.set("active", false)
		_place(stage.player, stage.room.exit_rect.get_center())
		_place(stage.enemy, stage.room.spawn)
		stage.room.exit_open = true
		await _step(2)
		_check(not stage.completed, "The escape exit alone cannot bypass both final weight challenges")
		if result == "封じ込め成功":
			_place(stage.player, Vector2(2330, 610))
			_place(stage.enemy, stage.room.cage.get_center())
			_put_weight(stage.room.seal_button.position, stage.room.LIGHT)
			await _step(15)
			_check(not stage.completed, "Caging the enemy alone cannot bypass final weight challenges")
		for door in stage.room.doors:
			_put_weight(door.button.position, stage.room.HEAVY if door.button.required_weight > 2 else stage.room.LIGHT)
		await _step(30)
		if not stage.completed:
			print("FINAL_FIXTURE ", result, " doors=", stage.room.doors.map(func(entry): return entry.button.total_weight), " seal=", stage.room.seal_button.total_weight, " player=", stage.player.position, " enemy=", stage.enemy.position)
		_check(stage.completed and stage.ending == result and stage._completion.card.visible, "Each difficult ending reaches the shared clear screen")
		_check(not stage.player.controls_enabled and not stage.enemy.controls_enabled, "Both actors stop after completion")
		if OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-6/%s.png" % ("seal" if result == "封じ込め成功" else "escape"))


func _capture_results() -> void:
	await _new_stage()
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	seed(12345)
	_check(randf() > 0.1, "The survival fixture selects the surviving branch")
	seed(12345)
	stage._capture()
	await _step(20)
	_check(not stage._game_over_pending and stage._immunity_left > 1.8 and stage.player.velocity.length() > 400, "A surviving capture throws the player back and grants recapture grace")
	_check(not stage._capture_pending, "The same capture resolves only once")
	stage.player._wall_stamina = 0.0
	stage._capture()
	await _step(90)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "A failed capture returns to stage selection")


func _put_weight(at: Vector2, scene: PackedScene) -> void:
	var item: Grabbable = scene.instantiate()
	item.position = at - Vector2(0, 60)
	item.directional_gravity_enabled = true
	stage.room.get_node("Items").add_child(item)


func _place(actor: PlayerController, at: Vector2) -> void:
	# Isolated collision/ending fixtures; traversal is verified separately with inputs.
	actor.position = at
	actor.velocity = Vector2.ZERO
	actor._contacts_valid = false
	if actor == stage.player:
		stage._previous_player = at
	else:
		stage._previous_enemy = at


func _new_stage() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_6: " + message)
		quit(1)
