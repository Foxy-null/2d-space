extends SceneTree

var stage
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.player.set_physics_process(false)
	var wall: StaticBody2D = stage.room._block(Rect2(550, 100, 24, 300))
	await _step(2)
	var needle = _shoot(Vector2(100, 200), Vector2.RIGHT, 0)
	needle.advance(1.0, stage.player)
	_check(needle.stuck and needle.anchor == wall, "A fast needle sticks at the first terrain surface without tunneling")
	_check(is_equal_approx(needle.global_position.x, 550.0), "The embedded end stays at the terrain surface")
	_check(needle.is_dangerous(), "An uncovered tip remains dangerous")
	needle.advance(60.0, stage.player)
	_check(not needle.is_queued_for_deletion(), "A stuck needle does not expire")
	_place(stage.player, needle.tip_position())
	_check(stage._touches_hazard(stage.player, stage.player.position), "Only the exposed needle tip acts as a spike")
	_place(stage.player, needle.global_position - Vector2(30, 0))
	_check(not stage._touches_hazard(stage.player, stage.player.position), "The shaft has no hidden spike hitbox")
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = needle.tip_position() - Vector2(170, 0)
	stage.room.get_node("Items").add_child(box)
	box.linear_velocity = Vector2(700, 0)
	stage._on_release(box, true, stage.player)
	box.position = needle.tip_position() + Vector2(50, 0)
	stage._check_projectiles()
	_check(box.pinned_to == needle and box.freeze and box.freeze_mode == RigidBody2D.FREEZE_MODE_STATIC, "A swept box throw embeds and becomes a fixed platform")
	_check(not needle.is_dangerous(), "The box completely covers the hazardous tip")
	_place(stage.player, box.position - Vector2(70, 0))
	_check(not stage.player.try_begin_grab(box), "A pinned platform cannot be accidentally picked up")
	_place(stage.player, box.position - Vector2(0, 60))
	stage.player.set_physics_process(true)
	await _step(12)
	_check(stage.player.is_on_floor() and stage.player.position.y < box.position.y - 45.0, "The player can really stand on the pinned box")
	_check(not stage._touches_hazard(stage.player, stage.player.position), "Standing on the box is safe")
	stage.player.set_physics_process(false)
	stage._keep_enemy_on_respawn = true
	stage.player.respawn(false)
	stage._keep_enemy_on_respawn = false
	_check(box.pinned_to == needle and box.freeze, "Falling preserves the constructed route")
	stage.player.respawn()
	_check(stage.room.needles.get_child_count() == 0 and not box.freeze and box.pinned_to == null, "Full retry removes needles and releases all pinned boxes")
	box.queue_free()
	await _step(2)
	var brittle: StaticBody2D = stage.room.brittle_platforms[0]
	needle = _shoot(brittle.position - Vector2(0, 150), Vector2.DOWN, 1)
	needle.advance(0.4, stage.player)
	_check(needle.stuck and brittle.collision_layer == 1, "Short needles remain embedded in brittle terrain")
	var long_needle = _shoot(brittle.position - Vector2(0, 150), Vector2.DOWN, 0)
	long_needle.advance(0.4, stage.player)
	_check(brittle.collision_layer == 0 and not brittle.visible, "Long needles destroy visibly cracked optional terrain")
	needle.advance(0.01, stage.player)
	_check(needle.is_queued_for_deletion(), "Needles cannot float after their supporting terrain breaks")
	stage.player.respawn()
	_check(brittle.collision_layer == 1 and brittle.visible, "Retry restores destructible terrain")
	_place(stage.player, Vector2(350, 200))
	stage._hit_grace = 0.0
	_shoot(Vector2(100, 200), Vector2.RIGHT, 0)
	stage._update_needles(1.0)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 2.0), "A swept flight hits the player before reaching a wall behind them")
	stage.player.respawn()
	_place(stage.player, Vector2(650, 200))
	stage._hit_grace = 0.0
	_shoot(Vector2(100, 200), Vector2.RIGHT, 0)
	stage._update_needles(1.0)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 3.0), "Terrain blocks damage to a player behind the wall")
	stage.player.respawn()
	await _attack_patterns()
	await _poses()
	_pause_and_retry()
	_art_invariants()
	print("STAGE_6_NEEDLES_TEST_OK (%d checks)" % checks)
	quit()


