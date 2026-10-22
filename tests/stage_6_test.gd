extends SceneTree

const STAGE = preload("res://scripts/stage_6.gd")
const PLAYER = preload("res://scenes/player.tscn")
const BOX = preload("res://scenes/grabbable.tscn")
var checks := 0
var stage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(STAGE.capture_probability(3, 3) == 0.0, "Full stamina has zero capture failure risk")
	_check(is_equal_approx(STAGE.capture_probability(1.5, 3), 0.5), "Half stamina has a 50% capture failure risk")
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
	await _arrival_latency()
	await _enemy_behavior()
	await _four_gravities()
	await _projectiles_and_retry()
	await _fall_keeps_chaser()
	await _final_endings()
	await _capture_results()
	print("STAGE_6_TEST_OK (%d checks)" % checks)
	quit()


func _enemy_behavior() -> void:
	stage._load_room(0)
	await _step(3)
	stage.player.set_physics_process(false)
	_place(stage.player, Vector2(450, 794))
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
	_check(not throws.is_empty(), "The enemy picks up shared stock and performs real throws")
	stage.enemy.set_physics_process(false)
	stage.enemy.respawn(false)
	stage.enemy.set("_pickup_left", 0.0)
	var stock: Grabbable = stage.room.get_node("Items").get_child(0)
	stock.reset_for_respawn()
	_place(stage.enemy, stock.position - Vector2(80, 0))
	await _step(3)
	stage.enemy.set("_pickup_left", 0.0)
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


func _fall_keeps_chaser() -> void:
	stage._load_room(1)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	_place(stage.player, Vector2(600, 794))
	_place(stage.enemy, Vector2(620, 780))
	await _step(3)
	var item: Grabbable = stage.room.get_node("Items").get_child(0)
	_check(stage.enemy.try_begin_grab(item), "Enemy holds a real shared item before the player falls")
	var weight: Grabbable = stage.room.get_node("Items").get_child(1)
	weight.position = stage.room.doors[0].button.position - Vector2(0, 60)
	weight.linear_velocity = Vector2.ZERO
	await _step(30)
	stage.enemy.set("active", true)
	stage._chase_delay = 0.0
	stage.enemy.stun_left = 0.75
	stage.enemy.velocity = Vector2(120, -80)
	stage.enemy.set_gravity_direction(-1)
	var enemy_position: Vector2 = stage.enemy.position
	var enemy_velocity: Vector2 = stage.enemy.velocity
	var clock: float = stage.room._elapsed
	_place(stage.player, Vector2(900, stage.room.size.y + 200))
	stage._physics_process(0.0)
	_check(stage.player.position == stage.room.spawn, "A real out-of-course check returns only the player to the entrance")
	_check(stage.enemy.position == enemy_position and stage.enemy.velocity == enemy_velocity and stage.enemy.gravity_direction == -1 and stage.enemy.stun_left == 0.75, "Fall recovery preserves enemy position, momentum, gravity and stun")
	_check(stage.enemy.get_held_object() == item and item.carrier == stage.enemy and stage.enemy.get("active"), "Fall recovery preserves enemy carrying and pursuit state")
	_check(stage.room.all_weight_doors_open() and stage.room._elapsed == clock, "Falling does not reset open doors, weights or the room clock")
	_place(stage.player, stage.room.moving_hazards[0].current.get_center())
	stage._physics_process(0.0)
	_check(stage.player.position == stage.room.spawn and stage.enemy.position == enemy_position, "Spike recovery also leaves the enemy in place")
	stage.player.respawn()
	await _step(3)
	_check(stage.enemy.position == stage.room.enemy_spawn and not stage.enemy.get("active") and not stage.room.all_weight_doors_open(), "An explicit full retry still resets both actors and room mechanisms")
	stage._load_room(11)
	stage.defeat_hits = 4
	stage.escape_elapsed = 7.0
	stage.room.key_collected = true
	var last_enemy_position: Vector2 = stage.enemy.position
	_place(stage.player, Vector2(900, stage.room.size.y + 200))
	stage._physics_process(0.0)
	_check(stage.defeat_hits == 4 and stage.escape_elapsed == 7.0 and stage.room.key_collected and stage.enemy.position == last_enemy_position, "Falling preserves final-room objectives as well as the enemy")
	stage.player.set_physics_process(true)
	stage.enemy.set_physics_process(true)


