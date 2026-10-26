extends "res://tests/stage_2_test.gd"

var checks := 0
var actions: Dictionary = {}
var monitor_view := false
var observed_frames := 0
var climb_frames := 0
var wind_force_frames := 0
var last_position := Vector2.ZERO
var last_velocity := Vector2.ZERO

func _run() -> void:
	var first := 19
	var last := 25
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): first = int(arg.trim_prefix("--section=")) - 1
		if arg.begins_with("--last="): last = int(arg.trim_prefix("--last="))
	var profiles: Array = [[1.0,20]] if (OS.get_cmdline_user_args().has("--strong") or OS.get_cmdline_user_args().has("--screenshots")) else [[1.0,16],[1.0,20],[1.0,24],[0.8,16],[0.8,20],[0.8,24]]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profiles = [profiles[int(arg.trim_prefix("--profile="))]]
	for profile in profiles:
		upper_strength = profile[0]
		upper_jump_delay = profile[1]
		upper_dash_delay = profile[1]
		await _fresh_fourth(18 if OS.get_cmdline_user_args().has("--old19") else first)
		if OS.get_cmdline_user_args().has("--old19"):
			await _parachute_course()
			_check(stage.checkpoint_index == 19 and respawns == 0 and player.get_held_object() == stage.get_node("Items/Parachute19"), "The actual old nineteenth glide delivers its same native parachute to CP20")
		for section in range(first, last):
			actions.clear()
			climb_frames = 0
			wind_force_frames = 0
			var before := respawns
			await _fourth_course(section)
			_check(respawns == before, "A successful native fourth course does not respawn")
			_check(root.get_node("CollectionProgress").get_count("tower") == 0, "Main traversal leaves both new optional scrolls untouched")
			if section == 19: _check(climb_frames>0 and actions.get("dash",0)>=3,"The wall, actual refill and horizontal transfer all contribute real actions")
			if section == 22: _check(actions.get("creature_jump",0)>0 and actions.get("air_jump",0)>0 and actions.get("wall_jump",0)>0,"The actual companion, Boot and wall jumps contribute separate actions")
			if section == 23: _check(wind_force_frames>0 and actions.get("air_jump",0)>0,"The real registered updraft lifts the held parachute and the later Boot supplies a real jump")
			if section == 24: _check(actions.get("dash",0)>=3,"The reflection and final refill contribute three actual dashes")
			print("FOURTH_ACTIONS section=",section+1," actions=",actions," climb_frames=",climb_frames," wind_force_frames=",wind_force_frames)
			if failed: return
		_check(stage.checkpoint_index==last and not stage.completed, "The real preceding native sections reach their next checkpoint without completing the new summit")
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FOURTH_ROUTE_TEST_OK checks=",checks," observed_frames=",observed_frames)
	quit(1 if failed else 0)

func _fresh_fourth(section: int) -> void:
	monitor_view = false
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(5)
	stage = current_scene
	player = stage.player
	stage._set_checkpoint(section)
	player.respawn()
	respawns = 0
	player.respawned.connect(func():
		print("FOURTH_RESPAWN p=",last_position," v=",last_velocity," peak=",stage.peak_y)
		respawns += 1)
	player.movement_action.connect(func(action): actions[action] = actions.get(action,0) + 1)
	await _step(5)
	stage.set_hints_visible(OS.get_cmdline_user_args().has("--hints"))
	monitor_view = true
	_check(player.is_on_floor(), "The actual new checkpoint is supported by its native safe floor")
	Input.action_press("move_right", upper_strength)
	_check(is_equal_approx(Input.get_axis("move_left","move_right"), upper_strength), "The actual input axis matches the tested strength")
	_release()
	var ids: Array[String] = []
	for node in stage.get_node("ScrollBranch").get_children():
		if node is Area2D:
			_check(node.stage_id == "tower" and not ids.has(node.scroll_id), "Every actual native tower scroll belongs to this stage and has a unique ID")
			ids.append(node.scroll_id)
	_check(ids.size() == 8 and root.get_node("CollectionProgress").TOTALS["tower"] == 8, "The displayed total equals all eight actual placements")

