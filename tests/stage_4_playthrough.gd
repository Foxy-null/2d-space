extends SceneTree

var stage: Node2D
var player: PlayerController
var actions := {}
var deaths := 0
var samples: Array[Vector2] = []
var screenshot_mode := false
var steering_strength := 1.0

func step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if is_instance_valid(player):
			samples.append(player.global_position)

func release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "wall_grab", "jump", "dash"]:
		Input.action_release(action)

func traverse(section: int, stop_at_rest := false) -> bool:
	if section >= 9:
		return await traverse_more(section, stop_at_rest)
	var before := deaths
	var room: Node2D = stage.rooms.get_child(section)
	var waypoint := 0
	var cooldown := 0
	var direction := 1
	var landing_first := false
	if section in [1, 7] and player.is_on_floor() and absf(player.position.y + 26 - room.walls[0].position.y) < 5 and player.position.x - room.position.x > room.walls[0].position.x:
		waypoint = 1
	if section in [4, 8]:
		if not (player.is_on_floor() and player.position.x > room.position.x + room.walls[0].position.x):
			if not await island_leap(20, 20, steering_strength, section):
				return false
		if stop_at_rest:
			return true
		waypoint = 1
	for frame in 1800:
		if section >= 6 and OS.get_cmdline_user_args().has("--trace") and frame % 30 == 0:
			print("EXPANSION room=%d frame=%d waypoint=%d pos=%s velocity=%s actions=%s" % [section+1, frame, waypoint, player.position - room.position, player.velocity, actions])
		release()
		if stage.room_index != section or stage.completed:
			return true
		if deaths != before:
			return false
		var x: float = player.position.x - section * 1280
		Input.action_press("wall_grab")
		if player.get_held_object() == null:
			if x >= 240:
				return false
			Input.action_press("move_right")
			await step()
			continue
		if player.is_wall_grabbing():
			return false
		cooldown = maxi(0, cooldown - 1)
		if section == 0 and waypoint == 0:
			var first: Rect2 = room.walls[0]
			if player.is_on_floor() and x > first.position.x and absf(player.position.y + 26 - first.position.y) < 5:
				waypoint = 1
			elif player.is_on_floor():
				steer_to(190 - x)
				if x > 180:
					Input.action_press("jump")
					cooldown = 10
			else:
				steer_to(450 - x)
				if cooldown == 0 and player.velocity.y > -40:
					if player.get_available_extra_jump_count() > 0:
						Input.action_press("jump")
						cooldown = 10
					elif player.is_dash_ready():
						Input.action_release("move_right")
						Input.action_release("move_left")
						Input.action_press("move_up")
						Input.action_press("dash")
		elif section in [1, 7] and waypoint == 0:
			if player.position.y < room.walls[0].position.y - 55 and x > room.walls[0].position.x - 50:
				landing_first = true
			if landing_first and player.is_on_floor() and x > 250:
				if stop_at_rest:
					return true
				waypoint = 1
			elif landing_first:
				steer_to(290 - x)
			else:
				if player.is_dash_ready() and x > 230 and player.position.y < room.walls[0].position.y + 180 and not player.is_on_floor():
					Input.action_release("move_right")
					Input.action_release("move_left")
					Input.action_press("move_up")
					Input.action_press("dash")
					await step()
					continue
				if player.is_on_wall() and cooldown == 0:
					var kick := int(player.get_wall_normal().x)
					if safe_launch(room, Vector2(kick * 720, -560), kick, 24):
						direction = kick
						Input.action_press("jump")
						cooldown = 10
					else:
						direction = -kick
				Input.action_press("move_right" if direction == 1 else "move_left", steering_strength)
				if player.is_on_floor() and cooldown == 0:
					Input.action_press("jump")
					cooldown = 10
		else:
			var target: Rect2 = room.walls[waypoint] if waypoint < room.walls.size() else Rect2(1200 if section == stage.rooms.get_child_count() - 1 else 1250, 420 if section == stage.rooms.get_child_count() - 1 else room.exit_top, 40, 30)
			if waypoint < room.walls.size() and player.is_on_floor() and x > target.position.x - 8 and x < target.end.x + 8 and absf(player.position.y + 26 - target.position.y) < 5:
				waypoint += 1
				if stop_at_rest and waypoint == 1:
					return true
				target = room.walls[waypoint] if waypoint < room.walls.size() else Rect2(1200 if section == stage.rooms.get_child_count() - 1 else 1250, 420 if section == stage.rooms.get_child_count() - 1 else room.exit_top, 40, 30)
			var dx: float = target.get_center().x - x
			steer_to(dx)
			var exiting: bool = waypoint >= room.walls.size() and section < stage.rooms.get_child_count() - 1 and x > 1200
			if not exiting and player.is_on_floor() and cooldown == 0 and absf(dx) > 35 and not (section == 0 and waypoint == 1) and (waypoint < room.walls.size() or (section == 4 and x < room.walls[0].end.x + 20) or player.position.y + 26 > target.position.y + 5):
				if safe_launch(room, Vector2(player.velocity.x, -650), int(signf(dx)), 48 if section == 4 or (section == 1 and waypoint == 1) else 32):
					Input.action_press("jump")
					cooldown = 10
				else:
					Input.action_release("move_left")
					Input.action_release("move_right")
			elif not exiting and not player.is_on_floor() and player.velocity.y > -40 and cooldown == 0 and player.get_available_extra_jump_count() > 0 and (player.position.y + 26 > target.position.y - 35 or (section == 7 and waypoint == 3)):
				Input.action_press("jump")
				cooldown = 12
			elif section == 6 and not player.is_on_floor() and player.velocity.y > -40 and cooldown == 0 and player.is_dash_ready() and player.position.y + 26 > target.position.y + 200:
				Input.action_release("move_right")
				Input.action_release("move_left")
				Input.action_press("move_up")
				Input.action_press("dash")
		if screenshot_mode and frame in [70, 180]:
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-4")
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-4/room_%d%s.png" % [section + 1, "_crossing" if frame == 180 else ""])
		await step()
	return false

