extends SceneTree
## Normal-input traversal with live pursuit and unmodified victory conditions.
## A numeric argument starts a room practice; no argument traverses all 13 rooms continuously.

var stage
var ticks := 0
var jumps := 0
var failures := 0
var _jump_left := 0
var _dash_left := 0
var _hold := false
var _live := false
var samples: Array[Dictionary] = []
var attack_count := 0
var _ground_run := false
var events: Array[Dictionary] = []
var _step_frames := 1
var _sample_at := 30
var _recent_launch := -100
var _record_label := "full-escape"
const OUTPUT := "res://deliverables/stage6-fatigue-update"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await process_frame
	await _step(4)
	stage = current_scene
	stage.enemy.needle_attack.connect(func(_origin, _directions, _variant): attack_count += 1)
	stage.enemy.ash_attack.connect(func(_origin, _target, _down): attack_count += 1)
	var arguments := OS.get_cmdline_user_args()
	_live = true
	var selected := -1
	for argument in arguments:
		if argument.is_valid_int():
			selected = int(argument)
	var mode := "seal" if arguments.has("--seal") else ("defeat" if arguments.has("--defeat") else "escape")
	_record_label = ("room%02d" % (selected + 1) if selected >= 0 else "full") + "-" + mode
	seed(6)
	for number in stage.ROOM.ROOM_COUNT:
		if selected >= 0 and selected != number:
			continue
		var passed := false
		var checkpoint_restarted := false
		for attempt in 16:
			if selected < 0 and stage.room_index > number:
				passed = true
				break
			_release()
			_jump_left = 0
			_dash_left = 0
			_ground_run = false
			if selected >= 0 and attempt == 0:
				stage._load_room(number)
			elif attempt > 0 and not checkpoint_restarted:
				Input.action_press("reset")
				await _step()
				Input.action_release("reset")
				await _step(3)
			checkpoint_restarted = false
			while stage._intro_left > 0.0 or stage.has_node("StageIntro"):
				await _step()
			_recent_launch = -100
			for child in stage.room.get_children():
				if child.has_signal("launched") and not child.launched.is_connected(_on_launch):
					child.launched.connect(_on_launch)
			await _step(3 + attempt * 23)
			print("TRAVERSE_BEGIN ", number + 1, " attempt=", attempt + 1)
			events.append({"time": ticks / 60.0, "room": number + 1, "attempt": attempt + 1, "event": "begin"})
			passed = await _play_room(number)
			if not passed and not is_instance_valid(stage):
				print("DEFEAT_SAMPLES ", samples.slice(maxi(0, samples.size() - 5)))
				push_error("Stage scene was unexpectedly removed in room %d" % (number + 1))
				quit(1)
				return
			if not passed:
				if stage._game_over_pending:
					events.append({"time": ticks / 60.0, "room": number + 1, "event": "checkpoint_defeat"})
					while stage._game_over_pending:
						await _step()
					checkpoint_restarted = true
				for settle in 30:
					if stage.room_index > number or stage.completed:
						passed = true
						break
					await _step()
			if passed:
				break
			failures += 1
			events.append({"time": ticks / 60.0, "room": number + 1, "event": "retry"})
		if not passed:
			push_error("Input traversal failed in room %d" % (number + 1))
			quit(1)
			return
		var previous_samples := samples.filter(func(sample): return sample.room == number + 1)
		var last: Dictionary = previous_samples.back() if not previous_samples.is_empty() else {}
		print("TRAVERSE_OK %d last=%s attacks=%d" % [number + 1, last, attack_count])
		events.append({"time": ticks / 60.0, "room": number + 1, "event": "clear"})
	var expected: String = {"escape": "逃走成功", "seal": "封じ込め成功", "defeat": "決着成功"}[mode]
	if (selected < 0 or selected == stage.ROOM.FINAL_ROOM) and (not stage.completed or stage.ending != expected):
		push_error("Expected %s, got %s" % [expected, stage.ending])
		quit(1)
		return
	print("STAGE_6_PLAYTHROUGH_OK live=%s inputs=%d jumps=%d retries=%d" % [_live, ticks, jumps, failures])
	_save_record(selected)
	_release()
	if stage.completed:
		await _step(180)
	for child in stage.room.arrival.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	current_scene.queue_free()
	await _step(3)
	OS.delay_msec(100) # Let the audio thread release the final arrival chime before shutdown.
	await _step(3)
	quit()


