extends SceneTree

var stage
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	await _presentation()
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	await _pickup_layout_and_hint()
	await _boundary_breaches()
	await _impact_and_box()
	await _pin_safety()
	await _hit_recovery()
	await _carried_shields()
	await _visible_shortcut()
	await _attacks()
	await _roof_cover()
	await _spawn_needle_lifetimes()
	await _escape_spawn()
	print("STAGE_6_PRESSURE_TEST_OK (%d checks)" % checks)
	quit()


func _presentation() -> void:
	_check(stage._intro_left > 0.0 and stage._intro_panel.visible, "The first room introduces the enemy before pursuit")
	_check(stage.room.entrance_wall.visible and stage.enemy.visuals.visible and stage.enemy.position.x > 0, "The first introduction keeps the enemy inside the room with the boundary wall intact")
	_check(stage._intro_panel.get_child(0).text.contains("UMA妖怪エイリアン") and stage._intro_panel.get_child(0).text.contains("星間山荒・大赤斑"), "The introduction shows both enemy names")
	_check(not stage.enemy.get_children().any(func(child): return child is Label and child.text == stage.enemy.ENEMY_NAME), "The individual name is not permanently displayed above the enemy")
	await _step(210)
	_check(stage._intro_left <= 0.0 and stage.player.controls_enabled, "The introduction ends and restores movement")
	stage._load_room(1)
	await _step(2)
	_check(stage.room.entrance_wall.visible and not stage.enemy.visuals.visible, "A new room first shows the intact wall")
	await _step(60)
	_check(not stage.room.entrance_wall.visible and stage.enemy.visuals.visible and stage.enemy.active, "The enemy breaks the wall and actually resumes pursuit")
	_check(stage._action.visible and not stage._action.text.is_empty(), "The message window describes offscreen enemy actions")
	for number in stage.ROOM.FINAL_ROOM:
		stage._load_room(number)
		if number in [0, 5, 9]:
			_check(is_equal_approx(stage.room.brittle_platforms[0].position.x, 1840.0 if number == 9 else 1136.0), "Extending a room does not move the original brittle platform into its exit switch")
		_check(stage.room.passage_rect.has_area() and stage.room.passage_route.size() >= 4, "Every course has a traversable extension after the switch")


func _boundary_breaches() -> void:
	for number in range(1, stage.ROOM.ROOM_COUNT):
		stage._load_room(number)
		stage.room.set_physics_process(false)
		await _step(2)
		var wall: StaticBody2D = stage.room.entrance_wall
		var shape: RectangleShape2D = wall.get_child(0).shape
		var rect := Rect2(wall.position - shape.size * 0.5, shape.size)
		_check(is_zero_approx(rect.position.x) and rect.size.x == 28 and stage.enemy.position.x < 0, "Room %d puts the enemy outside its enclosing wall" % number)
		var query := PhysicsRayQueryParameters2D.create(Vector2(-30, stage.room.spawn.y - 60), Vector2(40, stage.room.spawn.y - 60), 1, [stage.player.get_rid(), stage.enemy.get_rid()])
		var hit: Dictionary = stage.get_world_2d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and hit.collider == wall, "Room %d starts with a solid wall across the entrance" % number)
		stage.room.set_entrance_intact(false)
		await _step(2)
		_check(stage.get_world_2d().direct_space_state.intersect_ray(query).is_empty() and wall.collision_layer == 0, "Room %d's broken wall leaves a real opening" % number)
		query.from.y = rect.position.y - 10
		query.to.y = query.from.y
		_check(not stage.get_world_2d().direct_space_state.intersect_ray(query).is_empty(), "Room %d keeps the surrounding wall above the breach" % number)
		stage.enemy.visuals.show()
		stage.enemy.active = true
		stage.enemy._needle_cooldown = 999.0
		stage.enemy._pickup_left = 999.0
		stage.enemy.set_physics_process(true)
		for frame in 90:
			await _step()
			if stage.enemy.position.x > 55:
				break
		stage.enemy.set_physics_process(false)
		_check(stage.enemy.position.x > 55, "Room %d's enemy actually walks through the broken boundary wall" % number)
	stage.player.respawn()
	_check(stage.room.entrance_wall.visible and not stage.enemy.visuals.visible and stage._entry_left > 0.0, "A full retry restores the wall breach sequence")


