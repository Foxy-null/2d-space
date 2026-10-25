extends "res://tests/corridor_fourth_route_test.gd"

var observe_fifth_view := false

func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_fifth_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshots")
	var profiles: Array = [[1.0, 20]] if OS.get_cmdline_user_args().has("--strong") or screenshot_mode else [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	var first := 24
	var last := 30
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): first = int(arg.trim_prefix("--section="))-1; last = first+1
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		steering_strength = profile[0]
		observe_fifth_view = false
		await _new_stage()
		await _enter(first)
		more_drive(100*stage.rooms.get_child(first).travel_direction)
		_check(is_equal_approx(absf(Input.get_axis("move_left","move_right")),steering_strength), "The synthetic horizontal action really uses the stated direct axis strength")
		_hold()
		stage.set_hints_visible(true)
		observe_fifth_view = not OS.get_cmdline_user_args().has("--no-view")
		var ids: Array[String] = []
		var goals := 0
		for room in stage.rooms.get_children():
			if room.has_node("Scroll"):
				var scroll: Area2D = room.get_node("Scroll")
				_check(scroll.stage_id == "companion" and not ids.has(scroll.scroll_id), "Actual scroll IDs are unique and belong to the carry course")
				ids.append(scroll.scroll_id)
			if room.has_node("Goal"): goals += 1
		_check(ids.size() == 9 and progress.TOTALS["companion"] == 9, "Nine actual optional scrolls match the saved selection total")
		_check(stage.rooms.get_child_count() == 30 and goals == 1 and stage.goal.get_parent() == stage.rooms.get_child(29), "Thirty native rooms lead to one final Goal")
		for section in range(first,last):
			var before := deaths
			var started := Engine.get_physics_frames()
			actions.clear()
			if section == 27:
				var shape: CollisionShape2D = stage.rooms.get_child(section).get_node("Bumper/CollisionShape2D")
				var bumper: Rect2 = shape.get_global_transform_with_canvas()*shape.shape.get_rect()
				print("FIFTH_FIRST_BUMPER rect=",bumper," camera=",stage.camera.position," target=",stage._camera_position())
				_check(root.get_visible_rect().encloses(bumper), "The whole real first bumper is visible before dropping from the entrance")
				for path in ["Info","PauseButton","Hint"]:_check(not stage.get_node("HUD/"+path).get_global_rect().intersects(bumper), "The first physical rebound remains clear of shown HUD")
			await _fifth_capture("room%d_entrance" % (section+1))
			_check(await traverse_fifth(section, true, profile[1]), "The real new entrance reaches its safe intermediate rest")
			if failed:return
			_hold()
			await step(20)
			var stopped := player.position
			await step(180)
			_check(player.is_on_floor() and player.position.distance_to(stopped)<2 and stage._carry_requirement_met(), "The native rest allows three stationary seconds while retaining the actual companion")
			_fifth_mechanic_view(section)
			await _fifth_capture("room%d_rest" % (section+1))
			_check(await traverse_fifth(section, false, profile[1]), "The real course reaches its next checkpoint or final Goal")
			var seconds := (Engine.get_physics_frames()-started)/60.0
			print("FIFTH_MAIN room=",section+1," strength=",profile[0]," gap=",profile[1]," seconds=",seconds," actions=",actions)
			_check(deaths == before+(0 if section==29 else 1) and seconds<30, "The successful retry has only its ordinary transfer and remains under thirty seconds including rest")
			_check(progress.get_count("companion")==0, "The normal route leaves optional scrolls untouched")
			if failed:return
			_hold()
			await step(25)
			if section==29:await _fifth_capture("room30_goal")
		_check(stage.completed if last==30 else stage.room_index==last, "The actual new rooms connect to their intended endpoint")
	observe_fifth_view = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_FIFTH_ROUTE_TEST_OK checks=",checks)
	quit()

func step(count: int = 1) -> void:
	for frame in count:
		await super.step()
		if not observe_fifth_view or not is_instance_valid(stage) or not is_instance_valid(player) or stage.room_index<24 or stage.transitioning:continue
		var body: Rect2 = player.get_node("CollisionShape2D").get_global_transform_with_canvas()*player.get_node("CollisionShape2D").shape.get_rect()
		var screens: Array[Control] = [stage.get_node("HUD/Info"),stage.get_node("HUD/PauseButton")]
		if stage.get_node("HUD/Hint").visible:screens.append(stage.get_node("HUD/Hint"))
		var completion: Label = stage.get_node("HUD/Completion")
		if completion.visible and completion.card.visible:screens.append(completion.card)
		var held: Grabbable = player.get_held_object()
		_check(root.get_visible_rect().encloses(body), "The entire real player remains in the viewport")
		for control in screens:
			if control.get_global_rect().intersects(body): print("FIFTH_VIEW_BAD room=",stage.room_index+1," body=",body," hud=",control.name,control.get_global_rect()," p=",Vector2(_more_x(),player.position.y))
			_check(not control.get_global_rect().intersects(body), "The actual player remains outside all visible HUD panels")
			if held!=null:
				var object: Rect2 = held.collider.get_global_transform_with_canvas()*held.collider.shape.get_rect()
				if not root.get_visible_rect().encloses(object) or control.get_global_rect().intersects(object): print("FIFTH_HELD_BAD room=",stage.room_index+1," object=",object," hud=",control.name,control.get_global_rect()," p=",Vector2(_more_x(),player.position.y))
				_check(root.get_visible_rect().encloses(object) and not control.get_global_rect().intersects(object), "The whole held object remains visible outside every shown HUD panel")
		_check(not screens[0].get_global_rect().intersects(screens[1].get_global_rect()), "The Info and Pause controls stay separate")
		if stage.get_node("HUD/Hint").visible:_check(not screens[0].get_global_rect().intersects(screens[2].get_global_rect()), "The Info and optional Hint remain readable separately")

func _fifth_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	if OS.get_cmdline_user_args().has("--selection-only") and not label.ends_with("_selection"):return
	if OS.get_cmdline_user_args().has("--stage-only") and (label.ends_with("_selection") or not label.contains("_scroll")):return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-fifth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/corridor-fifth/%s.png"%label)==OK, "The actual native image is saved")


func _fifth_cleanup() -> void:
	observe_fifth_view = false
	if is_instance_valid(stage):
		if stage.completed: await step(60)
		for sound in stage.find_children("*", "AudioStreamPlayer", true, false):
			sound.stop()
			sound.stream = null
	await _fourth_cleanup()


func _fifth_mechanic_view(section: int) -> void:
	var room: Node2D = stage.rooms.get_child(section)
	var bounds: Rect2
	if section==26:
		bounds = root.get_canvas_transform()*room.get_global_transform()*Rect2(room.walls[1].position,Vector2(220,24))
	else:
		var path: String = {24:"Items/JumpCrystal",25:"Items/UpGate",27:"Items/UpGate",28:"Bumper",29:"Spring"}[section]
		var mechanic: Node2D = room.get_node(path)
		var shape: CollisionShape2D = mechanic.get_node("CollisionShape2D")
		bounds = shape.get_global_transform_with_canvas()*shape.shape.get_rect()
	print("FIFTH_NEXT room=",section+1," bounds=",bounds)
	_check(root.get_visible_rect().encloses(bounds), "The actual next mechanic or a broad safe landing surface is visible from the stationary observation rest")
	for path in ["Info","PauseButton","Hint"]:
		_check(not stage.get_node("HUD/"+path).get_global_rect().intersects(bounds), "Shown HUD panels leave the next real mechanic or landing visible")
