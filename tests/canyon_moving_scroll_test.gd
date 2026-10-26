extends "res://tests/canyon_applications_scroll_test.gd"

const MOVING_ROOM := 33
const MOVING_SCROLL := "moving_sky_12"
var moving_contact := false


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		_check(arg.begins_with("--phase=") or arg in ["--strong", "--weak", "--branch-only", "--screenshots", "--keep-fixture", "--hints", "--stage-only", "--selection-only"], "Known moving-scroll argument: " + arg)
		if failed: return
	_check(not (OS.get_cmdline_user_args().has("--strong") and OS.get_cmdline_user_args().has("--weak")), "Choose only one strength filter")
	if failed: return
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	_check(progress.TOTALS["canyon"] == 12, "The native collection total includes the twelfth scroll")
	if failed: return
	var strengths: Array = [1.0, 0.8]
	if OS.get_cmdline_user_args().has("--strong") or OS.get_cmdline_user_args().has("--screenshots"): strengths = [1.0]
	if OS.get_cmdline_user_args().has("--weak"): strengths = [0.8]
	for strength in strengths:
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		await _moving_lifecycle(strength)
		if failed: return
	monitor_view = false
	_release_inputs()
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("CANYON_MOVING_SAVED_PATH ", progress.save_path)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_MOVING_SCROLL_TEST_OK ", checks, " checks")
	quit()


func _moving_lifecycle(strength: float) -> void:
	print("CANYON_MOVING_LIFECYCLE axis=",strength)
	if not OS.get_cmdline_user_args().has("--branch-only") and not OS.get_cmdline_user_args().has("--screenshots"):
		for interruption in ["retry", "death", "leave"]:
			await _entry_setup(MOVING_ROOM)
			await _entry_pickup(strength)
			if failed: return
			_check(_scroll()._follower == player and not _scroll()._secured and not player.is_on_floor(), "The actual moving-room pickup remains airborne and pending")
			if failed: return
			monitor_view = false
			if interruption == "retry":
				await _pulse("reset")
				await _step(6)
			elif interruption == "death":
				await _application_die()
			else:
				stage.get_node("PauseMenu").return_to_select()
				await _step(4)
			if failed: return
			_check(progress.get_count("canyon") == 0 and not progress.has_scroll("canyon", MOVING_SCROLL), "Pending R, actual death and leaving never save the moving scroll")
			if interruption != "leave":
				_check(_scroll()._follower == null and _scroll().global_position == _scroll()._origin, "The interrupted actual scroll returns to its native origin")
			# Read the actual file, not only the in-memory pending state.
			progress._collected.clear()
			progress.load_progress()
			_check(progress.get_count("canyon") == 0, "Cancellation leaves no confirmed ID on disk")
			if failed: return
	await _entry_setup(MOVING_ROOM)
	monitor_view = true
	var started := Engine.get_physics_frames()
	await _entry_pickup(strength)
	if failed: return
	await _capture("room34_scroll_touch")
	await _entry_scroll_land(strength)
	if failed: return
	_check(progress.has_scroll("canyon", MOVING_SCROLL) and progress.get_count("canyon") == 1 and respawns == 0, "Real motion secures the twelfth scroll on its own optional shelf")
	var stopped := player.position
	await _step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and respawns == 0, "The actual scroll shelf permits three safe seconds without input")
	_application_preview()
	await _capture("room34_scroll_rest")
	if failed: return
	await _pulse("jump")
	await _land_at_wide_rest(strength)
	if failed: return
	var rest: Node2D = stage.rooms.get_child(MOVING_ROOM).get_node("Rest")
	_check(absf(player.position.y - (rest.position.y - 34)) < 2 and respawns == 0, "The optional shelf returns naturally to the same native main rest")
	var branch_seconds := float(Engine.get_physics_frames() - started) / 60
	_check(branch_seconds < 30, "Entrance, real pickup, three-second rest and natural return stay below thirty seconds")
	await _capture("room34_scroll_return")
	if failed: return
	await _moving_relaunch(strength, 20)
	if failed: return
	await _entry_finish(strength, 20)
	_release_inputs()
	_check(stage.completed and respawns == 0 and stage.next_bumper == stage._bumpers().get_child_count() and stage.goal.is_pressed(), "The branch rejoins the actual Boot/reflection route and presses the final Goal")
	_check(progress.get_count("canyon") == 1, "Goal arrival preserves exactly one confirmed scroll")
	await _capture("room34_scroll_goal")
	print("CANYON_MOVING_SCROLL_RETURN axis=", strength, " branch_seconds=", branch_seconds, " total_to_goal_seconds=", float(Engine.get_physics_frames() - started) / 60)
	if failed or OS.get_cmdline_user_args().has("--branch-only"): return
	await _entry_setup(MOVING_ROOM)
	_check(_scroll()._secured and _scroll().modulate.a < 1 and _scroll()._follower == null, "Revisiting displays the faint confirmed native marker")
	await _pulse("reset")
	await _step(6)
	_check(progress.get_count("canyon") == 1 and progress.has_scroll("canyon", MOVING_SCROLL), "R preserves the confirmed scroll")
	monitor_view = false
	await _application_die()
	if failed: return
	_check(progress.get_count("canyon") == 1 and stage.room_index == MOVING_ROOM and player.is_dash_ready(), "Actual death preserves the confirmed ID and restores this checkpoint")
	await _entry_setup(MOVING_ROOM)
	monitor_view = true
	print("CANYON_MOVING_RECONTACT axis=",strength)
	await _entry_pickup(strength)
	if failed: return
	_check(_scroll()._secured and _scroll()._follower == null and moving_contact, "Ordinary controls recontact the faint native marker without another follower")
	_check(progress.get_count("canyon") == 1, "Actual recontact never duplicates its saved ID")
	monitor_view = false
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage5")
	_check(card.get_node("Content/Collection/Count").text == "1 / 12" and card.accessibility_name.contains("巻物 1 / 12"), "Selection displays and announces the real one-out-of-twelve save")
	await _capture("room34_scroll_selection")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("canyon") == 1 and progress.has_scroll("canyon", MOVING_SCROLL), "Leaving and a real file reload retain the actual confirmed pickup")


