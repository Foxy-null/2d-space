extends "res://tests/corridor_more_test.gd"

var observe_main_view := false

func _run() -> void:
	observe_main_view = true
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshots")
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_wide_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	await _refill_retry()
	if failed: return
	for profile in ([[1.0, 20]] if screenshot_mode else [[1.0, 20], [0.8, 16], [0.8, 20], [0.8, 24]]):
		var strength: float = profile[0]
		var gap: int = profile[1]
		steering_strength = strength
		for section in range(15, 18):
			await _new_stage()
			await _enter(section)
			_check_mechanic_view(section)
			await _wide_capture("room%d_entrance" % (section + 1))
			var started := Engine.get_physics_frames()
			var before := deaths
			_check(await traverse_wide(section, true, gap), "The actual entrance reaches its first wide-room rest")
			if failed: return
			_hold()
			await step(20)
			var stopped := player.position
			await step(180)
			_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and stage._carry_requirement_met(), "The observation rest stays safe with the carried companion")
			var room: Node2D = stage.rooms.get_child(section)
			if section == 15:
				var scroll: Area2D = room.get_node("Scroll")
				var scroll_bounds := Rect2(root.get_canvas_transform() * scroll.global_position - Vector2(16, 20), Vector2(32, 40))
				_check(not stage.get_node("HUD/Info").get_global_rect().intersects(scroll_bounds), "The first rest leaves the optional scroll clear of the HUD")
			elif section == 16:
				var next_ceiling := Rect2(root.get_canvas_transform() * room.to_global(room.walls[1].position), Vector2(200, 24))
				_check(root.get_visible_rect().encloses(next_ceiling), "The next inverted landing is visible before leaving the first ceiling")
				_check(not stage.get_node("HUD/Info").get_global_rect().intersects(next_ceiling), "The HUD leaves the next inverted landing visible")
			await _wide_capture("room%d_rest" % (section + 1))
			if screenshot_mode:
				if section == 15: _check(await more_transfer(stage.rooms.get_child(section).walls[1]), "The rendered course reaches its actual upper shelf")
				elif section == 16: _check(await wide_ceiling_transfer(stage.rooms.get_child(section).walls[1], gap), "The rendered course reaches its actual second ceiling")
				else: _check(await more_walk(1310) and await wide_shaft(stage.rooms.get_child(section).walls[1]), "The rendered course reaches the real wall top")
				await _wide_capture("room%d_upper" % (section + 1))
			_check(await traverse_wide(section, false, gap), "Actual input rejoins the main exit after resting")
			var seconds := float(Engine.get_physics_frames() - started) / 60
			print("CORRIDOR_WIDE_ROOM_%d strength=%.2f gap=%d %.2fs p=%s deaths=%d actions=%s" % [section+1, strength, gap, seconds, Vector2(_more_x(), player.position.y), deaths-before, actions])
			_check(deaths == before + (0 if section == stage.rooms.get_child_count()-1 else 1) and seconds < 30, "The successful retry including rest stays below thirty seconds")
			_check(progress.get_count("companion") == 0, "The main path leaves its optional scroll untouched")
			if failed: return
			if stage.completed: await _wide_capture("room18_goal")
	for strength in ([1.0] if screenshot_mode else [1.0, 0.8]):
		steering_strength = strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for section in [15, 17]:
			await _wide_scroll(section, progress)
			if failed: return
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("CORRIDOR_WIDE_SAVED_PATH ", progress.save_path)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CORRIDOR_WIDE_ROUTE_TEST_OK (%d checks)" % checks)
	quit()

func _check(value: bool, message: String) -> void:
	super._check(value, message)
	if failed:
		print("WIDE_FAILURE room=", stage.room_index+1, " p=", Vector2(_more_x(), player.position.y), " v=", player.velocity, " actions=", actions)
		quit(1)