func _save_record(selected: int) -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var record := {"label": _record_label, "room_count": stage.ROOM.ROOM_COUNT, "frames": ticks, "jumps": jumps, "retries": failures, "ending": stage.ending, "game_over": stage._game_over_pending, "shots_fired": stage.shots_fired, "clouds_cast": stage.clouds_cast, "blocked_shots": stage.blocked_shots, "practice_start": selected + 1, "samples": samples, "events": events}
	FileAccess.open(OUTPUT + "/playthrough-" + _record_label + ".json", FileAccess.WRITE).store_string(JSON.stringify(record))

func _play_room(number: int) -> bool:
	if stage.room_index != number:
		return stage.room_index > number or stage.completed
	if number == stage.ROOM.FINAL_ROOM:
		if OS.get_cmdline_user_args().has("--seal"):
			return await _seal_boss()
		if OS.get_cmdline_user_args().has("--defeat"):
			return await _defeat_boss()
	# Solve the mandatory weight puzzles using the same carry/drop inputs.
	for door in stage.room.doors:
		if door.closes:
			continue
		var heavy: bool = door.button.required_weight > 2.0
		var supply: Vector2 = stage.room.supplies.filter(func(entry): return entry.scene == (stage.room.HEAVY if heavy else stage.room.LIGHT))[0].at
		if number == 2:
			for point: Vector2 in stage.room.route:
				if point.x > stage.player.position.x + 60 and point.x < supply.x - 50:
					if not await _navigate(point, 600):
						return false
		if not await _navigate(supply + Vector2(-30, 14), 500):
			return false
		_hold = true
		Input.action_press("wall_grab")
		await _step(4)
		if stage.player.get_held_object() == null:
			print("Pilot did not acquire a weight")
			return false
		if not stage.player.is_on_floor() and stage.player._coyote_left > 0.0:
			FullJumpInput.press(stage.player)
			await _step()
			FullJumpInput.release_after_apex(stage.player)
			_jump_left = 14
		if number == 2:
			for point: Vector2 in stage.room.route:
				if point.x > stage.player.position.x + 60 and point.x < door.button.position.x - 50:
					if not await _navigate(point, 600):
						return false
		if not await _navigate(door.button.position - Vector2(0, 26), 800):
			return false
		_release_movement()
		await _step(20)
		_hold = false
		Input.action_release("wall_grab")
		if not await _navigate(stage.player.position + Vector2(100, 0), 120):
			return false
		await _step(25)
		FullJumpInput.press(stage.player)
		await _step()
		FullJumpInput.release_after_apex(stage.player)
	if number in [1, 11] and not await _acquire("OBJECT"):
		return false
	if number in [3, 7, 8, 10, 12]:
		var kind: String = "PARACHUTE" if number in [3, 10] else "JUMP"
		if not await _acquire(kind):
			return false
	var route: Array = stage.room.route.duplicate()
	# Weight puzzles have already traversed the opening section.
	while route.size() and route[0].x < stage.player.position.x + 60 and number not in [7]:
		route.pop_front()
	for point: Vector2 in route:
		if number == 10 and point == Vector2(1170, 300) and stage.player.gravity_direction == -1:
			continue
		if number == stage.ROOM.FINAL_ROOM and point == Vector2(2860, 680):
			if not await _wait_for_block(0, 880.0):
				return false
		if number == stage.ROOM.FINAL_ROOM and point == Vector2(4020, 500):
			if not await _wait_for_block(1, 705.0):
				return false
		_ground_run = (number == 11 and point in [Vector2(1120, 910), Vector2(1450, 910)]) or (number == 0 and point == Vector2(1600, 670))
		if number == 0 and point == Vector2(1060, 620) and not await _acquire("PARACHUTE"):
			return false
		if not await _navigate(point, 1000):
			return false
		_ground_run = false
		if stage.room_index != number:
			return true
	if not await _navigate(stage.room.exit_position - Vector2(0, 118), 600):
		return false
	_release_movement()
	if number == stage.ROOM.FINAL_ROOM:
		for frame in 1800:
			if stage.completed or stage._game_over_pending:
				break
			await _step()
	await _step(45)
	if number != stage.ROOM.FINAL_ROOM and stage.room_index == number:
		for frame in 120:
			if stage.room.exit_open:
				break
			await _step()
		if not stage.room.exit_open:
			return false
		var passage: Array = stage.room.passage_route.duplicate()
		_ground_run = true
		for i in passage.size():
			if i == 2 and is_instance_valid(stage.room.extension_block):
				_release_movement()
				for frame in 360:
					var spike: SpikeBlock = stage.room.extension_block
					if spike.position.y > stage.room.exit_position.y - 100.0 and spike.position.y >= spike.previous_position.y:
						await _step(12)
						break
					await _step()
			if not await _navigate(passage[i], 900):
				return false
			if stage.room_index != number:
				return true
		_ground_run = false
		await _step(6)
	if not stage.completed and stage.room_index == number:
		print("Exit did not advance room %d at %s, gravity=%s key=%s locked=%s open=%s time=%.1f enemy=%s state=%s" % [number + 1, stage.player.position, stage.player.gravity_direction, stage.room.key_collected, stage.room.arrival.locked, stage.room.exit_open, stage.escape_elapsed, stage.enemy.position, stage.enemy.awareness])
		return false
	return true




