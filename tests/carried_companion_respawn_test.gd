extends SceneTree

var stage: Node
var player: PlayerController
var creature: Grabbable
var keys: Array = []
var hits := 0
var deaths := 0
var checks := 0
var failed := false
var peak_speed := 0.0
var stayed_in_room := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	stage = load("res://scenes/stage_4.tscn").instantiate()
	root.add_child(stage)
	# Initial fixture: Room2's normal checkpoint. All movement below uses input.
	stage.room_index = 1
	stage._set_checkpoint()
	player = stage.player
	player.respawn()
	creature = stage.rooms.get_child(1).get_node("Items/JumpCreature")
	player.respawned.connect(func(): deaths += 1)
	stage.rooms.get_child(1).get_node("Hazards/Spike1").player_hit.connect(func(): hits += 1)
	await _command([], 5)
	await _command(["Shift", "Right"], 8)
	await _command(["Shift"], 8)
	# Wait for the entrance spike's next pass without moving the held object.
	await _command(["Shift"], 201)
	_check(player.get_held_object() == creature and player.is_on_floor() and player.velocity.is_zero_approx() and player.get_available_extra_jump_count() == 1, "A real Grab and short walk leave the companion ready on the entrance floor")
	# Live input meets the moving spike; no signal emission, teleport or pause.
	await _command(["Shift", "Right", "Space"], 16)
	_check(hits == 1 and deaths == 1, "The carried jump causes one actual moving-spike retry")
	await _command(["Shift"], 15)
	await _command([], 60)
	_check(stayed_in_room and peak_speed < 1000, "The restored rigid body never receives a teleport impulse or leaves the room")
	_check(creature.position.y > 530 and creature.position.y < 620 and creature.position.x > 35 and creature.position.x < 250, "After a full second the companion remains on the safe entrance floor")
	_check(not player.get_collision_exceptions().has(creature) and not creature.get_collision_exceptions().has(player), "The temporary pair exception is removed after the restored bodies separate")
	var other: Grabbable = stage.rooms.get_child(0).get_node("Items/JumpCreature")
	_check(not player.get_collision_exceptions().has(other) and not other.get_collision_exceptions().has(player) and other.collision_layer == 1 and other.collision_mask == 1, "An unrelated free object keeps its ordinary collision settings")
	var probe := player.global_transform
	probe.origin = other.global_position + Vector2(-70, 0)
	var contact := KinematicCollision2D.new()
	_check(player.test_move(probe, Vector2(50, 0), contact) and contact.get_collider() == other, "The native physics query still collides with the other free object")
	await _command(["Shift"], 5)
	_check(player.get_held_object() == creature and stage._carry_requirement_met() and player.get_available_extra_jump_count() == 1, "Actual Grab reacquires the restored companion and restores delivery eligibility")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1])
	await _command([], 60)
	_check(not player.get_collision_exceptions().has(creature), "Reacquiring and dropping does not retain a collision exception")
	# R without a held object must retain the original reset behavior.
	await _command(["R"], 1)
	await _command([], 6)
	_check(player.position.distance_to(Vector2(1390, 594)) < 2 and player.get_held_object() == null and player.is_dash_ready(), "An unheld retry still returns to the safe current checkpoint")
	_check(player._separating_objects.is_empty(), "An unheld retry does not register unrelated bodies for separation")
	print("CARRIED_COMPANION_RESPAWN_TEST_%s (%d checks, peak speed %.1f)" % ["FAILED" if failed else "OK", checks, peak_speed])
	stage.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _command(wanted: Array, frames: int) -> void:
	for name in keys:
		if not wanted.has(name):
			_key(name, false)
	for name in wanted:
		if not keys.has(name):
			_key(name, true)
	keys = wanted.duplicate()
	Input.flush_buffered_events()
	await _step(frames)


func _key(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = OS.find_keycode_from_string(name)
	event.physical_keycode = event.keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame
		await process_frame
		if deaths > 0 and is_instance_valid(creature):
			peak_speed = maxf(peak_speed, creature.linear_velocity.length())
			stayed_in_room = stayed_in_room and Rect2(0, 32, 1280, 688).has_point(creature.position)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CARRIED_RESPAWN: " + message + " object=" + str(creature.position))