func _final_endings() -> void:
	for result in ["封じ込め成功", "逃走成功", "決着成功"]:
		await _new_stage()
		stage._load_room(11)
		await _step(3)
		stage.player.set_physics_process(false)
		stage.enemy.set_physics_process(false)
		stage.enemy.set("active", true)
		_place(stage.player, Vector2(3510, 1030))
		_place(stage.enemy, stage.room.cage.get_center())
		stage.escape_elapsed = stage.escape_seconds
		stage.room.update_escape(true)
		_check(stage.room.arrival.locked, "Time alone does not unlock escape without the key and weights")
		_place(stage.enemy, stage.room.escape_key.position)
		await _step(3)
		_check(not stage.room.key_collected, "The enemy cannot collect the player's escape key")
		_place(stage.player, stage.room.escape_key.position)
		await _step(3)
		_check(stage.room.key_collected and not stage.room.escape_key.visible, "Real player contact collects the escape key")
		_place(stage.player, Vector2(3510, 1030))
		_place(stage.enemy, stage.room.cage.get_center())
		stage.room.update_escape(true)
		_check(stage.room.arrival.locked, "The key and time cannot bypass common weight challenges")
		for door in stage.room.doors:
			_put_weight(door.button.position, stage.room.HEAVY if door.button.required_weight > 2 else stage.room.LIGHT)
		await _step(30)
		_check(stage.room.escape_unlocked and not stage.room.arrival.locked, "Escape requires both weights, the key and the chase timer")
		if result == "封じ込め成功":
			_put_weight(stage.room.seal_button.position, stage.room.LIGHT)
			await _step(15)
		elif result == "逃走成功":
			_place(stage.player, stage.room.exit_rect.get_center())
			stage.room.exit_open = true
			await _step(2)
		else:
			var object: Grabbable = stage.room.get_node("Items").get_child(0)
			for hit in stage.defeat_hits_required:
				stage.enemy.stun_left = 0.0
				_hit_enemy(object)
				if hit == 0:
					_hit_enemy(object)
					_check(stage.defeat_hits == 1, "Repeated impacts during stun do not count toward defeat")
				if hit < stage.defeat_hits_required - 1:
					_check(not stage.completed, "Defeat requires all six fresh hits")
		_check(stage.completed and stage.ending == result and stage._completion.card.visible, "All three endings reach the shared clear screen")
		_check(not stage.player.controls_enabled and not stage.enemy.controls_enabled, "Both actors stop after completion")
		if OS.get_cmdline_user_args().has("--screenshots"):
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-6/%s.png" % {"封じ込め成功": "seal", "逃走成功": "escape", "決着成功": "defeat"}[result])
	await _new_stage()
	stage._load_room(11)
	await _step(3)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage._chase_delay = 0.0
	_place(stage.player, Vector2(3500, 1000))
	await _step(60)
	_check(stage.escape_elapsed == 0.0, "Waiting while the enemy is stuck outside the arena does not release escape")
	_place(stage.enemy, Vector2(3100, 1000))
	await _step(60)
	_check(stage.escape_elapsed > 0.9, "The escape clock runs while both actors are in the arena")
	stage.player.respawn()
	_check(stage.defeat_hits == 0 and stage.escape_elapsed == 0.0 and not stage.room.key_collected and stage.room.arrival.locked, "Retry resets the three ending objectives")


func _hit_enemy(object: Grabbable) -> void:
	object.position = stage.enemy.position - Vector2(150, 0)
	object.linear_velocity = Vector2(1000, 0)
	stage._on_release(object, true, stage.player)
	object.position = stage.enemy.position + Vector2(150, 0)
	stage._check_projectiles()


func _arrival_latency() -> void:
	stage._load_room(1)
	stage.enemy.set_physics_process(false)
	stage._chase_delay = 999.0
	_place(stage.player, stage.room.exit_position + Vector2(65, -160))
	var activated_at := [-1]
	stage.room.arrival.activated.connect(func(): activated_at[0] = Engine.get_physics_frames())
	for frame in 90:
		await _step()
		if stage.room_index == 2:
			break
	_check(activated_at[0] >= 0 and stage.room_index == 2, "Pressing the arrival cap at its edge advances the room")
	_check(Engine.get_physics_frames() - activated_at[0] <= 2, "Room transition follows activation within two physics ticks")
	stage.enemy.set_physics_process(true)


func _capture_results() -> void:
	await _new_stage()
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage._update_hud()
	_check(stage._status.text.contains("捕獲時の失敗率   0%"), "The HUD reports zero failure risk at full stamina")
	var stock: Grabbable = stage.room.get_node("Items").get_child(0)
	_place(stage.player, Vector2(450, 794))
	_place(stage.enemy, stock.position - Vector2(80, 0))
	await _step(3)
	_check(stage.enemy.try_begin_grab(stock), "Enemy can hold an item in the capture fixture")
	stage._capture()
	_check(not stage._capture_pending and stage.enemy.get_held_object() == stock, "A carrying enemy cannot grab the player or discard its item to capture")
	stage.enemy.velocity = Vector2.ZERO
	stage.enemy.release_grab()
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