func _wide_branch_touch(section: int) -> void:
	_check(await traverse_wide(section, true), "The real entrance reaches the branch approach")
	if failed: return
	var room: Node2D = stage.rooms.get_child(section)
	if section == 15:
		_check(await more_transfer(room.walls[1]), "The left branch begins on the upper main shelf")
	else:
		_check(await more_walk(1310) and await wide_shaft(room.walls[1]), "The upper branch begins after the real wind and wall kicks")
	if failed: return
	var scroll: Area2D = room.get_node("Scroll")
	more_drive(scroll.position.x - _more_x())
	await more_jump()
	var cooldown := 12
	for frame in 360:
		if scroll._follower == player: return
		more_drive(scroll.position.x - _more_x())
		cooldown = maxi(0, cooldown - 1)
		if player.velocity.y > -40 and cooldown == 0:
			if player.get_available_extra_jump_count() > 0:
				Input.action_press("jump")
				cooldown = 12
			elif player.is_dash_ready():
				if section == 15:
					Input.action_release("move_left")
					Input.action_release("move_right")
				Input.action_press("move_up")
				Input.action_press("dash")
				cooldown = 12
		await step()
	_check(false, "Actual input reaches the optional airborne wide-room scroll")


func _wide_fall(pending := false) -> void:
	var before := deaths
	var room: Node2D = stage.rooms.get_child(stage.room_index)
	var direction := 3000 if player.position.y > room.entrance_top - 100 else -1000
	for frame in 360:
		more_drive(direction)
		if pending and frame % 6 == 0: await _pulse("jump")
		await step()
		if deaths != before:
			_hold()
			await step(6)
			_check(deaths == before + 1 and player.is_on_floor() and player.is_dash_ready(), "A real fall restores one safe checkpoint")
			return
	_check(false, "Walking off the optional shelf actually falls")


func _wide_scroll(section: int, progress: Node) -> void:
	await _new_stage()
	var id: String = stage.rooms.get_child(section).get_node("Scroll").scroll_id
	var count: int = progress.get_count("companion")
	for interruption in ([] if screenshot_mode else ["retry", "death", "leave"]):
		await _new_stage()
		await _enter(section)
		await _wide_branch_touch(section)
		if failed: return
		var scroll: Area2D = stage.rooms.get_child(section).get_node("Scroll")
		_check(scroll._follower == player and not progress.has_scroll("companion", id), "The branch pickup waits for a real safe landing")
		if interruption == "retry":
			await _pulse("reset")
			_hold()
			await step(6)
			_check(scroll._follower == null and scroll.global_position == scroll._origin, "R restores the pending scroll to its native position")
		elif interruption == "death":
			await _wide_fall(true)
			_check(scroll._follower == null and scroll.global_position == scroll._origin, "An actual fall cancels the pending scroll")
		else:
			stage.get_node("PauseMenu").return_to_select()
			await step(4)
		_check(progress.get_count("companion") == count, "An interrupted branch does not change the saved count")
		if failed: return
	await _new_stage()
	await _enter(section)
	var started := Engine.get_physics_frames()
	var before := deaths
	await _wide_branch_touch(section)
	if failed: return
	await _wide_capture("room%d_scroll" % (section + 1))
	var room: Node2D = stage.rooms.get_child(section)
	var rest: StaticBody2D = room.get_node("ScrollRest")
	var shape: CollisionShape2D = rest.get_node("Collision")
	var rect := Rect2(rest.position + shape.shape.get_rect().position, shape.shape.get_rect().size)
	_check(await more_flight(rect, false), "The airborne scroll reaches its real confirmation shelf")
	_hold()
	await step(20)
	await _wide_capture("room%d_scroll_rest" % (section + 1))
	_check(progress.has_scroll("companion", id) and stage._carry_requirement_met(), "A safe landing saves the scroll and keeps the companion")
	var stopped := player.position
	await step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and deaths == before, "The optional shelf allows three seconds of safe observation")
	var return_floor := Rect2(root.get_canvas_transform() * room.to_global(room.walls[1].position), Vector2(100, 24))
	_check(root.get_visible_rect().encloses(return_floor), "The main return landing is visible before leaving the scroll shelf")
	_check(not stage.get_node("HUD/Info").get_global_rect().intersects(return_floor), "The HUD leaves the scroll return landing clear")
	if room.has_node("ShaftLeft"):
		var wall: StaticBody2D = room.get_node("ShaftLeft")
		var wall_shape: CollisionShape2D = wall.get_node("Collision")
		var wall_rect := Rect2(wall.position + wall_shape.shape.get_rect().position, wall_shape.shape.get_rect().size)
		_check(await more_walk(wall_rect.position.x - 40), "The upper branch reaches its real return edge")
		more_drive(wall_rect.get_center().x - _more_x())
		await more_jump()
		_check(await more_flight(Rect2(wall_rect.position, Vector2(wall_rect.size.x, 24)), false), "A normal jump rests on the left wall without approaching the ceiling spikes")
		more_drive(room.walls[1].get_center().x - _more_x())
		await more_jump()
		_check(await more_flight(room.walls[1], false), "The left wall returns to the main right wall")
	else:
		_check(await more_transfer(room.walls[1]), "The branch physically rejoins the same main shelf")
	if failed: return
	await _wide_capture("room%d_scroll_return" % (section + 1))
	var seconds := float(Engine.get_physics_frames() - started) / 60
	print("CORRIDOR_WIDE_SCROLL_%d strength=%.2f %.2fs" % [section + 1, steering_strength, seconds])
	_check(seconds < 30 and deaths == before, "The complete branch round trip stays below thirty seconds")
	_check(await traverse(section), "The branch rejoins the real exit and Goal")
	await _new_stage()
	await _enter(section)
	_check(stage.rooms.get_child(section).get_node("Scroll").modulate.a < 1, "Saved collection remains as a faint revisit scroll")
	await _pulse("reset")
	_hold()
	await step(6)
	await _wide_fall()
	_check(progress.get_count("companion") == count + 1, "Confirmed collection survives R and an actual fall")
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage4")
	await _wide_capture("room%d_selection" % (section + 1))
	var expected := "%d / 7" % (count + 1)
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 " + expected), "Selection displays and announces the saved count and actual total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("companion") == count + 1 and progress.has_scroll("companion", id), "Reload preserves the unfinished stage collection")