func steer_to(dx: float) -> void:
	var steer: float = dx * 6 - player.velocity.x * 0.5
	if absf(steer) > 20:
		Input.action_press("move_right" if steer > 0 else "move_left", steering_strength)

func safe_launch(room: Node2D, velocity: Vector2, direction: int, frames: int) -> bool:
	var at := player.global_position
	for frame in frames:
		if frame > 0:
			velocity.x = move_toward(velocity.x, direction * 360.0, 1700.0 / 60)
			velocity.y += 1900.0 / 60
		at += velocity / 60
		for hazard in room.get_node("Hazards").get_children():
			var progress: float = (1.0 - cos(TAU * ((hazard.elapsed + (frame + 1.0) / 60) / hazard.period + hazard.phase))) * 0.5
			var spike: Vector2 = room.position + hazard.origin + hazard.travel * progress
			var local_extent: Vector2 = hazard.hit_extent()
			var extent: Vector2 = hazard.transform.x.abs() * local_extent.x + hazard.transform.y.abs() * local_extent.y + Vector2(22, 30)
			if absf(at.x - spike.x) < extent.x and absf(at.y - spike.y) < extent.y:
				return false
	return true


func island_leap(extra_delay := 20, dash_delay := 20, strength := 1.0, section := 4) -> bool:
	var room: Node2D = stage.rooms.get_child(section)
	var before := deaths
	Input.action_press("wall_grab")
	Input.action_press("move_right", strength)
	for frame in 120:
		if player.position.x >= room.position.x + 225:
			break
		if not await _island_step(1, before): return false
	Input.action_press("jump")
	if not await _island_step(1, before): return false
	Input.action_release("jump")
	if not await _island_step(extra_delay, before): return false
	Input.action_press("jump")
	if not await _island_step(1, before): return false
	Input.action_release("jump")
	if not await _island_step(dash_delay, before): return false
	Input.action_release("move_right")
	Input.action_press("move_up", strength)
	Input.action_press("dash")
	if not await _island_step(1, before): return false
	Input.action_release("dash")
	Input.action_release("move_up")
	Input.action_press("move_right", strength)
	for frame in 180:
		if deaths != before:
			return false
		if player.position.x > room.position.x + room.walls[0].position.x and not player.is_on_floor():
			Input.action_release("move_right")
		elif player.is_on_floor():
			Input.action_press("move_right", strength)
		if player.is_on_floor() and player.position.x > room.position.x + room.walls[0].get_center().x:
			Input.action_release("move_right")
			if not await _island_step(20, before): return false
			return deaths == before
		if not await _island_step(1, before): return false
	return false