func _acquire(kind: String) -> bool:
	for attempt in 4:
		if stage.player.get_held_object() != null:
			if stage.player.get_held_object().carry_name == kind:
				_hold = true
				return true
			_hold = false
			Input.action_release("wall_grab")
			await _step(3)
		var chosen: Grabbable
		var nearest := INF
		for item in stage.room.get_node("Items").get_children():
			if stage.room_index != stage.ROOM.FINAL_ROOM and not stage.room.exit_open and item.position.x > stage.room.passage_gate.position.x:
				continue
			if item.carry_name == kind and item.carrier == null and not (item.carry_name in ["OBJECT", "HEAVY"] and stage.room.item_on_switch(item)) and not is_instance_valid(item.pinned_to) and item.linear_velocity.length() < 160.0:
				var box_min: float = stage.room.cage.position.x - 600.0 if OS.get_cmdline_user_args().has("--seal") else 800.0
				var box_max: float = stage.room.cage.end.x + 100.0 if OS.get_cmdline_user_args().has("--seal") else 1460.0
				if kind == "OBJECT" and stage.room_index == stage.ROOM.FINAL_ROOM and (OS.get_cmdline_user_args().has("--defeat") or OS.get_cmdline_user_args().has("--seal")) and (item.position.y < 1240.0 or item.position.y > 1325.0 or item.position.x < box_min or item.position.x > box_max):
					continue
				var distance: float = stage.player.position.distance_squared_to(item.position)
				if distance < nearest:
					nearest = distance
					chosen = item
		if chosen == null:
			await _step(50)
			continue
		var travel_frames: int = maxi(600, ceili(stage.player.position.distance_to(chosen.position) / stage.player.move_speed * 60.0) + 300)
		if not await _navigate(chosen.position + Vector2(-35, 18), travel_frames):
			return false
		if stage.player.get_held_object() != null and stage.player.get_held_object().carry_name != kind:
			_hold = false
			Input.action_release("wall_grab")
			await _step(3)
		_hold = true
		Input.action_press("wall_grab")
		await _step(5)
		if stage.player.get_held_object() != null and stage.player.get_held_object().carry_name == kind:
			print("ACQUIRED ", kind)
			return true
	return false


func _wait_for_block(index: int, y: float) -> bool:
	_release_movement()
	var generation: int = stage._generation
	var spike: SpikeBlock = stage.room.spike_blocks[index]
	for frame in 360:
		if stage._generation != generation or stage._game_over_pending:
			return false
		if spike.position.y >= y and spike.position.y >= spike.previous_position.y:
			# Leave a visible 0.2-second reaction window before acting on the safe phase.
			await _step(12)
			return stage._generation == generation
		await _step()
	return false


func _throw_at(point: Vector2) -> bool:
	if stage.player.get_held_object() == null:
		return false
	_release_movement()
	var right: bool = point.x > stage.player.position.x
	_input("move_right", right)
	_input("move_left", not right)
	for frame in 18:
		if stage.player.velocity.x * (1.0 if right else -1.0) > 100.0:
			break
		await _step()
	if stage.player.get_held_object() == null:
		return false
	_hold = false
	Input.action_release("wall_grab")
	await _step()
	await _step(18)
	_release_movement()
	return stage.player.get_held_object() == null


