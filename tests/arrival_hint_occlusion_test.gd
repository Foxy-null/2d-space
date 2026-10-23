extends SceneTree

var failed := false
var checks := 0
var tutorial: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	await _step(4)
	tutorial.set_physics_process(false)
	tutorial.player.set_physics_process(false)
	tutorial.player.get_node("Visuals/Body").set_process(false)
	tutorial.get_node("Background/Starfield").motion_enabled = false
	tutorial.get_node("Background/Starfield").elapsed = 0.0
	tutorial._set_room(1, false)
	tutorial.camera.position = tutorial._camera_position()
	for key in tutorial.STEPS[1]:
		tutorial._mark(key)
	await _step(32)
	var player: PlayerController = tutorial.player
	var goal: ArrivalSwitch = tutorial.rooms.get_child(1).get_node("Goal")
	var bubble: Node2D = goal.get_node("Bubble")
	var original_position := bubble.position
	var objective: String = bubble.get_node("Objective").text
	# Match the obscured airborne pose from the screen-only play session.
	player.get_node("Visuals/Body").animation = &"fall"
	for details in [true, false]:
		tutorial.set_hints_visible(details)
		player.global_position = goal.global_position + Vector2(-38, -195 if details else -230)
		await _step(3)
		_check(is_zero_approx(bubble.modulate.a), "Airborne ninja stays visible in either hint mode")
		await _capture("%s-overlap" % ("detail" if details else "compact"))
		player.position = Vector2(1 * 1280 + 110, 614)
		await _step(3)
		_check(is_equal_approx(bubble.modulate.a, 1.0), "Cue returns after the ninja leaves")
		_check(bubble.get_node("Objective").visible == details and bubble.get_node("Objective").text == objective, "Occlusion preserves the hint preference and objective")
		await _capture("%s-restored" % ("detail" if details else "compact"))
	for details in [false, true]:
		tutorial.set_hints_visible(details)
		# An authored room override must move the avoidance region with the cue.
		bubble.position = Vector2(-220, -190)
		for gravity in [1, -1]:
			player.set_gravity_direction(gravity)
			await _step(12)
			for scene in ["grabbable", "heavy_object", "jump_creature", "parachute_creature"]:
				var bounds: Rect2 = bubble.global_transform * goal.get_hint_rect()
				player.global_position = Vector2(bounds.get_center().x, bounds.end.y + 32 if gravity > 0 else bounds.position.y - 32)
				var item: Grabbable = load("res://scenes/%s.tscn" % scene).instantiate()
				root.add_child(item)
				item.global_position = player.global_position
				_check(player.try_begin_grab(item), "Carry fixture can pick up " + scene)
				await _step(3)
				_check(is_zero_approx(bubble.modulate.a), "Cue yields when only the held artwork overlaps: %s, gravity %d" % [scene, gravity])
				if details and scene == "parachute_creature":
					await _capture("held-%s-overlap" % ("normal" if gravity > 0 else "inverted"))
				player.position.x -= 500
				player._update_carry_position()
				await _step(3)
				_check(is_equal_approx(bubble.modulate.a, 1.0), "Cue returns after the held artwork leaves")
				player.release_grab()
				item.queue_free()
				await _step(1)
	bubble.position = original_position
	bubble.hide()
	await _step(3)
	_check(not bubble.visible, "An explicitly hidden cue stays hidden")
	var optional: ArrivalSwitch = load("res://scenes/arrival_switch.tscn").instantiate()
	optional.mission_required = false
	root.add_child(optional)
	await _step(3)
	_check(not optional.get_node("Bubble").visible and not optional.locked, "Non-mission switches keep their existing hidden cue")
	optional.queue_free()
	_check(goal.get_node("Bubble/Objective").visible and not goal.locked and not goal.is_pressed(), "Avoidance preserves detail mode and switch progress")
	print("ARRIVAL_HINT_OCCLUSION_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	DirAccess.make_dir_recursive_absolute("/tmp/arrival-hint-occlusion")
	RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png("/tmp/arrival-hint-occlusion/%s.png" % name)
	_check(result == OK, "Native screenshot saved")


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("ARRIVAL_HINT_OCCLUSION: " + message)
