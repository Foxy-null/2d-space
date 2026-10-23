extends SceneTree

var stage: Node2D
var player: PlayerController
var actions := {}
var deaths := 0
var samples: Array[Vector2] = []
var screenshot_mode := false

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
	var before := deaths
	var room: Node2D = stage.rooms.get_child(section)
	var waypoint := 0
	var cooldown := 0
	var direction := 1
	var landing_first := false
	if section == 4:
		if not (player.is_on_floor() and player.position.x > room.position.x + room.walls[0].position.x):
			if not await island_leap():
				return false
		if stop_at_rest:
			return true
		waypoint = 1
	for frame in 1800:
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
		elif section == 1 and waypoint == 0:
			if player.position.y < room.walls[0].position.y - 55 and x > room.walls[0].position.x - 50:
				landing_first = true
			if landing_first and player.is_on_floor() and x > 250:
				if stop_at_rest:
					return true
				waypoint = 1
			elif landing_first:
				steer_to(290 - x)
			else:
				if player.is_dash_ready() and x > 230 and player.position.y < 480 and not player.is_on_floor():
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
				Input.action_press("move_right" if direction == 1 else "move_left")
				if player.is_on_floor() and cooldown == 0:
					Input.action_press("jump")
					cooldown = 10
		else:
			var target: Rect2 = room.walls[waypoint] if waypoint < room.walls.size() else Rect2(1200 if section == 5 else 1240, 420 if section == 5 else room.exit_top, 40, 30)
			if waypoint < room.walls.size() and player.is_on_floor() and x > target.position.x - 8 and x < target.end.x + 8 and absf(player.position.y + 26 - target.position.y) < 5:
				waypoint += 1
				target = room.walls[waypoint] if waypoint < room.walls.size() else Rect2(1200 if section == 5 else 1240, 420 if section == 5 else room.exit_top, 40, 30)
			var dx: float = target.get_center().x - x
			steer_to(dx)
			if player.is_on_floor() and cooldown == 0 and absf(dx) > 35 and not (section == 0 and waypoint == 1) and (waypoint < room.walls.size() or (section == 4 and x < room.walls[0].end.x + 20) or player.position.y + 26 > target.position.y + 5):
				if safe_launch(room, Vector2(player.velocity.x, -650), int(signf(dx)), 48 if section == 4 or (section == 1 and waypoint == 1) else 32):
					Input.action_press("jump")
					cooldown = 10
				else:
					Input.action_release("move_left")
					Input.action_release("move_right")
			elif not player.is_on_floor() and player.velocity.y > -40 and cooldown == 0 and player.get_available_extra_jump_count() > 0 and player.position.y + 26 > target.position.y - 35:
				Input.action_press("jump")
				cooldown = 12
		if screenshot_mode and frame in [70, 180]:
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-4")
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-4/room_%d%s.png" % [section + 1, "_crossing" if frame == 180 else ""])
		await step()
	return false

func steer_to(dx: float) -> void:
	var steer: float = dx * 6 - player.velocity.x * 0.5
	if absf(steer) > 20:
		Input.action_press("move_right" if steer > 0 else "move_left")

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
			var extent: Vector2 = hazard.hit_extent() + Vector2(22, 30)
			if absf(at.x - spike.x) < extent.x and absf(at.y - spike.y) < extent.y:
				return false
	return true


func island_leap(extra_delay := 20, dash_delay := 20, strength := 1.0) -> bool:
	var room: Node2D = stage.rooms.get_child(4)
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