func _defeat_boss() -> bool:
	_ground_run = true
	for attack in 24:
		if stage.completed:
			return true
		if not await _acquire("OBJECT"):
			return false
		for frame in 300:
			if stage._game_over_pending:
				return false
			var delta: Vector2 = stage.enemy.position - stage.player.position
			if absf(delta.y) < 65.0 and absf(delta.x) < 360.0 and stage.enemy.stun_left <= 0.0:
				break
			_release_movement()
			await _step()
		if not await _throw_at(stage.enemy.position):
			return false
		for frame in 130:
			if stage.completed:
				return true
			if stage._game_over_pending:
				return false
			await _step()
		print("BOSS_HITS ", stage.defeat_hits, " player=", stage.player.position, " enemy=", stage.enemy.position, " held=", stage.enemy.get_held_object() != null)
	return stage.completed


func _seal_boss() -> bool:
	_ground_run = true
	if not await _acquire("HEAVY"):
		return false
	if not await _navigate(stage.room.seal_button.position - Vector2(0, 26), 600):
		return false
	_release_movement()
	await _step(20)
	_hold = false
	Input.action_release("wall_grab")
	await _step(25)
	if not stage.room.seal_button.is_pressed() or not await _acquire("OBJECT"):
		return false
	if not await _navigate(Vector2(stage.room.cage.end.x + 70.0, 1294), 700):
		return false
	_release_movement()
	var ready := false
	for frame in 900:
		if stage._game_over_pending:
			return false
		if stage.enemy.position.x < stage.room.cage.get_center().x and stage.enemy.is_on_floor() and not stage.enemy.is_dashing() and absf(stage.enemy.position.y - stage.player.position.y) < 60.0 and stage.room.cage.encloses(Rect2(stage.enemy.position - Vector2(26, 26), Vector2(52, 52))):
			ready = true
			break
		await _step()
	if not ready:
		return false
	if not await _throw_at(stage.enemy.position):
		return false
	print("SEAL_STUN ", stage.enemy.position, " left=", stage.enemy.stun_left)
	_ground_run = false
	_jump_left = 0
	if not await _navigate(Vector2(stage.room.seal_console.x + 170, 1294), 300):
		return false
	if not await _navigate(stage.room.seal_console - Vector2(0, 26), 300, true):
		return false
	await _step(5)
	print("SEAL_RESULT ", stage.ending, " enemy=", stage.enemy.position, " player=", stage.player.position, " power=", stage.room.seal_button.is_pressed(), " floor=", stage.player.is_on_floor())
	return stage.completed

