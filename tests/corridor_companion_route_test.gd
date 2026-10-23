extends "res://tests/stage_4_playthrough.gd"

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_4.tscn")
	await step(5)
	stage = current_scene
	player = stage.player
	player.respawned.connect(func(): deaths += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action, 0) + 1)
	var room: Node2D = stage.rooms.get_child(0)
	for wait in [0, 15, 30, 45]:
		release()
		player.respawn()
		await step(5 + wait)
		deaths = 0
		actions.clear()
		var started := Engine.get_physics_frames()
		var arrived := await traverse(0)
		release()
		_check(arrived and stage.room_index == 1 and deaths == 1, "The live first room is reachable without dying from several initial patrol phases")
		_check(actions.get("creature_jump", 0) > 0 and actions.get("dash", 0) > 0, "The high landing combines the companion with dash")
		var seconds := (Engine.get_physics_frames() - started) / 60.0
		_check(seconds < 30.0, "The checkpoint remains less than thirty seconds away")
		print("CORRIDOR_COMPANION_CROSSING %.2fs wait=%d" % [seconds, wait])
		await step(25)
		stage.room_index = 0
		stage._set_checkpoint()
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	for hazard in room.get_node("Hazards").get_children():
		if not hazard.ceiling_strip:
			hazard.set_physics_process(false)
	for launch_x in [55, 190, 220, 250]:
		for delay in [0, 12, 24, 36, 48, 60]:
			for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]:
				release()
				player.respawn()
				await step(5)
				Input.action_press("wall_grab")
				await step(2)
				_check(player.get_held_object() == creature, "Each trial starts with the actual companion held")
				Input.action_press("move_left" if launch_x < 110 else "move_right")
				for frame in 80:
					if (player.position.x <= launch_x if launch_x < 110 else player.position.x >= launch_x):
						break
					await step()
				deaths = 0
				actions.clear()
				Input.action_press("jump")
				await step()
				Input.action_release("jump")
				var landed_high := false
				for frame in 300:
					creature.consume_extra_jump()
					for action in ["move_left", "move_up", "move_down", "dash", "jump"]:
						Input.action_release(action)
					Input.action_press("move_right")
					if player.is_on_wall() and frame % 12 == 0:
						Input.action_press("jump")
					if frame == delay and not direction.is_zero_approx():
						Input.action_release("move_right")
						if direction.x != 0:
							Input.action_press("move_right" if direction.x > 0 else "move_left")
						if direction.y != 0:
							Input.action_press("move_down" if direction.y > 0 else "move_up")
						Input.action_press("dash")
					await step()
					landed_high = landed_high or (player.is_on_floor() and absf(player.position.y + 26 - room.walls[0].position.y) < 5)
					if deaths > 0 or stage.room_index != 0:
						break
				_check(not landed_high and stage.room_index == 0, "Without an extra jump, jump/dash/wall attempts cannot reach the high landing: x%d delay%d %s" % [launch_x, delay, direction])
				_check(not actions.has("creature_jump"), "The negative trial received no additional jump")
	release()
	player.respawn()
	await step(5)
	_check(player.position.distance_to(Vector2(110, 594)) < 2 and player.is_dash_ready() and creature.extra_jump_count() == 1 and player.get_held_object() == null, "Retry restores the safe entrance, creature and abilities")
	print("CORRIDOR_COMPANION_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("CORRIDOR_COMPANION: " + message)
		quit(1)
