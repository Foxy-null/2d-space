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
	await _homing()
	await _cloud()
	await _poses()
	await _superdash()
	await _spikes()
	print("STAGE_6_ATTACKS_TEST_OK (%d checks)" % checks)
	quit()


func _homing() -> void:
	stage.player.position = Vector2(450, 400)
	var needle = _shoot(Vector2(150, 200), Vector2.RIGHT, 2)
	var start: Vector2 = needle.position
	needle.advance(0.3, stage.player)
	_check(needle.position == start and not needle.flew and needle.picture.texture.atlas.resource_path.ends_with("homing-neutral.png"), "c1 waits in its neutral state before launch")
	needle.advance(0.36, stage.player)
	_check(needle.flew and needle.velocity.y > 0 and needle.picture.texture.atlas.resource_path.ends_with("homing-flight.png"), "c2 ignites and steers toward the player")
	var before: float = needle.velocity.angle()
	stage.player.position = Vector2(-300, 900)
	needle.advance(0.05, stage.player)
	_check(absf(angle_difference(before, needle.velocity.angle())) <= 2.3 * 0.05 + 0.001, "Homing turn rate is bounded so it can be dodged")
	needle.tracking_left = 0.0
	var direction: Vector2 = needle.velocity
	needle.advance(0.1, stage.player)
	_check(needle.velocity.is_equal_approx(direction), "Homing ends instead of chasing indefinitely")
	needle.life = 0.01
	needle.advance(0.02, stage.player)
	_check(needle.is_queued_for_deletion(), "An airborne homing spine has a finite lifetime")
	await _step(2)
	var wall = stage.room._block(Rect2(600, 100, 30, 400))
	await _step(2)
	needle = _shoot(Vector2(300, 250), Vector2.RIGHT, 2)
	needle.neutral_left = 0.0
	needle.tracking_left = 0.0
	needle.advance(1.0, stage.player)
	_check(needle.stuck and needle.anchor == wall, "A homing spine hits terrain instead of passing through it")
	_check(needle.picture.texture.atlas.resource_path.ends_with("homing-neutral.png"), "An embedded homing spine stops its flame and returns to c1")
	stage.enemy.position = needle.tip_position()
	stage.player.position = needle.tip_position()
	_check(not stage._touches_hazard(stage.enemy, stage.enemy.position) and stage._touches_hazard(stage.player, stage.player.position), "The same exposed tip hurts only the ninja")
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = needle.tip_position() - Vector2(70, 0)
	stage.room.get_node("Items").add_child(box)
	_check(needle.pin_box(box, stage.player) and not needle.is_dangerous(), "Homing spines also accept boxes as safe platforms")
	stage.player.respawn()
	await _step(2)