func _wide_capture(label: String) -> void:
	if not screenshot_mode: return
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-wide")
	root.get_texture().get_image().save_png("res://docs/screenshots/corridor-wide/%s.png" % label)


func _refill_retry() -> void:
	await _new_stage()
	await _enter(15)
	var crystal: Area2D = stage.rooms.get_child(15).get_node("Items/DashCrystal")
	var collected: Array[bool] = []
	crystal.collected.connect(func(_body): collected.append(true))
	_check(await more_walk(430), "The refill retry uses the native entrance and real companion")
	_hold()
	await more_jump()
	await step(20)
	await more_jump()
	await step(20)
	_drive(Vector2.UP)
	await _pulse("dash")
	await step(10)
	_check(collected.size() == 1 and not crystal._available and player.is_dash_ready() and actions.has("creature_jump"), "The real airborne Dash crystal refills the spent Dash")
	await _pulse("reset")
	release()
	await step(6)
	_check(crystal._available and player.get_held_object() == null and player.is_on_floor() and player.is_dash_ready() and player.position.distance_to(player._spawn_position) < 2, "R during the refill flight restores the crystal, companion and safe entrance")

func step(count: int = 1) -> void:
	for frame in count:
		await super.step()
		if observe_main_view and is_instance_valid(stage) and is_instance_valid(player) and stage.room_index == 16 and not stage.transitioning:
			var shape: CollisionShape2D = player.get_node("CollisionShape2D")
			var body := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position,shape.shape.get_rect().size)
			var hud: Control = stage.get_node("HUD/Info")
			_check(root.get_visible_rect().encloses(body) and not hud.get_global_rect().intersects(body),"The seventeenth room keeps the full player outside the HUD throughout the actual Up/Down route")
			var held: Grabbable = player.get_held_object()
			if held != null:
				var object_bounds := Rect2(held.collider.get_global_transform_with_canvas()*held.collider.shape.get_rect().position,held.collider.shape.get_rect().size)
				_check(not hud.get_global_rect().intersects(object_bounds),"The seventeenth room leaves the actual carried companion visible outside the HUD")