func _navigate(point: Vector2, maximum: int, strict := false) -> bool:
	var initial_room: int = stage.room_index
	var initial_gravity: int = stage.player.gravity_direction
	var underside: Node2D
	var ledge_goal := Vector2.ZERO
	var dropping := false
	var drop_edge := Vector2.ZERO
	var drop_below := 0.0
	var floor_query := PhysicsRayQueryParameters2D.create(point + stage.player.get_gravity_vector() * 5, point + stage.player.get_gravity_vector() * 80, 1, [stage.player.get_rid(), stage.enemy.get_rid()])
	var require_floor: bool = not stage.player.get_world_2d().direct_space_state.intersect_ray(floor_query).is_empty()
	for frame in maximum:
		if not is_instance_valid(stage) or stage._game_over_pending:
			return false
		if stage.completed:
			return true
		if stage.room_index != stage.ROOM.FINAL_ROOM and stage.room.exit_open and point.distance_to(stage.room.exit_position) < 200.0:
			_release_movement()
			return true
		var actor: PlayerController = stage.player
		var delta := point - actor.position
		if actor.gravity_direction != initial_gravity and delta.length() < 220.0:
			_release_movement()
			return true
		var floating := actor.get_held_object() != null and is_finite(actor.get_held_object().fall_speed_limit()) and not actor._winds.is_empty()
		var reached := (delta.length() < 38.0 and (not require_floor or actor.is_on_floor())) or (delta.length() < 70.0 and actor._impact_frame >= Engine.get_physics_frames() - 3) or (actor.is_on_floor() and absf(delta.dot(actor.get_walk_axis())) < 35.0 and delta.dot(actor.get_gravity_vector()) > 0.0 and delta.dot(actor.get_gravity_vector()) < 100.0) or (floating and absf(delta.dot(actor.get_walk_axis())) < 55.0 and delta.dot(actor.get_gravity_vector()) > -40.0)
		if Engine.get_physics_frames() - _recent_launch <= 8 and delta.length() < 130.0:
			reached = true
		if strict:
			reached = actor.is_on_floor() and absf(delta.dot(actor.get_walk_axis())) < 18.0 and absf(delta.dot(actor.get_gravity_vector())) < 20.0
		if reached:
			_release_movement()
			return true
		var tangent := actor.get_walk_axis()
		var down := actor.get_gravity_vector()
		if is_instance_valid(underside):
			if not underside.visible or actor.position.dot(down) <= ledge_goal.dot(down) + 2.0:
				underside = null
			else:
				delta = ledge_goal - actor.position
		var climbing := delta.dot(down) < -18.0 or (actor.is_on_wall() and delta.dot(down) < 30.0 and absf(delta.dot(tangent)) > 26.0)
		if climbing and actor.is_on_ceiling():
			for index in actor.get_slide_collision_count():
				var contact := actor.get_slide_collision(index)
				var body := contact.get_collider() as Node2D
				if body == null or contact.get_normal().dot(down) < 0.7:
					continue
				var shapes := body.get_children().filter(func(node): return node is CollisionShape2D)
				if shapes.is_empty():
					continue
				var collision: CollisionShape2D = shapes[0]
				if not collision.shape is RectangleShape2D:
					continue
				var half: Vector2 = collision.shape.size * 0.5
				var extent := collision.global_transform.x.abs() * half.x + collision.global_transform.y.abs() * half.y
				var side := signf((actor.position - body.global_position).dot(tangent))
				if side == 0.0: side = 1.0
				underside = body
				ledge_goal = body.global_position + tangent * side * (extent.dot(tangent.abs()) + 50.0) - down * (extent.dot(down.abs()) + 30.0)
				delta = ledge_goal - actor.position
				break
		var along := delta.dot(tangent)
		# Walk off an elevated support before trying to reach a waypoint below it.
		if not dropping and actor.is_on_floor() and absf(along) < 45.0 and delta.dot(down) > 100.0:
			for index in actor.get_slide_collision_count():
				var contact := actor.get_slide_collision(index)
				var body := contact.get_collider() as Node2D
				if body == null or contact.get_normal().dot(-down) < 0.7:
					continue
				var shapes := body.get_children().filter(func(node): return node is CollisionShape2D)
				if shapes.is_empty():
					continue
				var collision: CollisionShape2D = shapes[0]
				if not collision.shape is RectangleShape2D:
					continue
				var half: Vector2 = collision.shape.size * 0.5
				var extent := collision.global_transform.x.abs() * half.x + collision.global_transform.y.abs() * half.y
				var side := signf((actor.position - body.global_position).dot(tangent))
				if side == 0.0: side = 1.0
				drop_edge = body.global_position + tangent * side * (extent.dot(tangent.abs()) + 48.0)
				drop_below = body.global_position.dot(down) + extent.dot(down.abs()) + 38.0
				dropping = true
				break
		if dropping:
			if actor.position.dot(down) > drop_below:
				dropping = false
			else:
				along = (drop_edge - actor.position).dot(tangent)
				climbing = false
		var danger: bool = stage.room.hazard_ahead(actor, along)
		for needle in stage.room.needles.get_children():
			if not needle.stuck or not needle.is_dangerous():
				continue
			var ahead: Vector2 = needle.tip_position() - actor.position
			if ahead.dot(tangent) * signf(along) > 20.0 and ahead.dot(tangent) * signf(along) < 120.0 and absf(ahead.dot(down)) < 65.0:
				danger = true
				break
		var enemy_delta: Vector2 = stage.enemy.position - actor.position
		var close_enemy: bool = stage.enemy.active and enemy_delta.dot(tangent) * along > 0.0 and absf(enemy_delta.dot(tangent)) < 170.0 and absf(enemy_delta.dot(down)) < 90.0
		var rising_target := climbing and absf(along) < 210.0
		var movement := tangent * signf(along) if absf(along) > 12.0 else Vector2.ZERO
		_jump_left -= _step_frames
		_dash_left -= _step_frames
		var jump := false
		var dash := false
		var grab := _hold
		if actor.is_on_wall() and climbing and not _hold:
			grab = true
			movement -= down
		if not dropping and _jump_left <= 0 and (((actor.is_on_floor() or actor._coyote_left > 0.0) and (rising_target or danger or close_enemy or (absf(along) > 180 and not _ground_run) or (_ground_run and actor.is_on_wall()))) or (actor.is_on_wall() and climbing and _hold) or (not actor.is_on_floor() and (climbing or danger) and actor.velocity.dot(down) > -50 and actor.get_available_extra_jump_count() > 0)):
			jump = true
			jumps += 1
			_jump_left = 14
		if not dropping and not jump and _dash_left <= 0 and actor.is_dash_ready() and not actor.is_on_floor() and (not _ground_run or climbing) and actor.velocity.dot(down) > (-350.0 if danger else -150.0) and (climbing or danger or absf(along) > 260):
			dash = true
			movement = (-down if climbing and absf(along) < 70.0 else (tangent * signf(along) - down).normalized()) if danger else (delta.normalized() if climbing else tangent * signf(along))
			_dash_left = 20
		# The hanging wall has a walking gap underneath; jumping presses into its side.
		if initial_room == 11 and point == Vector2(1450, 910) and actor.position.x > 1060 and actor.position.x < 1360:
			jump = false
			dash = false
			movement = Vector2.RIGHT
		_input("move_left", movement.x < -0.1)
		_input("move_right", movement.x > 0.1)
		_input("move_up", movement.y < -0.1)
		_input("move_down", movement.y > 0.1)
		_input("jump", jump)
		_input("dash", dash)
		_input("wall_grab", grab)
		var previous_position := actor.position
		var generation: int = stage._generation
		await _step()
		if stage.room_index != initial_room:
			return true
		if stage._generation != generation:
			print("PILOT_RETRY from=", previous_position, " target=", point)
			for needle in stage.room.needles.get_children():
				if needle.stuck and needle.tip_position().distance_to(previous_position) < 110.0:
					print("NEARBY_TIP ", needle.tip_position(), " variant=", needle.variant)
			return false
		if frame > 0 and frame % 240 == 0:
			print("PILOT ", stage.room_index + 1, " target=", point, " pos=", actor.position, " gravity=", actor.gravity_direction, " held=", actor.get_held_object() != null, " weights=", stage.room.doors.map(func(entry): return entry.button.total_weight))
	print("Pilot stalled in room %d: target=%s position=%s gravity=%d" % [stage.room_index + 1, point, stage.player.position, stage.player.gravity_direction])
	return false

