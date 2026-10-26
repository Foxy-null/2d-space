extends "res://tests/corridor_sixth_route_test.gd"

var branch_started := 0
var observe_sixth_branch := false

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_sixth_scroll_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshots")
	var strengths: Array = [0.8] if OS.get_cmdline_user_args().has("--weak") else ([1.0] if OS.get_cmdline_user_args().has("--strong") else [1.0,0.8])
	for strength in strengths:
		steering_strength = strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for section in [30,32,34]:
			var only := -1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--section="):only=int(arg.trim_prefix("--section="))-1
			if only>=0 and only!=section:continue
			await _sixth_scroll(section, progress)
			if failed:return
	observe_sixth_view = false
	if OS.get_cmdline_user_args().has("--keep-fixture"):print("CORRIDOR_SIXTH_SAVED_PATH ",progress.save_path)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_SIXTH_SCROLL_TEST_OK checks=",checks)
	quit()

func _sixth_branch_touch(section: int) -> void:
	observe_sixth_view = observe_sixth_branch
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints") or not screenshot_mode)
	_check(await traverse_sixth(section,true), "The detour starts after the actual native entrance challenge")
	var room: Node2D = stage.rooms.get_child(section)
	if section==34:
		_check(await more_walk(room.route_x(795)) and await wide_shaft(room.walls[1]), "The upper branch starts after the real held wall kicks")
	if failed:return
	_hold()
	await step(20)
	await _sixth_capture("room%d_scroll_approach"%(section+1))
	for label in ["Scroll","ScrollMark"]:
		var node: Node2D = room.get_node(label)
		var bounds := node.get_global_transform_with_canvas()*Rect2(-16,-20,32,40)
		_sixth_bounds(bounds,"The actual optional "+label)
		if label=="ScrollMark" and player.get_held_object()!=null:
			var carried_shape: CollisionShape2D=player.get_held_object().collider
			_check(not bounds.intersects(carried_shape.get_global_transform_with_canvas()*carried_shape.shape.get_rect()),"The native entry marker remains separate from the real companion at the observation rest")
	var scroll: Area2D = room.get_node("Scroll")
	branch_started = Engine.get_physics_frames()
	var launch_floor: Rect2 = room.walls[0 if section==32 else 1]
	_check(await more_walk(clampf(scroll.position.x,launch_floor.position.x+30,launch_floor.end.x-30)),"The actual optional launch uses the near edge of its existing main shelf")
	more_drive(scroll.position.x-_more_x())
	await more_jump()
	var cooldown := 12
	for frame in 360:
		if scroll._follower==player:return
		more_drive(scroll.position.x-_more_x())
		cooldown=maxi(0,cooldown-1)
		if player.is_on_floor() and cooldown==0:
			Input.action_press("jump")
			cooldown=12
		elif not player.is_on_floor() and player.velocity.y>-40 and cooldown==0:
			if player.get_available_extra_jump_count()>0:
				Input.action_press("jump")
				cooldown=12
			elif player.is_dash_ready():
				Input.action_press("move_up")
				Input.action_press("dash")
				cooldown=12
		await step()
	_check(false,"Actual held movement reaches the optional airborne scroll")

func _sixth_fall(pending := false) -> void:
	observe_sixth_view = false
	var before:=deaths
	var room: Node2D=stage.rooms.get_child(stage.room_index)
	for frame in 420:
		more_drive(-3000*room.travel_direction)
		if pending and frame%6==0:await _pulse("jump")
		await step()
		if deaths!=before:
			_hold()
			await step(6)
			_check(deaths==before+1 and player.is_on_floor() and player.is_dash_ready(),"Actual fall or native Spike contact restores one real checkpoint")
			return
	_check(false,"Real movement away from the branch causes an actual death")

