extends "res://tests/corridor_sixth_route_test.gd"


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_hint_labels_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	await _new_stage()
	_check(not stage.hints_visible, "The stage initially disables optional hints")
	for room in stage.rooms.get_children():
		for label in ["CarryHint", "ExitLabel", "Checkpoint"]:
			var node: CanvasItem = room.get_node_or_null(label)
			if node != null:
				_check(not node.is_visible_in_tree(), "Hints OFF hides the optional world label: room%d %s" % [room.get_index() + 1, label])
				if failed: return
	for section in stage.rooms.get_child_count():
		await _enter(section)
		for enabled in [false, true]:
			stage.set_hints_visible(enabled)
			await step()
			_verify_current(enabled, true, false)
			# Proximity alone can be sampled without advancing hazards at the temporary position.
			var home := player.position
			player.position.x += stage.rooms.get_child(section).travel_direction * 400
			stage._update_hud()
			_verify_current(enabled, false, false)
			player.position = home
			stage._update_hud()
			_hold()
			await step(2)
			_check(stage._carry_requirement_met(), "Grab the actual local companion")
			_verify_current(enabled, true, true)
			await _pulse("reset")
			release()
			await step(6)
			_verify_current(enabled, true, false)
			if failed: return
		var pause_menu: CanvasLayer = stage.get_node("PauseMenu")
		pause_menu.open()
		for enabled in [false, true]:
			pause_menu.menu.get_node("Hints").pressed.emit()
			_check(paused, "The hint button updates labels while the game is paused")
			_verify_current(enabled, true, false)
		pause_menu.menu.get_node("Resume").pressed.emit()
		await step()
		_verify_current(true, true, false)
		if failed: return
	for enabled in [false, true]:
		await _enter(0)
		stage.set_hints_visible(enabled)
		await step(21)
		_check(await traverse(0), "The actual first carry route crosses its real room boundary")
		release()
		await step(25)
		_check(stage.room_index == 1 and not stage.transitioning, "The real transfer reaches room two")
		_verify_current(enabled, true, false)
		if failed: return
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	current_scene.get_node("Margin/Content/Stages/Stage4").pressed.emit()
	await step(5)
	stage = current_scene
	player = stage.player
	_check(stage.room_index == 0 and not stage.hints_visible, "Re-entering the stage starts with optional hints disabled")
	_verify_current(false, true, false)
	if OS.get_cmdline_user_args().has("--screenshots"):
		for section in [0, 23, 34, 35]: await _render_room(section)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_HINT_LABELS_TEST_OK checks=", checks)
	quit()


func _verify_current(enabled: bool, nearby: bool, held: bool) -> void:
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	_check(stage.hints_visible == enabled and stage.get_node("HUD/Hint").visible == enabled, "The world and HUD use the selected hint state")
	for label in ["ExitLabel", "Checkpoint"]:
		var node: CanvasItem = room.get_node_or_null(label)
		if node != null: _check(node.is_visible_in_tree() == enabled, "Only enabled hints show the optional world label: " + label)
	_check(room.get_node("CarryHint").is_visible_in_tree() == (enabled and nearby and not held), "Grab keys appear only with hints enabled near an unheld companion")
	for marker in ["DeliveryIcon", "DeliveryFrame"]:
		_check(room.get_node(marker).is_visible_in_tree(), "The physical companion delivery marker remains visible: " + marker)


func _render_room(section: int) -> void:
	await _new_stage()
	await _enter(section)
	for enabled in [false, true]:
		stage.set_hints_visible(enabled)
		await step()
		await _hint_capture("room%d_entrance_%s" % [section + 1, "on" if enabled else "off"])
	var room: Node2D = stage.rooms.get_child(section)
	player.position = Vector2(room.position.x + room.route_x(room.room_width - 220), room.exit_top - 26)
	player.velocity = Vector2.ZERO
	stage.camera.position = stage._camera_position()
	stage.camera.reset_smoothing()
	for enabled in [false, true]:
		stage.set_hints_visible(enabled)
		await step(2)
		var icon: Sprite2D = room.get_node("DeliveryIcon")
		_check(icon.is_visible_in_tree() and root.get_visible_rect().encloses(icon.get_global_transform_with_canvas() * icon.get_rect()), "The real required-companion picture stays visible at the exit")
		await _hint_capture("room%d_exit_%s" % [section + 1, "on" if enabled else "off"])


func _hint_capture(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-hints")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/corridor-hints/%s.png" % label) == OK, "Save the optional labels and physical delivery marker")
