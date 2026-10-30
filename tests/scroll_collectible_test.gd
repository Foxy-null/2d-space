extends SceneTree

class LandingHazard extends Node:
	var player: PlayerController
	var grounded_time := 0.0
	var hits := 0

	func _physics_process(delta: float) -> void:
		if hits == 0 and player.is_on_floor():
			grounded_time += delta
			if grounded_time >= 0.2:
				hits += 1
				player.respawn.call_deferred()


var test_save := "user://scroll_collectible_test_%d.cfg" % OS.get_process_id()
var world: Node2D
var player: PlayerController
var scroll: Area2D
var progress: Node
var audio: Node
var checks := 0
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	audio = root.get_node("GameAudio")
	var original_path: String = progress.save_path
	var original_records: Dictionary = progress._collected.duplicate(true)
	progress.save_path = test_save
	progress._collected.clear()
	await _airborne_and_secured()
	await _retry(false)
	await _retry(true)
	await _deferred_death()
	await _gravity_change()
	await _transition()
	await _room_transfer()
	await _dash()
	await _wall_hold()
	await _spring()
	await _rigid_support()
	await _save_failure()
	_clear()
	progress.save_path = original_path
	progress._collected = original_records
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save + ".tmp"))
	print("SCROLL_COLLECTIBLE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _airborne_and_secured() -> void:
	_fixture("landing")
	await _step(6)
	_check(scroll._follower == player and not _has("landing"), "Airborne contact follows without securing the scroll")
	_check(audio.scroll_touch.playing and not audio.scroll_collect.playing, "Contact plays only the touch sound before landing")
	audio.scroll_touch.stop()
	scroll._on_body_entered(player)
	_check(not audio.scroll_touch.playing, "Repeated contact while following does not replay the touch sound")
	var creature: Grabbable = load("res://scenes/jump_creature.tscn").instantiate()
	creature.position = player.position + Vector2(42, 0)
	world.add_child(creature)
	Input.action_press("wall_grab")
	await _step(5)
	_check(player.get_held_object() == creature and scroll._follower == player, "A pending scroll leaves the companion holding slot available")
	for frame in 65:
		await _step()
		if scroll._secured:
			break
	_check(_has("landing") and scroll._secured and scroll.modulate.a < 0.5, "A safe landing saves once and leaves a faint scroll at its original position")
	_check(audio.scroll_collect.playing, "Saving the scroll plays the distinct acquisition pop")
	_check(scroll.position.is_equal_approx(scroll._origin), "The secured marker stays at the collectible location")
	audio.scroll_collect.stop()
	player.respawn()
	scroll.reset_for_respawn()
	await _step(3)
	_check(scroll._secured and progress.get_count("gravity") == 1, "Retry and repeated contact preserve a secured scroll without adding another")
	_check(not audio.scroll_collect.playing and not audio.scroll_touch.playing, "A secured scroll does not replay either sound")
	var duplicate: Area2D = load("res://scenes/scroll_collectible.tscn").instantiate()
	duplicate.stage_id = "gravity"
	duplicate.scroll_id = "landing"
	duplicate.position = player.position
	world.add_child(duplicate)
	await _step(20)
	_check(duplicate._secured and duplicate.modulate.a < 0.5 and progress.get_count("gravity") == 1, "A reloaded collected scroll starts faint and cannot be counted again")
	_check(not audio.scroll_collect.playing and not audio.scroll_touch.playing, "Loading an already collected scroll is silent")


func _retry(manual: bool) -> void:
	var id := "manual_retry" if manual else "death"
	_fixture(id)
	await _step(6)
	audio.scroll_touch.stop()
	player.set_respawn_position(Vector2(700, 80))
	if manual:
		Input.action_press("reset")
		await _step()
		Input.action_release("reset")
	else:
		player.respawn()
	# Simulate an already queued Area notification after the actual teleport.
	scroll._on_body_entered(player)
	_check(not audio.scroll_touch.playing, "A stale contact after retry does not play a touch sound")
	await _step(40)
	_check(not _has(id) and scroll._follower == null and scroll.position.is_equal_approx(scroll._origin), "Unsecured scroll returns after %s and rejects a stale enter notification" % id)


func _gravity_change() -> void:
	_fixture("inverted", 274)
	await _step(8)
	_check(player.is_on_floor() and not _has("inverted"), "Gravity-gate fixture starts from a short grounded contact")
	player.set_gravity_direction(-1)
	player.set_physics_process(false)
	await _step(20)
	_check(not _has("inverted"), "Changing gravity invalidates the cached floor before the next player movement")
	player.set_physics_process(true)
	await _step(75)
	_check(player.gravity_direction == -1 and player.is_on_floor() and _has("inverted"), "A safe ceiling landing secures the scroll under inverted gravity")


func _deferred_death() -> void:
	_fixture("deferred_death")
	player.set_respawn_position(Vector2(700, 80))
	var hazard := LandingHazard.new()
	hazard.player = player
	hazard.process_physics_priority = 10
	world.add_child(hazard)
	await _step(70)
	_check(hazard.hits == 1 and not _has("deferred_death") and scroll._follower == null, "A deferred hazard death on the collection tick cancels the pending save")


func _transition() -> void:
	_fixture("transition", 274)
	await _step(8)
	player.controls_enabled = false
	await _step(30)
	_check(not _has("transition"), "Room-transition input lock cannot secure a scroll from cached floor contact")
	player.controls_enabled = true
	await _step(8)
	_check(not _has("transition"), "A transition restarts the safe landing duration")
	await _step(10)
	_check(_has("transition"), "Restored controls permit a fresh safe landing")


func _dash() -> void:
	_fixture("dash", 274)
	await _step(8)
	Input.action_press("move_right")
	Input.action_press("dash")
	await _step(5)
	_check(player.is_dashing() and not _has("dash"), "Passing a scroll while dashing along terrain does not secure it")
	_release()
	await _step(8)
	_check(not _has("dash"), "A dash interrupts the partial landing duration")
	await _step(20)
	_check(_has("dash"), "A normal landing after the dash secures the scroll")


func _room_transfer() -> void:
	_fixture("room_transfer")
	await _step(6)
	player.controls_enabled = false
	player.set_respawn_position(Vector2(600, 274))
	player.respawn(true)
	await _step(20)
	_check(scroll._follower == player and not _has("room_transfer"), "Normal room transfer preserves the follower without securing during its input lock")
	_check(not player.room_transfer_in_progress, "The transfer reason lasts only during synchronous reset callbacks")
	player.controls_enabled = true
	await _step(8)
	_check(not _has("room_transfer"), "The new room requires a fresh safe landing duration")
	await _step(10)
	_check(_has("room_transfer"), "A safe landing after transfer secures the carried scroll")
	_fixture("locked_retry")
	await _step(6)
	player.controls_enabled = false
	player.respawn()
	await _step(20)
	_check(scroll._follower == null and not _has("locked_retry"), "Retry during a transition still returns an unsecured scroll")


func _wall_hold() -> void:
	_fixture("wall_hold", 274)
	_support(Vector2(215, 150), Vector2(20, 300))
	Input.action_press("wall_grab")
	Input.action_press("move_right")
	await _step(32)
	_check(player.is_wall_grabbing() and not _has("wall_hold"), "A grounded wall hold does not count as a safe landing")
	_release()
	await _step(20)
	_check(_has("wall_hold"), "Releasing the wall onto terrain permits collection")


func _spring() -> void:
	_fixture("spring", 274)
	await _step(8)
	player.launch_from_spring(Vector2(0, -900))
	player.set_physics_process(false)
	await _step(20)
	_check(not _has("spring"), "A spring launch invalidates the cached floor contact")
	player.set_physics_process(true)
	await _step(90)
	_check(_has("spring"), "Returning from the spring to terrain permits collection")


func _rigid_support() -> void:
	_fixture("rigid", 80, true)
	await _step(70)
	_check(player.is_on_floor() and not _has("rigid"), "Standing on a free rigid body does not secure a scroll")
	world.get_node("Floor").free()
	_support(Vector2(500, 320), Vector2(1000, 40))
	await _step(20)
	_check(_has("rigid"), "Stepping onto static terrain secures the pending scroll")


func _save_failure() -> void:
	_fixture("save_failure")
	progress.save_path = "user://scroll_missing_%d/collection.cfg" % Time.get_ticks_usec()
	await _step(70)
	_check(not _has("save_failure") and not scroll._secured and scroll._follower == player, "A failed save leaves the scroll pending and the collectible available")
	_check(not audio.scroll_collect.playing, "A failed save does not play a false acquisition sound")
	progress.save_path = test_save
	await _step(20)
	_check(_has("save_failure") and scroll._secured, "A successful save retry secures the scroll")


func _fixture(id: String, start_y: float = 80, rigid_floor: bool = false) -> void:
	_clear()
	audio.scroll_touch.stop()
	audio.scroll_collect.stop()
	world = Node2D.new()
	root.add_child(world)
	var floor_body := _support(Vector2(500, 320), Vector2(1000, 40), rigid_floor)
	floor_body.name = "Floor"
	_support(Vector2(500, -20), Vector2(1000, 40))
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(180, start_y)
	player.use_default_respawn_bounds = false
	world.add_child(player)
	scroll = load("res://scenes/scroll_collectible.tscn").instantiate()
	scroll.stage_id = "gravity"
	scroll.scroll_id = id
	scroll.position = player.position
	world.add_child(scroll)


func _support(at: Vector2, size: Vector2, rigid: bool = false) -> PhysicsBody2D:
	var body: PhysicsBody2D = RigidBody2D.new() if rigid else StaticBody2D.new()
	if rigid:
		body.freeze = true
	body.position = at
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body


func _has(id: String) -> bool:
	return progress.has_scroll("gravity", id)


func _clear() -> void:
	_release()
	if is_instance_valid(world):
		world.free()


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab", "reset"]:
		Input.action_release(action)


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