func _pickup_layout_and_hint() -> void:
	for number in stage.ROOM.ROOM_COUNT:
		stage._load_room(number)
		var crystals: Array = stage.room.get_children().filter(func(child): return child.get_script() == preload("res://scripts/refill_crystal.gd"))
		var spaced := true
		for index in crystals.size():
			for other in range(index + 1, crystals.size()):
				var gap: float = crystals[index].position.distance_to(crystals[other].position)
				spaced = spaced and gap >= (240.0 if crystals[index].refill_kind == crystals[other].refill_kind else 160.0)
		_check(spaced, "Room %d separates refills so one pickup does not collect a cluster" % (number + 1))
		for box in stage.room.supplies.filter(func(supply): return supply.scene == stage.room.LIGHT):
			for umbrella in stage.room.supplies.filter(func(supply): return supply.scene == stage.room.UMBRELLA):
				_check(absf(box.at.y - umbrella.at.y) > 60.0 or absf(box.at.x - umbrella.at.x) >= 200.0, "Room %d separates box and umbrella supply choices" % (number + 1))
	await _fresh()
	for kind in ["OBJECT", "PARACHUTE"]:
		var item: Grabbable
		for child in stage.room.get_node("Items").get_children():
			if child.carry_name == kind and child.position.x > 700 and child.position.x < 1200:
				item = child
		item.freeze = true
		stage.player.position = item.position + Vector2(70 if kind == "PARACHUTE" else -70, 0)
		await _step(2)
		stage._update_grab_hint()
		_check(stage._grab_target == item and stage._grab_frame.visible and stage._grab_hint.visible, "A nearby %s is highlighted as the real pickup target" % kind)
		_check(stage._grab_hint.text == "掴む：" + ("箱" if kind == "OBJECT" else "傘"), "The pickup label identifies %s" % kind)
		Input.action_press("wall_grab")
		stage.player._update_grab_input()
		_check(stage.player.get_held_object() == item, "The grab input picks up the highlighted %s" % kind)
		stage._update_grab_hint()
		_check(not stage._grab_frame.visible and not stage._grab_hint.visible, "Holding the target hides the pickup hint")
		Input.action_release("wall_grab")
		stage.player.release_grab()
		item.queue_free()
		await _step(2)
	var object: Grabbable = stage.room.LIGHT.instantiate()
	object.position = Vector2(500, -400)
	stage.room.get_node("Items").add_child(object)
	object.freeze = true
	stage.player.position = object.position - Vector2(60, 0)
	await _step(2)
	for gravity in [1, -1, 2, -2]:
		stage.player.set_gravity_direction(gravity)
		object.rotation = gravity * 0.17
		stage._update_grab_hint()
		_check(stage._grab_target == object and stage._grab_frame.points.size() == 4, "The pickup frame works in gravity %d" % gravity)
		var corner: Vector2 = object.collider.global_transform * (-(object.collider.shape.size * 0.5 + Vector2(6, 6)))
		_check(stage._grab_frame.to_global(stage._grab_frame.points[0]).distance_to(corner) < 0.01, "The frame follows the object's rotated collider")
		_check(stage._grab_hint.position.x >= 16.0 and stage._grab_hint.position.y >= 120.0 and stage._grab_hint.get_rect().end.x <= 1264.0, "The pickup label stays inside the viewport and below the HUD")
	stage.player.stun_left = 0.2
	stage._update_grab_hint()
	_check(not stage._grab_hint.visible, "Stun hides the unusable pickup hint")
	stage.player.stun_left = 0.0
	paused = true
	stage._update_grab_hint()
	_check(not stage._grab_hint.visible, "Pausing hides the pickup hint")
	paused = false
	stage.player.controls_enabled = false
	stage._update_grab_hint()
	_check(not stage._grab_hint.visible, "Disabled controls hide the pickup hint")
	stage.player.controls_enabled = true
	stage.player.position += Vector2(300, 0)
	stage.enemy.position = object.position - Vector2(60, 0)
	await _step(2)
	stage.enemy._pickup_left = 0.0
	_check(stage.enemy.get_grab_candidate() == object, "The enemy uses the same eligible pickup query")
	stage.enemy._pickup_left = 1.0
	_check(stage.enemy.get_grab_candidate() == null and not stage.enemy.try_begin_grab(object), "The shared query preserves enemy pickup cooldown")
	stage.enemy._pickup_left = 0.0
	object.pinned_to = stage.room.entrance_wall
	stage._update_grab_hint()
	_check(not stage._grab_hint.visible and not stage.enemy.can_begin_grab(object), "Pinned platforms cannot be highlighted or picked up")
	stage._load_room(1)
	stage.room.set_physics_process(false)
	var switch_box: Grabbable = stage.room.get_node("Items").get_child(0)
	switch_box.freeze = true
	switch_box.position = stage.room.doors[0].button.position - Vector2(0, 35)
	stage.enemy.position = switch_box.position - Vector2(50, 0)
	stage.player.position = Vector2(1800, 350)
	var spare: Grabbable = stage.room.LIGHT.instantiate()
	spare.position = stage.enemy.position - Vector2(65, 0)
	stage.room.get_node("Items").add_child(spare)
	spare.freeze = true
	stage.enemy._pickup_left = 0.0
	await _step(2)
	_check(stage.room.item_on_switch(switch_box) and not stage.enemy.can_begin_grab(switch_box), "The enemy leaves the box operating the weight switch")
	_check(stage.enemy.get_grab_candidate() == spare and stage.enemy.try_begin_grab(spare), "The enemy can still choose the next eligible object")
	await _fresh()