func _check(ok: bool, message: String) -> void:
	checks += 1
	super._check(ok, message)
	if not ok:
		print("FOURTH_FAIL cp=",stage.checkpoint_index+1," p=",player.position," v=",player.velocity," actions=",actions," respawns=",respawns," held=",player.get_held_object()," wall=",player.is_on_wall()," grab=",player.is_wall_grabbing()," floor=",player.is_on_floor()," inputGrab=",Input.is_action_pressed("wall_grab")," inputUp=",Input.is_action_pressed("move_up")," stamina=",player.get_wall_stamina())
		quit(1)


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not is_instance_valid(player): continue
		last_position = player.position
		last_velocity = player.velocity
		if not monitor_view or stage.checkpoint_index < 19: continue
		observed_frames += 1
		if player.is_wall_grabbing() and player.velocity.y<0: climb_frames += 1
		if stage.checkpoint_index==23 and player.get_held_object()==stage.get_node("Items/Fourth24Parachute") and player._winds.has(stage.get_node("Items/Fourth24Wind").get_instance_id()) and not player.is_dashing() and player.velocity.y<0: wind_force_frames += 1
		var bodies: Array[CollisionShape2D] = [player.get_node("CollisionShape2D")]
		var held: Grabbable = player.get_held_object()
		if held != null: bodies.append(held.collider)
		var panels: Array[Control] = [stage.get_node("HUD/Info"),stage.get_node("HUD/PauseButton")]
		var hint: Control = stage.get_node("HUD/Hint")
		if hint.visible: panels.append(hint)
		var completion = stage.get_node("HUD/Completion")
		if completion.card.visible: panels.append(completion.card)
		for shape in bodies:
			var bounds: Rect2 = shape.get_global_transform_with_canvas() * shape.shape.get_rect()
			_check(root.get_visible_rect().encloses(bounds),"The entire native player and held object remain inside the viewport: "+shape.get_parent().name)
			for panel in panels:
				if panel.get_global_rect().intersects(bounds): print("FOURTH_NATIVE_HUD_FAIL body=",shape.get_parent().name," bounds=",bounds," panel=",panel.name," rect=",panel.get_global_rect()," camera=",stage.camera.position)
				_check(not panel.get_global_rect().intersects(bounds),"The native body remains outside visible HUD panels: "+panel.name)


func _fourth_view(phase: String) -> void:
	if phase.ends_with("_entry"):
		_horizontal(player.position.x)
		await _step(18)
	var landings := {
		"20_entry":["Fourth20Wall",-400], "20_wall":["Fourth20AirRest",-350], "20_gap":["Fourth21Checkpoint",600],
		"21_entry":["Fourth21Rest",100], "21_rest":["Fourth22Checkpoint",150], "22_spring":["Fourth23Checkpoint",1900],
		"23_entry":["Fourth23Rest",1300], "23_wall_top":["Fourth24Checkpoint",560], "24_wind_top":["Fourth24UpperRest",570], "24_upper":["Fourth24LowerRest",-780],
		"24_lower":["Fourth25Checkpoint",-1350], "25_refill":["FourthSummit",-1200]}
	if landings.has(phase):
		var destination: Array = landings[phase]
		var shape: CollisionShape2D = stage.get_node("Terrain/"+destination[0]+"/Collision")
		var face := shape.shape.get_rect()
		face.position.x = clampf(float(destination[1])-shape.global_position.x-80,face.position.x,face.end.x-160)
		face.size = Vector2(160,minf(16,face.size.y))
		_check_next_visible(shape.get_global_transform_with_canvas()*face,phase+" landing face")
	if phase in ["22_entry","25_entry"]:
		var shape: CollisionShape2D = stage.get_node("Items/Fourth"+("22" if phase=="22_entry" else "25")+"Bumper/CollisionShape2D")
		_check_next_visible(shape.get_global_transform_with_canvas()*shape.shape.get_rect(),phase+" first bumper")
	if phase=="25_refill":
		var point: Marker2D=stage.checkpoints.get_child(25)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The actual next CP26 flag")
	if phase=="19_wind_b":
		var point: Marker2D=stage.checkpoints.get_child(19)
		_check_next_visible(point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56),"The old final wind shows the real CP20 flag")
	if phase=="22_spring":
		var point: Marker2D=stage.checkpoints.get_child(22)
		var flag: Rect2=point.get_global_transform_with_canvas()*Rect2(-108,-52,48,56)
		var object: Grabbable=stage.get_node("Items/Fourth23Companion")
		var bounds: Rect2=object.collider.get_global_transform_with_canvas()*object.collider.shape.get_rect()
		print("FOURTH_NEXT_FLAG ",flag," next_companion=",bounds)
		_check_next_visible(flag,"The actual next CP23 flag before the second spring")
		_check_next_visible(bounds,"The entire native companion at the next checkpoint")
	if not OS.get_cmdline_user_args().has("--screenshots"):return
	if phase=="25_checkpoint":
		_horizontal(player.position.x)
		await _step(18)
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-fourth")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/tower-fourth/%s%s.png"%[phase,"_hints" if stage.hints_visible else ""])==OK,"Save the actual native route frame")

func _check_next_visible(bounds: Rect2, label: String) -> void:
	if not root.get_visible_rect().encloses(bounds): print("FOURTH_DESTINATION_BOUNDS ",label," ",bounds," p=",player.position," camera=",stage.camera.position)
	_check(root.get_visible_rect().encloses(bounds),"The next real destination is visible before taking off: "+label)
	for path in ["HUD/Info","HUD/Hint","HUD/PauseButton"]:
		var panel: Control=stage.get_node(path)
		if panel.visible:
			if panel.get_global_rect().intersects(bounds):print("FOURTH_DESTINATION_HUD ",label," ",bounds," panel=",panel.name," ",panel.get_global_rect())
			_check(not panel.get_global_rect().intersects(bounds),"The next real destination is outside visible HUD: "+label)

func _parachute_view(phase: String) -> void:
	if phase=="wind_b":await _fourth_view("19_wind_b")