func _entry_pickup(strength: float, _from_rest := false) -> void:
	moving_contact=false
	_scroll().body_entered.connect(func(body):
		if body==player:moving_contact=true)
	# The caller enables viewport monitoring only for the positive/revisit route.
	Input.action_press("move_right", strength)
	_check(is_equal_approx(Input.get_axis("move_left", "move_right"), strength), "The reported normal/weak strength matches the live action axis")
	_release_inputs()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):await _step(int(arg.trim_prefix("--phase=")))
	await _moving_first(strength)
	if failed: return
	await _capture("room34_scroll_approach")
	for frame in 600:
		if _application_touched() or respawns > 0: break
		_steer_to(_scroll().position, false, strength)
		await _step()
	_release_inputs()
	_check(_application_touched() and respawns == 0, "Actual Spring and moving reflection controls contact the native optional scroll")
	if not _scroll()._secured:
		_check(not player.is_on_floor() and _scroll()._follower == player, "The first real contact is airborne before any safe confirmation")


func _application_preview() -> void:
	var room: Node2D = stage.rooms.get_child(MOVING_ROOM)
	for path in ["ScrollRest/Collision", "Rest/Collision", "Scroll/CollisionShape2D"]:
		var shape: CollisionShape2D = room.get_node(path)
		_application_visible(shape.get_global_transform_with_canvas() * shape.shape.get_rect(), "The next actual optional/return floor " + path)


func _capture(label: String) -> void:
	if not label.contains("_scroll_"): return
	if OS.get_cmdline_user_args().has("--stage-only") and label.ends_with("_selection"): return
	if OS.get_cmdline_user_args().has("--selection-only") and not label.ends_with("_selection"): return
	if monitor_view and label.ends_with("_approach"):
		var room: Node2D = stage.rooms.get_child(MOVING_ROOM)
		for name in ["Scroll", "ScrollMark"]:
			var node: Node2D = room.get_node(name)
			_application_visible(node.get_global_transform_with_canvas() * Rect2(-22, -22, 44, 44), "The optional branch " + name)
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	var directory := "res://docs/screenshots/canyon-moving/" + ("hints" if OS.get_cmdline_user_args().has("--hints") else "default")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory + "/" + label + ".png") == OK, "Save the actual optional moving-route phase")

func _application_touched() -> bool:
	return _scroll()._follower==player or (_scroll()._secured and moving_contact)