func _fresh() -> void:
	stage._load_room(0)
	stage._intro_left = 0.0
	stage._intro_panel.hide()
	stage.player.controls_enabled = true
	stage.enemy.controls_enabled = true
	stage.room.set_physics_process(false)
	stage.player.position = Vector2(1500, 350)
	stage.enemy.position = Vector2(100, 350)
	stage._previous_player = stage.player.position
	stage._previous_enemy = stage.enemy.position
	stage._respawn_grace = 0.0
	await _step(2)


func _visible_shortcut() -> void:
	await _fresh()
	stage.enemy._has_seen = true
	stage.enemy.awareness = "pursuit"
	stage.enemy._last_seen = stage.player.position
	stage.enemy._last_gravity = 1
	stage.enemy._trail.assign([{"at": Vector2(10, 350), "gravity": 1}])
	stage.enemy._trail_index = 0
	stage.enemy._steer(1.0 / 60.0)
	_check(stage.enemy.get_movement_input().x > 0.0, "Visible level targets override a stale airborne trail even at long range")


func _impact_and_box() -> void:
	await _fresh()
	var wall: StaticBody2D = stage.room._block(Rect2(550, 100, 24, 300))
	await _step(2)
	var direction := Vector2(1, 0.3).normalized()
	var needle = _shoot(Vector2(100, 200), direction, 0)
	needle.advance(0.8, stage.player)
	_check(needle.stuck and needle.anchor == wall, "The first wall receives an angled needle")
	_check(absf(angle_difference(needle.rotation, direction.angle())) < 0.001, "Impact preserves the incoming angle")
	_check(needle.tip_position().x < wall.position.x, "Only the exposed rear tip protrudes from the terrain")
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = Vector2(120, 250)
	stage.room.get_node("Items").add_child(box)
	box.freeze = true
	await _step(2)
	var caught = _shoot(Vector2(120, 100), Vector2.DOWN, 0)
	caught.advance(0.3, stage.player)
	_check(caught.stuck and caught.anchor == box, "Flying needles stick into a box instead of disappearing")
	var relative: Vector2 = caught.position - box.position
	box.position += Vector2(80, 20)
	caught.advance(0.01, stage.player)
	_check((caught.position - box.position).is_equal_approx(relative), "An embedded needle follows its portable box")
	_check(not caught.is_dangerous() and box.pinned_to == null, "A box safely absorbs needles without becoming an immovable platform")
	var ground: StaticBody2D = stage.room._block(Rect2(300, -500, 400, 40))
	await _step(2)
	var shallow = _shoot(Vector2(320, -501), Vector2(1, 0.02), 0)
	shallow.advance(0.2, stage.player)
	_check(shallow.stuck and shallow.anchor == ground, "A shallow-angle needle reaches the floor")
	var cover: Grabbable = stage.room.LIGHT.instantiate()
	cover.position = Vector2(200, -600)
	stage.room.get_node("Items").add_child(cover)
	_check(shallow.pin_box(cover, stage.player), "A box can cover a shallow tip without intersecting the floor")
	_check(not shallow.is_dangerous() and cover.freeze, "Covering the tip creates a safe fixed platform")
	var ash = _shoot(Vector2(500, -650), Vector2.DOWN, 3)
	ash.advance(0.5, stage.player)
	_check(ash.stuck, "Ash sticks to terrain with the same impact rules")
	ash.advance(8.1, stage.player)
	_check(ash.is_queued_for_deletion(), "Uncovered brittle ash does not obstruct the course forever")