func _sixth_scroll(section: int, progress: Node) -> void:
	await _new_stage()
	var id: String = stage.rooms.get_child(section).get_node("Scroll").scroll_id
	var count: int = progress.get_count("companion")
	for interruption in ([] if screenshot_mode or OS.get_cmdline_user_args().has("--branch-only") else ["retry", "death", "leave"]):
		await _new_stage()
		await _enter(section)
		await _sixth_branch_touch(section)
		if failed: return
		var scroll: Area2D = stage.rooms.get_child(section).get_node("Scroll")
		_check(scroll._follower == player and not progress.has_scroll("companion", id), "The branch pickup waits for a real safe landing")
		if interruption == "retry":
			await _pulse("reset")
			_hold()
			await step(6)
			_check(scroll._follower == null and scroll.global_position == scroll._origin, "R restores the pending scroll to its native position")
		elif interruption == "death":
			await _sixth_fall(true)
			_check(scroll._follower == null and scroll.global_position == scroll._origin, "An actual fall cancels the pending scroll")
		else:
			stage.get_node("PauseMenu").return_to_select()
			await step(4)
		_check(progress.get_count("companion") == count, "An interrupted branch does not change the saved count")
		if failed: return
	observe_sixth_branch = true
	await _new_stage()
	await _enter(section)
	var started := Engine.get_physics_frames()
	var before := deaths
	await _sixth_branch_touch(section)
	if failed: return
	await _sixth_capture("room%d_scroll" % (section + 1))
	var room: Node2D = stage.rooms.get_child(section)
	var rest: StaticBody2D = room.get_node("ScrollRest")
	var shape: CollisionShape2D = rest.get_node("Collision")
	var rect := Rect2(rest.position + shape.shape.get_rect().position, shape.shape.get_rect().size)
	_check(await more_flight(rect, false), "The airborne scroll reaches its real confirmation shelf")
	_hold()
	await step(20)
	await _sixth_capture("room%d_scroll_rest" % (section + 1))
	_check(progress.has_scroll("companion", id) and stage._carry_requirement_met(), "A safe landing saves the scroll and keeps the companion")
	var stopped := player.position
	await step(180)
	_check(player.is_on_floor() and player.position.distance_to(stopped) < 2 and deaths == before, "The optional shelf allows three seconds of safe observation")
	var return_target: Rect2 = room.walls[0 if section==32 else 1]
	var return_face := Rect2(Vector2(clampf(_more_x(),return_target.position.x,return_target.end.x-160),return_target.position.y),Vector2(160,24))
	var return_floor: Rect2 = root.get_canvas_transform()*room.global_transform*return_face
	_check(root.get_visible_rect().encloses(return_floor), "The main return landing is visible before leaving the scroll shelf")
	_check(not stage.get_node("HUD/Info").get_global_rect().intersects(return_floor), "The HUD leaves the scroll return landing clear")
	_check(await more_transfer(room.walls[0 if section==32 else 1]), "The optional branch physically returns to its original main shelf")
	if failed: return
	await _sixth_capture("room%d_scroll_return" % (section + 1))
	var seconds := float(Engine.get_physics_frames() - branch_started) / 60
	print("CORRIDOR_SIXTH_SCROLL_%d strength=%.2f %.2fs" % [section + 1, steering_strength, seconds])
	_check(seconds < 30 and deaths == before, "The complete branch round trip stays below thirty seconds")
	_check(await traverse(section), "The branch rejoins the actual exit after returning to its original main shelf")
	print("SIXTH_SCROLL_TOTAL room=",section+1," strength=",steering_strength," entrance_to_exit_seconds=",(Engine.get_physics_frames()-started)/60.0)
	observe_sixth_view = false
	observe_sixth_branch = false
	await _new_stage()
	await _enter(section)
	_check(stage.rooms.get_child(section).get_node("Scroll").modulate.a < 1, "Saved collection remains as a faint revisit scroll")
	await _pulse("reset")
	_hold()
	await step(6)
	await _sixth_fall()
	_check(progress.get_count("companion") == count + 1, "Confirmed collection survives R and an actual fall")
	stage.get_node("PauseMenu").return_to_select()
	await step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage4")
	await _sixth_capture("room%d_selection" % (section + 1))
	var expected := "%d / 12" % (count + 1)
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 " + expected), "Selection displays and announces the saved count and actual total")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("companion") == count + 1 and progress.has_scroll("companion", id), "Reload preserves the unfinished stage collection")
