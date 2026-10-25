extends "res://tests/stage_3_test.gd"

var progress: Node
var captures: Dictionary = {}
var monitor_view := false


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_parachute_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var args := OS.get_cmdline_user_args()
	var selected := 21
	for arg in args:
		if arg.begins_with("--room="): selected = int(arg.trim_prefix("--room=")) - 1
	var rooms := [selected] if selected != 21 or args.has("--room=22") else [21,22,23,24]
	var configurations := [[0.8,20]] if args.has("--weak") else [[1.0,20]]
	if args.has("--timing"):
		configurations = []
		for strength in [1.0,0.8]:
			for gap in [16,20,24]: configurations.append([strength,gap])
	for config in configurations:
		para_strength = config[0]
		para_gap = config[1]
		Input.action_press("move_right",para_strength)
		_check(is_equal_approx(Input.get_axis("move_left","move_right"),para_strength),"The real action axis equals the declared strength")
		_release_inputs()
		for index in rooms:
			await _fresh_para(index)
			await _para_course(index)
			_check(progress.get_count("gravity")==0,"The main course leaves every optional scroll untouched")
			if index == 24:
				_check(not stage.completed, "The former twenty-fifth final is now intermediate")
				monitor_view = false
				await _para_walk(3040)
				_para_drive(3120)
				await _until(func(): return stage.room_index == 25, 160, "The actual old25 exit enters the new26 checkpoint")
				_release_inputs()
				await _step(25)
				_check(not stage.transitioning and player.controls_enabled and player.position.distance_to(stage.rooms.get_child(25).get_node("Spawn").global_position)<5 and player.gravity_direction==1 and player.is_dash_ready() and player.get_held_object()==null, "The new26 native checkpoint restores normal input and resources after real transfer")
			if failed: break
		if failed: break
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_PARACHUTE_ROUTE_TEST_%s %d checks" % ["FAILED" if failed else "OK",checks])
	quit(1 if failed else 0)


func _fresh_para(index: int) -> void:
	monitor_view = false
	_release_inputs()
	_reset_course()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage._set_room(index, false)
	player.respawn()
	await _step(4)
	respawns = 0
	actions.clear()
	flips.clear()
	player.respawned.connect(func(): respawns += 1)
	player.movement_action.connect(func(action: String): actions[action] = actions.get(action,0)+1)
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	for crystal in stage.rooms.get_child(index).find_children("*", "Area2D", true, false):
		if crystal.get_script() != null and crystal.get_script().resource_path == "res://scripts/refill_crystal.gd": crystal.collected.connect(func(_body): actions["crystal"] = actions.get("crystal",0)+1)
	if OS.get_cmdline_user_args().has("--hints"): stage.set_hints_visible(true)
	monitor_view = true
	_check(stage.rooms.get_child_count() == 31 and not stage.completed, "Thirty-one native rooms begin without premature completion")
	for room in stage.rooms.get_children():
		var boundary:Node2D=room.get_node_or_null("RightBoundary")
		if boundary!=null:
			var last:bool=room.get_index()==stage.rooms.get_child_count()-1
			_check(boundary.get_node("Collision").disabled!=last and boundary.visible==last,"Only the final native boundary remains solid and visible")
	var ids: Dictionary={}
	for candidate in stage.rooms.find_children("*","Area2D",true,false):
		if candidate.get_script()!=null and candidate.get_script().resource_path=="res://scripts/scroll_collectible.gd":
			_check(candidate.stage_id=="gravity" and not ids.has(candidate.scroll_id),"Placed scrolls have unique stage-scoped IDs")
			ids[candidate.scroll_id]=true
	_check(ids.size()==10 and progress.TOTALS["gravity"]==10,"Ten native scrolls match the persisted selection total")
	await _para_capture("room_%d_entrance"%(index+1))




func _para_capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or captures.has(name): return
	captures[name]=true
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-parachute")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/gravity-parachute/%s.png"%name)==OK,"Save native screenshot")


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not monitor_view or not is_instance_valid(player) or not is_instance_valid(stage) or stage.transitioning: continue
		var shape: CollisionShape2D=player.get_node("CollisionShape2D")
		var body := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position,shape.shape.get_rect().size)
		_check(root.get_visible_rect().encloses(body),"The full player remains in the camera throughout the actual route")
		var panels: Array[Control] = [stage.get_node("HUD/Margin/Panel"),stage.get_node("HUD/PauseButton"),stage.get_node("HUD/Status")]
		var card: PanelContainer=stage.get_node("HUD/Completion").card
		panels.append(card)
		for panel in panels:
			if not panel.is_visible_in_tree(): continue
			_check(not panel.get_global_rect().intersects(body),"The player stays outside visible HUD: "+str(panel.name))
			var held: Grabbable=player.get_held_object()
			if held != null:
				var bounds:=Rect2(held.collider.get_global_transform_with_canvas()*held.collider.shape.get_rect().position,held.collider.shape.get_rect().size)
				_check(root.get_visible_rect().encloses(bounds) and not panel.get_global_rect().intersects(bounds),"The full carried Parachute stays visible outside HUD: "+str(panel.name))


func _check(ok: bool,message: String) -> void:
	super._check(ok,message)
	if not ok: quit(1)