func _pin_safety() -> void:
	await _fresh()
	stage.room._block(Rect2(634, 100, 30, 300))
	await _step(2)
	var needle = _shoot(Vector2(100, 200), Vector2.RIGHT, 0)
	needle.advance(1.0, stage.player)
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = Vector2(300, 400)
	stage.room.get_node("Items").add_child(box)
	stage.player.position = needle.tip_position()
	_check(not needle.pin_box(box, stage.player) and not box.freeze, "Pinning cannot freeze a box inside the ninja and immobilize them")
	stage.player.position = Vector2(300, 400)
	stage.enemy.position = Vector2(500, 200)
	stage._previous_enemy = stage.enemy.position
	box.position = Vector2(400, 200)
	box.linear_velocity = Vector2(800, 0)
	stage._on_release(box, true, stage.player)
	box.position = Vector2(540, 200)
	stage._check_projectiles()
	_check(stage.enemy.stun_left > 0.0 and box.pinned_to == null, "A box hits the enemy before a needle farther along the same swept path")


func _hit_recovery() -> void:
	await _fresh()
	stage.player.position = Vector2(500, 350)
	stage._previous_player = stage.player.position
	stage._hit_grace = 0.0
	_shoot(Vector2(200, 350), Vector2.RIGHT, 5)
	stage._update_needles(0.8)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 2.0), "A real machine-gun hit applies one stamina damage")
	_check(stage.player.stun_left <= 0.2 and stage._hit_grace - stage.player.stun_left >= 0.5, "A hit leaves at least half a second of movement before another hit can stun")
	stage.enemy.position = stage.player.position
	stage.enemy.active = true
	stage._immunity_left = 0.0
	stage.player.stun_left = 0.0
	stage._update_capture(0.01)
	_check(stage.enemy.capture_windup < 0.0, "Projectile recovery prevents an immediate grab combo")


func _carried_shields() -> void:
	for kind in ["OBJECT", "PARACHUTE"]:
		await _fresh()
		stage.player.position = Vector2(300, 300)
		stage._previous_player = stage.player.position
		var object: Grabbable = (stage.room.LIGHT if kind == "OBJECT" else stage.room.UMBRELLA).instantiate()
		object.position = stage.player.position + Vector2(30, 0)
		stage.room.get_node("Items").add_child(object)
		await _step(2)
		_check(stage.player.try_begin_grab(object), "The shield is a genuinely carried " + kind)
		var needle = _shoot(Vector2(300, 100), Vector2.DOWN, 3)
		stage._update_needles(0.4)
		_check(needle.blocked and is_equal_approx(stage.player.get_wall_stamina(), 3.0), "A held " + kind + " intercepts rain before it reaches the ninja")
		if kind == "OBJECT":
			_check(needle.stuck and needle.anchor == object, "Held boxes visibly retain the absorbed needle")
		else:
			_check(needle.is_queued_for_deletion(), "Umbrella interception destroys the ash shard")