func _cloud() -> void:
	stage.enemy.position = Vector2(150, 700)
	stage.player.position = Vector2(800, 700)
	stage._spawn_ash_cloud(stage.enemy.position, stage.player.position, Vector2.DOWN)
	var cloud = stage.room.get_node("AshClouds").get_child(0)
	var locked: Vector2 = cloud.position
	var points: Array[Vector2] = []
	cloud.rain.connect(func(at, _down): points.append(at))
	cloud.advance(1.79)
	_check(points.is_empty(), "Smoke gathers into a cloud before any damaging rain appears")
	stage.player.position.x += 250
	cloud.advance(0.02)
	_check(points.size() == 3 and cloud.position == locked, "The first rain row has three shards and does not follow a dodging player")
	_check(is_equal_approx(points[1].x - points[0].x, 160.0), "Rain leaves wide escape lanes")
	cloud.advance(2.5)
	_check(points.size() == 15 and cloud.waves == 6, "Six alternating rain rows emit fifteen actual shards")
	_check(stage.room.needles.get_child_count() == 15, "Ash rain uses the shared swept projectile and embedded-tip rules")
	for needle in stage.room.needles.get_children():
		_check(needle.variant == 3 and needle.velocity == Vector2.DOWN * 660.0, "Solid ash falls along the cast gravity")
	var rain = stage.room.needles.get_child(0)
	stage.player.position = rain.position + Vector2(0, 100)
	stage._previous_player = stage.player.position
	stage._hit_grace = 0.0
	stage._update_needles(0.2)
	_check(stage.player.get_wall_stamina() < stage.player.wall_stamina_max, "Solidified ash actually damages the player on a swept hit")
	var elapsed: float = cloud.elapsed
	stage._keep_enemy_on_respawn = true
	stage.player.respawn(false)
	stage._keep_enemy_on_respawn = false
	_check(stage.room.get_node("AshClouds").get_child(0) == cloud, "Ordinary falling preserves the active cloud and rain")
	paused = true
	stage._physics_process(1.0)
	_check(cloud.elapsed == elapsed, "Pause freezes cloud timers and rain spawning")
	paused = false
	stage.player.respawn()
	_check(stage.room.get_node("AshClouds").get_child_count() == 0 and stage.room.needles.get_child_count() == 0, "A full retry clears clouds and all rain")
	var ceiling = stage.room._block(Rect2(500, 400, 600, 30))
	await _step(2)
	stage._spawn_ash_cloud(Vector2(200, 650), Vector2(800, 600), Vector2.DOWN)
	cloud = stage.room.get_node("AshClouds").get_child(0)
	_check(cloud.position.y > 430.0, "A low ceiling forms the cloud underneath instead of inside terrain")
	var blocked_direction: Array[Vector2] = [Vector2.DOWN]
	stage._spawn_needles(ceiling.position, blocked_direction, 3)
	_check(stage.room.needles.get_child_count() == 0, "A rain source inside terrain cannot shoot through the solid from inside")
	cloud.advance(5.4)
	_check(cloud.is_queued_for_deletion(), "The cloud expires after its finite attack")
	stage.player.respawn()
	await _step(2)
	for gravity in [Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		stage._spawn_ash_cloud(Vector2(100, 300), Vector2(300, 300), gravity)
		cloud = stage.room.get_node("AshClouds").get_child(0)
		points.clear()
		var directions: Array[Vector2] = []
		cloud.rain.connect(func(at, direction): points.append(at); directions.append(direction))
		cloud.advance(1.81)
		_check(directions.size() == 3 and directions[0] == gravity and absf((points[1] - points[0]).dot(gravity)) < 0.01, "Clouds and their escape lanes rotate with gravity")
		stage.player.respawn()
	await _step(2)
	stage.enemy.position = Vector2(150, 200)
	stage.player.position = Vector2(400, 200)
	stage.enemy.active = true
	stage.enemy.stun_left = 0.0
	stage.enemy._needle_variant = 3
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	_check(stage.enemy._needle_warning > 0.0, "The AI announces its ash attack")
	stage.enemy._update_needle_attack(1.01)
	_check(stage.room.get_node("AshClouds").get_child_count() == 1 and stage.enemy._needle_variant == 0, "The AI casts a cloud and cycles back to straight needles")
	stage.player.respawn()
	await _step(2)


func _poses() -> void:
	var enemy = stage.enemy
	var sprite = enemy.get_node("Visuals/EnemySprite")
	enemy.active = false
	enemy.facing_direction = -1
	sprite._process(0.0)
	_check(sprite.animation == &"idle_left" and not sprite.flip_h, "Left neutral uses the supplied sozai156 without an extra mirror")
	enemy.position = Vector2(400, 790)
	enemy.velocity = Vector2(0, 400)
	enemy._move_player()
	enemy._contacts_valid = true
	enemy.active = true
	enemy.facing_direction = 1
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = Vector2(440, 760)
	stage.room.get_node("Items").add_child(box)
	await _step(2)
	enemy._pickup_left = 0.0
	_check(enemy.try_begin_grab(box), "Pose test holds a real box")
	enemy.velocity = Vector2(220, 0)
	sprite._process(0.0)
	_check(enemy.is_on_floor() and sprite.animation == &"carry_walk" and sprite.sprite_frames.get_frame_count("carry_walk") == 2, "Carrying on the ground uses both new walking frames before airborne fallback")
	enemy.velocity = Vector2.ZERO
	sprite._process(0.0)
	_check(sprite.animation == &"descend", "Stationary carrying keeps raised hands")
	enemy.release_grab()
	enemy.throw_pose_left = 0.0
	enemy._dash_left = 0.1
	sprite._process(0.0)
	_check(sprite.animation == &"dash", "A real dash uses sozai9")
	enemy._dash_left = 0.0
	enemy.movement_action.emit("superdash")
	sprite._process(0.0)
	_check(sprite.animation == &"superdash", "The superdash event uses sozai10")
	sprite.superdash_left = 0.0
	enemy._wall_grabbing = true
	sprite._process(0.0)
	_check(sprite.animation == &"wall_climb", "A wall grab uses sozai11")
	enemy._wall_grabbing = false
	enemy.throw_pose_left = 0.5
	enemy.stun_left = 0.4
	sprite._process(0.0)
	_check(sprite.animation == &"throwback", "Capture throwback has priority over its intentional stun")
	enemy.throw_pose_left = 0.0
	sprite._process(0.0)
	_check(sprite.animation == &"defeated", "Ordinary damage still uses the defeated artwork")
	enemy.stun_left = 0.0
	enemy.respawn(false)
	await _step(2)


func _superdash() -> void:
	stage._load_room(1)
	stage.room.set_physics_process(false)
	for item in stage.room.get_node("Items").get_children():
		item.free()
	stage.enemy.position = Vector2(170, 794)
	stage.player.position = Vector2(1040, 794)
	stage.enemy.active = true
	stage.enemy._pickup_left = 99.0
	stage.enemy._needle_cooldown = 99.0
	var actions: Array[String] = []
	stage.enemy.movement_action.connect(func(action): actions.append(action))
	stage.enemy.set_physics_process(true)
	await _step(30)
	_check(actions.has("dash") and actions.has("superdash"), "AI performs a real grounded dash followed by a superdash jump")
	stage.enemy.set_physics_process(false)


func _spikes() -> void:
	stage.room._hazard(Rect2(50, -1000, 1100, 40))
	stage.room._hazard(Rect2(600, -1300, 70, 300))
	stage.enemy.set_respawn_position(Vector2(440, -1026))
	stage.enemy.reset_pursuit()
	stage.enemy._needle_cooldown = 999.0
	stage.enemy.active = true
	stage.player.position = Vector2(550, -1026)
	stage.enemy.set_physics_process(true)
	var walked := false
	var climbed := false
	for frame in 15:
		await _step()
		walked = walked or (stage.enemy.is_on_floor() and stage.enemy.position.x > 450)
	stage.player.position = Vector2(800, -1326)
	for frame in 240:
		await _step()
		walked = walked or (stage.enemy.is_on_floor() and stage.enemy.position.x > 450)
		climbed = climbed or stage.enemy.is_wall_grabbing()
		if climbed and stage.enemy.position.y < -1300:
			break
	_check(walked, "The enemy really walks on a spike floor using physical contact")
	_check(climbed and stage.enemy.position.y < -1300, "The enemy really grips and climbs a spike wall")
	_check(not stage.room.hazard_ahead(stage.enemy, 1.0), "Immune AI does not avoid spike surfaces as lethal hazards")
	stage.enemy.set_physics_process(false)
	stage.player.position = Vector2(400, -1026)
	_check(not stage.player.test_move(stage.player.global_transform, Vector2(0, 100)), "Enemy-only spike surfaces do not change the ninja physics mask")
	stage.player.position = Vector2(400, -990)
	_check(stage._touches_hazard(stage.player, stage.player.position), "Spike floors still kill the ninja")


func _shoot(at: Vector2, direction: Vector2, variant: int):
	var directions: Array[Vector2] = [direction]
	stage._spawn_needles(at, directions, variant)
	return stage.room.needles.get_child(-1)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_6_ATTACKS: " + message)
		quit(1)