func _island_step(count: int, before: int) -> bool:
	for frame in count:
		await step()
		if deaths != before:
			release()
			return false
	return true


func traverse_more(section: int, stop_at_rest := false, gap := 20) -> bool:
	var room: Node2D = stage.rooms.get_child(section)
	var before := deaths
	var waypoint := 0
	for index in room.walls.size():
		if _on_more_rest(room.walls[index]): waypoint = index + 1
	if waypoint == 0:
		if not await more_walk(185): return false
		if section == 9:
			if not await more_combo(430, room.walls[0], gap): return false
		elif section == 10:
			if not await more_gravity(room): return false
			waypoint = 2
		elif section == 11:
			for frame in 120:
				more_drive(205 - _more_x())
				await step()
				if not player.is_on_floor() and player.velocity.y < -800: break
			if not await more_flight(room.walls[0]): return false
		elif section == 12:
			if not await island_leap(gap, gap, steering_strength, section): return false
		elif section == 13:
			if not await more_shaft(room): return false
		else:
			if not await more_transfer(room.walls[0]): return false
		if deaths != before: return false
		if waypoint == 0: waypoint = 1
		if stop_at_rest: return true
	if section == 12 and waypoint == 1:
		if not await more_combo(930, room.walls[1], gap): return false
		waypoint = 2
	for index in range(waypoint, room.walls.size()):
		if not await more_transfer(room.walls[index]): return false
	var target := Rect2(1180 if section == 14 else 1250, room.exit_top - (80 if section == 14 else 0), 45, 24)
	if not await more_transfer(target, true): return false
	return deaths == before + (0 if section == 14 else 1)


func more_drive(dx: float) -> void:
	release()
	Input.action_press("wall_grab")
	steer_to(dx)


func _more_x() -> float:
	return player.position.x - stage.room_index * 1280


func _on_more_rest(rect: Rect2) -> bool:
	return player.is_on_floor() and _more_x() >= rect.position.x - 8 and _more_x() <= rect.end.x + 8 and absf(player.position.y + 26 - rect.position.y) < 5


func more_walk(target: float) -> bool:
	var before := deaths
	for frame in 240:
		more_drive(target - _more_x())
		await step()
		if deaths != before: return false
		if absf(target - _more_x()) < 5 and absf(player.velocity.x) < 25:
			return player.get_held_object() != null
	return false


func more_jump() -> void:
	Input.action_press("jump")
	await step()
	Input.action_release("jump")


func more_combo(launch: float, target: Rect2, gap: int, boot_gap: int = -1, dash_gap: int = -1) -> bool:
	if not await more_walk(launch): return false
	more_drive(0)
	await more_jump()
	await step(gap)
	await more_jump()
	await step(gap if boot_gap < 0 else boot_gap)
	if not player.is_air_jump_ready():
		print("MORE_COMBO_BOOT_MISSING ",stage.room_index+1, " ",Vector2(_more_x(),player.position.y))
		return false
	more_drive(target.get_center().x - _more_x())
	await more_jump()
	await step(gap if dash_gap < 0 else dash_gap)
	release()
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	Input.action_press("dash")
	await step()
	Input.action_release("dash")
	return await more_flight(target, false)