func _attacks() -> void:
	await _fresh()
	stage.room.visible_area = Rect2(1000, 0, 1280, 720)
	stage.enemy.active = true
	stage.enemy._update_perception(0.01)
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	_check(stage.enemy._needle_variant == 3 and stage.enemy._needle_warning > 0.0, "A distant offscreen enemy chooses a telegraphed ash cloud")
	stage.enemy._update_needle_attack(1.11)
	_check(stage.room.get_node("AshClouds").get_child_count() == 1, "The distant cloud is actually spawned")
	await _fresh()
	stage.room.attack_patterns.assign([2])
	stage.player.position = Vector2(600, 400)
	stage.enemy.active = true
	stage.enemy._update_perception(0.01)
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	stage.enemy._update_needle_attack(1.11)
	_check(stage.room.needles.get_child_count() == 6, "Homing launches six real needles simultaneously")
	await _fresh()
	stage.room.attack_patterns.assign([5])
	stage.player.position = Vector2(650, 350)
	stage.enemy.active = true
	stage.enemy._update_perception(0.01)
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	stage.enemy._update_needle_attack(0.81)
	var angles: Array[float] = []
	for i in 18:
		stage.player.position.y += 8.0
		stage.enemy._update_perception(0.0)
		stage.enemy._update_needle_attack(0.081)
		angles.append(stage.enemy._needle_aim.angle())
	_check(stage.room.needles.get_child_count() == 18, "Machine gun fire emits eighteen real short needles")
	_check(absf(angles.back() - angles.front()) > 0.08, "The burst follows observed movement instead of firing into one fixed point")
	for i in range(1, angles.size()):
		_check(absf(angle_difference(angles[i-1], angles[i])) <= 0.181, "Burst aim turns gradually and remains dodgeable")
	_check(not stage.enemy.can_capture() and stage.enemy._needle_recovery > 0.0, "A full burst leaves a real capture-free recovery")
	await _fresh()
	stage.room.attack_patterns.assign([4])
	stage.player.position = Vector2(1000, 500)
	stage.enemy.position = Vector2(100, 500)
	stage.enemy.active = true
	stage.enemy._update_perception(0.01)
	stage.enemy._needle_cooldown = 0.0
	stage.enemy._update_needle_attack(0.01)
	stage.enemy._update_needle_attack(1.11)
	_check(stage.room.needles.get_child_count() == 10, "The arcing attack launches ten long needles")
	var arc = stage.room.needles.get_child(4)
	_check(arc.velocity.y < 0.0 and arc.acceleration == Vector2(0, 1200), "Arcing needles begin upward and use actual gravity")
	arc.advance(0.8, stage.player)
	_check(arc.velocity.y > 0.0, "The same projectile curves down rather than switching to an unrelated rain spawn")


func _roof_cover() -> void:
	await _fresh()
	stage.player.position = Vector2(800, 500)
	stage._previous_player = stage.player.position
	stage.room._block(Rect2(600, 300, 500, 30))
	await _step(2)
	stage._spawn_ash_cloud(Vector2(100, 400), stage.player.position, Vector2.DOWN)
	var cloud = stage.room.get_node("AshClouds").get_child(0)
	_check(cloud.position.y < 300.0, "An intervening roof keeps the cloud outside the shelter")
	cloud.advance(1.31)
	stage._update_needles(0.6)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 3.0), "Actual roof collision stops rain before it reaches the ninja")

	await _fresh()
	stage.player.position = Vector2(1120, 500)
	stage._previous_player = stage.player.position
	stage.room._block(Rect2(1090, 200, 120, 24))
	await _step(2)
	stage._spawn_ash_cloud(Vector2(100, 400), Vector2(800, 600), Vector2.DOWN)
	cloud = stage.room.get_node("AshClouds").get_child(0)
	_check(cloud.position.y < 200.0, "A roof over a side column lifts the whole cloud even when its centre is outside the roof")
	cloud.advance(1.31)
	stage._update_needles(0.8)
	_check(is_equal_approx(stage.player.get_wall_stamina(), 3.0), "Side-column rain respects a high roof instead of appearing below it")


