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

func release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "wall_grab", "jump", "dash"]:
		Input.action_release(action)

func traverse(section: int) -> bool:
	var before := deaths
	var room: Node2D = stage.rooms.get_child(section)
	var direction := 1
	var cooldown := 0
	var crest := false
	var landing_first := false
	var waypoint := 0
	for frame in 1200:
		release()
		if stage.room_index != section or stage.completed:
			return true
		if deaths != before:
			return false
		samples.append(player.global_position)
		var x: float = player.position.x - section * 1280
		if section in [2, 5]:
			Input.action_press("wall_grab")
			if player.get_held_object() == null and x < 240:
				Input.action_press("move_right")
				await step()
				continue
		cooldown = maxi(0, cooldown - 1)
		if not crest and player.position.y < room.walls[0].position.y - 55 and x > 220:
			landing_first = true
		if not crest and landing_first and player.is_on_floor() and x > 250:
			crest = true
			waypoint = 1
		if not crest:
			if landing_first:
				var difference: float = 290 - x
				var steer: float = difference * 6 - player.velocity.x * 0.5
				if absf(steer) > 20:
					Input.action_press("move_right" if steer > 0 else "move_left")
			elif player.is_on_wall() and cooldown == 0:
				var kick_direction := int(player.get_wall_normal().x)
				if safe_launch(room, Vector2(kick_direction * 720, -560), kick_direction, 24):
					direction = kick_direction
					Input.action_press("jump")
					cooldown = 10
				else:
					direction = -kick_direction
					if section not in [2, 5]:
						Input.action_press("wall_grab")
						Input.action_press("move_up")
			if not landing_first:
				Input.action_press("move_right" if direction == 1 else "move_left")
			if player.is_on_floor() and cooldown == 0:
				Input.action_press("jump")
				cooldown = 10
		else:
			var target_x: float = room.walls[waypoint].get_center().x if waypoint < 4 else (1220 if section == 5 else 1270)
			if waypoint < 4 and player.is_on_floor() and absf(x - target_x) < 42 and absf(player.position.y + 26 - room.walls[waypoint].position.y) < 5:
				waypoint += 1
				target_x = room.walls[waypoint].get_center().x if waypoint < 4 else (1220 if section == 5 else 1270)
			var steer: float = (target_x - x) * 6 - player.velocity.x * 0.5
			if absf(steer) > 20:
				Input.action_press("move_right" if steer > 0 else "move_left")
			if player.is_on_floor() and cooldown == 0 and waypoint < 4 and target_x > x + 45:
				if safe_launch(room, Vector2(player.velocity.x, -650), 1, 45):
					Input.action_press("jump")
					cooldown = 10
				else:
					Input.action_release("move_right")
					Input.action_release("move_left")
			elif waypoint < 4 and player.velocity.y > -10 and player.position.y + 26 > room.walls[waypoint].position.y - 4 and player.get_available_extra_jump_count() > 0 and cooldown == 0:
				Input.action_press("jump")
				cooldown = 14
			elif section not in [2, 5] and player.is_on_wall():
				Input.action_press("wall_grab")
				Input.action_press("move_up")
		if screenshot_mode and frame in [70, 310]:
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-4")
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-4/room_%d%s.png" % [section + 1, "_crossing" if frame == 310 else ""])
		await step()
	return false


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
			if absf(at.x - spike.x) < 18 + hazard.half_size + 4 and absf(at.y - spike.y) < 26 + hazard.half_size + 4:
				return false
	return true