func more_transfer(target: Rect2, finishing := false) -> bool:
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		if contact.get_normal().dot(Vector2.UP) < 0.8: continue
		var floor_body := contact.get_collider() as StaticBody2D
		if floor_body == null: continue
		var shape: CollisionShape2D = floor_body.get_node("Collision")
		var bounds: Rect2 = shape.shape.get_rect()
		var start: float = shape.to_global(bounds.position).x - stage.room_index * 1280
		var end: float = shape.to_global(bounds.end).x - stage.room_index * 1280
		if absf(target.get_center().x - _more_x()) > 200:
			if not await more_walk(clampf(target.get_center().x, start + 30, end - 30)): return false
		break
	more_drive(target.get_center().x - _more_x())
	await more_jump()
	return await more_flight(target, true, finishing)


func more_flight(target: Rect2, allow_actions := true, finishing := false) -> bool:
	var section: int = stage.room_index
	var before := deaths
	var cooldown := 10
	for frame in 600:
		if OS.get_cmdline_user_args().has("--trace") and frame % 15 == 0:
			print("MORE_FLIGHT room=",section+1," frame=",frame," pos=",Vector2(_more_x(),player.position.y)," velocity=",player.velocity," target=",target," deaths=",deaths-before)
		if stage.room_index != section or stage.completed: return finishing
		if deaths != before: return false
		if not finishing and _on_more_rest(target):
			more_drive(0)
			await step(12)
			return deaths == before
		var dx := target.get_center().x - _more_x()
		more_drive(dx)
		cooldown = maxi(cooldown - 1, 0)
		if allow_actions and not player.is_on_floor() and player.velocity.y > -40 and cooldown == 0:
			if player.get_available_extra_jump_count() > 0 and (player.position.y + 26 > target.position.y - 35 or absf(dx) > 180):
				Input.action_press("jump")
				cooldown = 12
			elif player.is_dash_ready() and player.position.y + 26 > target.position.y + 50:
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press("move_up")
				if absf(dx) > 220: Input.action_press("move_right" if dx > 0 else "move_left", steering_strength)
				Input.action_press("dash")
				cooldown = 12
		await step()
	return false


func more_inverted_rest() -> bool:
	var before := deaths
	more_drive(300 - _more_x())
	await more_jump()
	for frame in 300:
		more_drive(470 - _more_x())
		await step()
		if deaths != before: return false
		if player.gravity_direction == -1 and player.is_on_floor(): break
	if player.gravity_direction != -1 or not player.is_on_floor(): return false
	return true


func more_gravity(room: Node2D) -> bool:
	var before := deaths
	if not await more_inverted_rest(): return false
	more_drive(0)
	await step(180)
	await _more_capture("room11_inverted_rest")
	if not await more_walk(330): return false
	more_drive(220 - _more_x())
	await more_jump()
	for frame in 240:
		more_drive(220 - _more_x())
		await step()
		if deaths != before: return false
		if player.gravity_direction == 1: break
	if player.gravity_direction != 1: return false
	return await more_flight(room.walls[1], false)


func more_shaft(room: Node2D) -> bool:
	var before := deaths
	var cooldown := 0
	var direction := 1
	for frame in 1500:
		release()
		Input.action_press("wall_grab")
		if deaths != before: return false
		if _on_more_rest(room.walls[0]): return true
		if player.position.y < room.walls[0].position.y - 55:
			steer_to(310 - _more_x())
		else:
			cooldown = maxi(0, cooldown - 1)
			if player.is_on_wall() and cooldown == 0:
				direction = int(player.get_wall_normal().x)
				Input.action_press("jump")
				cooldown = 10
			Input.action_press("move_right" if direction == 1 else "move_left", steering_strength)
			if player.is_on_floor() and cooldown == 0:
				Input.action_press("jump")
				cooldown = 10
			elif player.is_dash_ready() and _more_x() > 230 and player.position.y < room.walls[0].position.y + 180:
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press("move_up")
				Input.action_press("dash")
		await step()
	return false


func _more_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-more")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/corridor-more/%s.png"%label)