func _attack_patterns() -> void:
	_place(stage.enemy, Vector2(100, 200))
	_place(stage.player, Vector2(400, 200))
	stage.enemy.active = true
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	_check(stage.enemy._needle_warning > 0.0 and stage.room.needles.get_child_count() == 0, "A needle attack always gives warning before spawning")
	var aim: Vector2 = stage.enemy._needle_aim
	_place(stage.player, Vector2(440, 240))
	stage.enemy._update_needle_attack(0.81)
	_check(stage.room.needles.get_child_count() == 1 and stage.enemy._needle_aim == aim, "The long shot uses a locked aim that can be dodged")
	_check(stage.enemy._needle_recovery > 0.0, "Firing creates a chance to escape or throw back")
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	stage.enemy._update_needle_attack(1.01)
	_check(stage.room.needles.get_child_count() == 4, "The next pattern fires three short needles")
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	stage.enemy.apply_stun(0.4)
	stage.enemy._update_needle_attack(0.1)
	_check(stage.enemy._needle_warning < 0.0 and stage.room.needles.get_child_count() == 4, "Stunning the enemy cancels its warning attack")
	await _step(2)


func _poses() -> void:
	var sprite: AnimatedSprite2D = stage.enemy.get_node("Visuals/EnemySprite")
	stage.enemy.stun_left = 0.0
	stage.enemy.active = false
	sprite._process(0.0)
	_check(sprite.animation == &"idle", "The enemy has its own standing artwork before the chase")
	var height := sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_height() * sprite.scale.y
	_check(is_equal_approx(height, 96.0) and height > 52.0, "Enemy artwork is larger than the ninja")
	_check(sprite.sprite_frames.get_frame_count(&"walk") == 2, "Both supplied walking frames are assigned")
	stage.enemy.active = true
	stage.enemy.velocity = Vector2(0, 100)
	sprite._process(0.0)
	_check(sprite.animation == &"descend", "Moderate descent uses the designated descending drawing")
	stage.enemy.velocity = Vector2(0, 600)
	sprite._process(0.0)
	_check(sprite.animation == &"jump" and not is_zero_approx(sprite.rotation), "Fast falling tilts the jump artwork instead of using defeated")
	stage.enemy.defeated = true
	sprite._process(0.0)
	_check(sprite.animation == &"defeated", "The defeated artwork is reserved for damage and defeat")
	stage.enemy.defeated = false
	for direction in [1, -1, 2, -2]:
		stage.enemy.set_gravity_direction(direction)
		stage.enemy.velocity = -stage.enemy.get_gravity_vector() * 300.0
		sprite._process(0.0)
		_check(sprite.animation == &"jump", "Sprite selection follows all four gravity directions")


func _shoot(at: Vector2, direction: Vector2, variant: int):
	var directions: Array[Vector2] = [direction]
	stage._spawn_needles(at, directions, variant)
	return stage.room.needles.get_child(-1)


func _pause_and_retry() -> void:
	stage.player.respawn()
	var needle = _shoot(Vector2(200, 100), Vector2.RIGHT, 0)
	var before: Vector2 = needle.position
	stage._chase_delay = 1.0
	var pause = stage.get_node("PauseMenu")
	pause.open()
	stage._physics_process(0.5)
	_check(paused and needle.position == before and stage._chase_delay == 1.0, "Shared pause freezes needles and the root chase clock")
	pause.retry()
	_check(not paused and stage.room.needles.get_child_count() == 0 and stage.player.position == stage.room.spawn, "Shared retry finds the nested player and resets the room")


func _art_invariants() -> void:
	var path := "res://assets/enemies/star-mountain/"
	var repairs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "repairs.json"))
	var total := 0
	for pose in repairs:
		var entry: Dictionary = repairs[pose]
		var original := Image.new()
		var edited := Image.new()
		original.load_png_from_buffer(FileAccess.get_file_as_bytes(path + "originals/" + entry.source + ".png"))
		edited.load_png_from_buffer(FileAccess.get_file_as_bytes(path + pose + ".png"))
		var intact := original.get_size() == edited.get_size()
		for y in original.get_height():
			for x in original.get_width():
				if original.get_pixel(x, y) != edited.get_pixel(x, y):
					total += 1
					intact = intact and entry.pixels.any(func(point): return int(point[0]) == x and int(point[1]) == y) and original.get_pixel(x, y).a < 0.05
		_check(intact, "Original white design and every pixel outside the recorded transparent repair remain intact: " + pose)
	_check(total == 1, "Only the one unambiguous transparent pinhole is changed; redraw candidates are not used")


func _place(actor: PlayerController, at: Vector2) -> void:
	actor.position = at
	actor.velocity = Vector2.ZERO
	actor._contacts_valid = false
	if actor == stage.player:
		stage._previous_player = at
	else:
		stage._previous_enemy = at


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_6_NEEDLES: " + message)
		quit(1)