func _spawn_needle_lifetimes() -> void:
	await _fresh()
	for item in stage.room.get_node("Items").get_children():
		item.free()
	await _step(2)
	for kind in 6:
		var needle = _shoot(stage.room.spawn + Vector2(-100 + kind * 30, -150), Vector2.DOWN, kind)
		needle.neutral_left = 0.0
		needle.tracking_left = 0.0
		needle.velocity = Vector2.DOWN * 660
		needle.acceleration = Vector2.ZERO
		needle.advance(0.4, stage.player)
		_check(needle.stuck and needle.temporary and needle.stuck_left <= 0.6, "Every attack's exposed tip near the start gets a short lifetime: %d" % kind)
		needle.advance(0.3, stage.player)
		_check(not needle.is_queued_for_deletion() and needle.picture.modulate.a < 1.0, "The start needle fades before disappearing")
		needle.advance(0.31, stage.player)
		_check(needle.is_queued_for_deletion(), "The start needle disappears before respawn protection runs out")
	var pinned = _shoot(stage.room.spawn + Vector2(100, -150), Vector2.DOWN, 0)
	pinned.advance(0.4, stage.player)
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = stage.room.spawn - Vector2(100, 100)
	stage.room.get_node("Items").add_child(box)
	_check(pinned.pin_box(box, stage.player), "A short-lived start needle can still accept a box")
	pinned.advance(60.0, stage.player)
	_check(not pinned.is_queued_for_deletion() and box.pinned_to == pinned and box.freeze, "A box platform near the start remains intact")
	var absorbed = _shoot(box.position - Vector2(0, 150), Vector2.DOWN, 0)
	absorbed.advance(0.4, stage.player)
	absorbed.advance(60.0, stage.player)
	_check(absorbed.stuck and absorbed.anchor == box and not absorbed.is_queued_for_deletion() and not absorbed.is_dangerous(), "A box's harmless absorbed needle is preserved near the start")


func _escape_spawn() -> void:
	await _fresh()
	var needle = _shoot(stage.room.spawn - Vector2(0, 100), Vector2.DOWN, 3)
	needle.advance(0.5, stage.player)
	stage.player.position = Vector2(900, stage.room.size.y + 200)
	stage._physics_process(0.0)
	_check(not is_instance_valid(needle), "Falling clears the dangerous ash at the checkpoint immediately")
	var generation: int = stage._generation
	for frame in 60:
		stage._physics_process(1.0 / 60.0)
		await _step()
	_check(stage._generation == generation and stage.room.needles.get_child_count() == 0, "Waiting at the checkpoint does not bring back old ash or cause another retry")
	stage.player.set_physics_process(true)
	Input.action_press("move_right")
	for frame in 24:
		stage._physics_process(1.0 / 60.0)
		await _step()
	Input.action_release("move_right")
	stage.player.set_physics_process(false)
	print("SPAWN_RECOVERY generation=", stage._generation, "/", generation, " position=", stage.player.position, " spawn=", stage.room.spawn, " controls=", stage.player.controls_enabled, " grace=", stage._respawn_grace)
	_check(stage._generation == generation and stage.player.position.x > stage.room.spawn.x + 45.0, "A dangerous tip at the spawn cannot trap the ninja in an endless respawn loop")


func _shoot(at: Vector2, direction: Vector2, kind: int):
	var directions: Array[Vector2] = [direction]
	stage._spawn_needles(at, directions, kind)
	return stage.room.needles.get_child(-1)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_6_PRESSURE: " + message)
		quit(1)
		assert(condition, message)