func _on_launch(body: Node) -> void:
	if body == stage.player:
		_recent_launch = Engine.get_physics_frames()


func _input(action: StringName, pressed: bool) -> void:
	if pressed:
		FullJumpInput.press_action(action, stage.player)
	elif action != &"jump" or not FullJumpInput.is_holding():
		Input.action_release(action)

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash"]:
		Input.action_release(action)

func _release() -> void:
	_release_movement()
	Input.action_release("wall_grab")
	_hold = false

func _step(count := 1) -> void:
	var began := Engine.get_physics_frames()
	var previous := began
	while Engine.get_physics_frames() - began < count:
		await physics_frame
		await process_frame
		var current := Engine.get_physics_frames()
		ticks += current - previous
		previous = current
		if ticks >= _sample_at and is_instance_valid(stage) and is_instance_valid(stage.player):
			_sample_at += 30
			samples.append({"time": ticks / 60.0, "room": stage.room_index + 1, "player": [stage.player.position.x, stage.player.position.y], "enemy": [stage.enemy.position.x, stage.enemy.position.y], "distance": stage.player.position.distance_to(stage.enemy.position), "awareness": stage.enemy.awareness, "attacks": attack_count, "stamina": stage.player.get_wall_stamina(), "ending": stage.ending})
	_step_frames = Engine.get_physics_frames() - began
