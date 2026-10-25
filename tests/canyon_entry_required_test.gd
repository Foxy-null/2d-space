extends "res://tests/canyon_entry_route_test.gd"

const ENTRY_AIMS := [Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1)]
const ENTRY_GROUPS := [["spring", 24], ["spring", 25], ["bumpers", 24], ["bumpers", 25], ["bumpers", 26], ["parachute", 26], ["updraft", 26], ["step", 26]]

var entry_trials := 0
var entry_supports := 0
var entry_relaunches := 0


func _run() -> void:
	monitor_view = false
	var selected := ""
	var selected_room := 0
	var seen := {}
	for argument in OS.get_cmdline_user_args():
		var key := argument.get_slice("=", 0)
		if seen.has(key):
			_entry_argument_error("Duplicate argument: " + argument)
			return
		seen[key] = true
		if argument.begins_with("--only="):
			selected = argument.trim_prefix("--only=")
			if selected not in ["spring", "bumpers", "parachute", "updraft", "step"]:
				_entry_argument_error("Unknown omission group: " + selected)
				return
		elif argument.begins_with("--room="):
			var value := argument.trim_prefix("--room=")
			if not value.is_valid_int() or int(value) not in [25, 26, 27]:
				_entry_argument_error("Expected --room=25, 26 or 27: " + argument)
				return
			selected_room = int(value)
		else:
			_entry_argument_error("Unknown argument: " + argument)
			return
	var groups := ENTRY_GROUPS.filter(func(group): return (selected.is_empty() or group[0] == selected) and (selected_room == 0 or group[1] + 1 == selected_room))
	if groups.is_empty():
		_entry_argument_error("The selected room has no such omission group")
		return
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	for group in groups:
		if group[0] != "step":
			await _entry_trial(group[0], group[1], Vector2.ZERO, 0)
			if failed: return
		for delay in [16, 24]:
			for aim in ENTRY_AIMS:
				await _entry_trial(group[0], group[1], aim, delay)
				if failed: return
		print("CANYON_ENTRY_REQUIRED_GROUP ", group[0], " room=", group[1] + 1)
	_release_inputs()
	Input.action_release("wall_grab")
	current_scene.queue_free()
	await _step(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_ENTRY_REQUIRED_TEST_OK (%d checks, %d routes, %d actual supports, %d actual rest jumps)" % [checks, entry_trials, entry_supports, entry_relaunches])
	quit()


func _entry_argument_error(message: String) -> void:
	push_error(message)
	quit(1)


func _entry_trial(kind: String, index: int, aim: Vector2, delay: int) -> void:
	await _setup(index)
	monitor_view = false
	var room: Node2D = stage.rooms.get_child(index)
	var spring_launches := [0]
	if kind == "spring":
		var spring: Area2D = room.get_node("Items/Spring")
		spring.launched.connect(func(_body): spring_launches[0] += 1)
		spring.monitoring = false
	elif kind == "bumpers":
		for bumper in stage._bumpers().get_children(): bumper.monitoring = false
	elif kind == "parachute":
		room.get_node("Items/Parachute").queue_free()
	elif kind in ["updraft", "step"]:
		room.get_node("Winds/Updraft").wind_acceleration = 0
	await _step(2)
	var before := respawns
	if kind == "bumpers":
		await _entry_begin()
	elif kind == "step":
		var object := await _entry_real_support()
		if failed: return
		Input.action_press("wall_grab")
		await _pulse("jump")
		_check(player.get_held_object() == object and player.velocity.y < -100, "The same native support is picked up during the real jump")
	elif kind == "updraft":
		Input.action_press("wall_grab")
		await _step()
		_check(player.get_held_object() == room.get_node("Items/Parachute"), "The wind omission retains the actual held parachute")
		await _entry_walk_edge()
	else:
		await _entry_walk_edge()
	if failed: return
	_check(respawns == before and bounces == 0, "The omission starts from a real entrance without a death or accidental reflection")
	if failed: return
	var target: float = room.get_node("Exit").position.x if kind == "bumpers" else stage._bumpers().get_child(0).position.x
	var air_started := Engine.get_physics_frames() - (1 if kind == "step" else 0)
	var spent := false
	for frame in 720:
		if respawns > before or stage.room_index != index or stage.transitioning or stage.completed: break
		if kind != "bumpers" and bounces > 0: break
		if not player.is_dashing():
			_entry_horizontal(target)
			Input.action_press("wall_grab")
			Input.action_press("move_up")
			if player.is_on_floor():
				if absf(_x() - room.get_node("Rest").position.x) < 200: entry_relaunches += 1
				air_started = Engine.get_physics_frames()
				spent = false
				await _pulse("jump")
			if aim != Vector2.ZERO and not spent and Engine.get_physics_frames() - air_started >= delay and player.is_dash_ready():
				_release_inputs()
				Input.action_press("wall_grab")
				if aim.x != 0: Input.action_press("move_right" if aim.x > 0 else "move_left")
				if aim.y != 0: Input.action_press("move_down" if aim.y > 0 else "move_up")
				await _pulse("dash")
				spent = true
		await _step()
	_check(stage.room_index == index and not stage.transitioning and not stage.completed, "Omitting %s cannot reach the real exit/Goal (room=%d aim=%s delay=%d)" % [kind, index + 1, aim, delay])
	_check(bounces == 0, "The omitted entrance mechanic cannot be replaced before a real reflection (kind=%s room=%d aim=%s delay=%d)" % [kind, index + 1, aim, delay])
	if kind == "spring": _check(spring_launches[0] == 0, "The missing Spring never launches the comparison")
	if failed: return
	entry_trials += 1
	print("CANYON_ENTRY_REQUIRED kind=%s room=%d aim=%s delay=%d deaths=%d x=%.2f y=%.2f" % [kind, index + 1, aim, delay, respawns - before, _x(), player.position.y])
	_release_inputs()


func _entry_walk_edge() -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var entrance: StaticBody2D = room.get_node("Entrance")
	var shape: CollisionShape2D = entrance.get_node("Collision")
	var bounds: Rect2 = shape.shape.get_rect()
	var left: bool = room.get_meta("exit_left", false)
	var target: float = entrance.position.x + (bounds.position.x + 30 if left else bounds.end.x - 30)
	for frame in 180:
		_entry_horizontal(target)
		await _step()
		if absf(_x() - target) < 8 and absf(player.velocity.x) < 60: return
		if respawns > 0: break
	_check(false, "Reach the favorable edge using real movement before the omission jump")


func _entry_real_support() -> Grabbable:
	var object: Grabbable = stage.rooms.get_child(stage.room_index).get_node("Items/Parachute")
	Input.action_release("wall_grab")
	await _step()
	_check(player.get_held_object() == null, "The step starts with an unheld native parachute")
	if failed: return object
	_entry_horizontal(object.position.x)
	await _pulse("jump")
	var supported := false
	for frame in 180:
		_entry_horizontal(object.position.x)
		Input.action_release("wall_grab")
		await _step()
		supported = false
		for contact in player.get_slide_collision_count():
			var collision := player.get_slide_collision(contact)
			if collision.get_collider() == object and collision.get_normal().dot(Vector2.UP) > 0.8: supported = true
		if supported and player.is_on_floor(): break
		if respawns > 0: break
	_check(supported and player.is_on_floor() and respawns == 0, "The player genuinely stands on the native parachute before simultaneous Grab/Jump")
	if not failed: entry_supports += 1
	return object
