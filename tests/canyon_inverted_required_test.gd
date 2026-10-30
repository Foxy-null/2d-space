extends "res://tests/canyon_inverted_route_test.gd"

# Finite ordinary-input comparisons; checkpoint setup is the only positioning fixture.
# --case=spring --room=28 --offset=0 --count=4 keeps each batch short.
const DIRECTIONS := [Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1),Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1)]
var required_events: Dictionary = {}


func _run() -> void:
	_isolate_collection()
	progress = root.get_node("CollectionProgress")
	var mode := "all"
	var selected := 0
	var offset := 0
	var count := 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg.begins_with("--room="): selected = int(arg.trim_prefix("--room="))
		if arg.begins_with("--offset="): offset = int(arg.trim_prefix("--offset="))
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
	_check(mode in ["all","spring","wind","parachute","up"] and offset>=0 and count>0 and selected in [0,28,29,30],"Valid finite comparison selection")
	if failed: return
	var trials := 0
	if mode in ["all","spring"]:
		for index in [27,28,29]:
			if selected>0 and selected!=index+1: continue
			for aim in DIRECTIONS.slice(offset,mini(offset+count,8)):
				await _spring_required(index,aim)
				if failed: return
				trials += 1
	for resource in ["wind","parachute"]:
		if mode not in ["all",resource]: continue
		for delay in [12,20,28,36].slice(offset,mini(offset+count,4)):
			await _wind_required(resource,delay)
			if failed: return
			trials += 1
	if mode in ["all","up"]:
		for lane in [170.0,180.0,190.0].slice(offset,mini(offset+count,3)):
			await _up_captures_prior_bypass(lane)
			if failed: return
			trials += 1
	_check(trials>0,"The selected batch executes real comparisons")
	if failed: return
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_INVERTED_REQUIRED_TEST_OK case=",mode," room=",selected," offset=",offset," trials=",trials," checks=",checks)
	quit()


func _required_setup(index: int) -> Node2D:
	monitor_view = false
	await _setup(index)
	var room: Node2D = stage.rooms.get_child(index)
	required_events = {"up":0,"spring":0,"bumper":0,"jump":0,"dash":0}
	room.get_node("Gates/Up").body_entered.connect(func(body):
		if body==player: required_events["up"] += 1
	)
	room.get_node("Items/Spring").launched.connect(func(body):
		if body==player: required_events["spring"] += 1
	)
	for bumper in stage._bumpers().get_children():
		bumper.launched.connect(func(body):
			if body==player: required_events["bumper"] += 1
		)
	player.movement_action.connect(func(action):
		if required_events.has(action): required_events[action] += 1
	)
	_check(respawns==0 and player.gravity_direction==1,"The live checkpoint starts in normal gravity")
	return room


func _spring_required(index: int, aim: Vector2) -> void:
	var room := await _required_setup(index)
	room.get_node("Items/Spring").monitoring = false
	if index==29:
		Input.action_press("wall_grab")
		await _step()
		_check(player.get_held_object()==room.get_node("Items/Parachute"),"The real entrance parachute is held")
	for frame in 900:
		_entry_horizontal(room.get_node("Gates/Up").position.x)
		await _step()
		if player.gravity_direction<0 or respawns>0: break
	_check(required_events["up"]>0 and player.gravity_direction==-1 and respawns==0,"The enabled Up really contacts and flips the live player")
	if failed: return
	if player.get_held_object()!=null: await _inverted_throw(1.0)
	_release_inputs()
	for frame in 300:
		# Same safe steering as the current base _inverted_launch, without its Spring.
		if index==29: _entry_horizontal(220 if player.position.y>=980 else 110)
		await _step()
		if _supported_by(room.get_node("CeilingEntry")) or respawns>0: break
	_check(_supported_by(room.get_node("CeilingEntry")) and respawns==0,"The actual inverted entry ceiling supports the preparation")
	if failed: return
	for frame in 180:
		_entry_horizontal(room.get_node("Items/Spring").position.x)
		await _step()
		if absf(_x()-room.get_node("Items/Spring").position.x)<8 and absf(player.velocity.x)<40: break
	_check(player.is_on_floor() and required_events["spring"]==0 and respawns==0,"The live grounded fixture has received no Spring launch")
	if failed: return
	var target: float = stage._bumpers().get_child(0).position.x
	_entry_horizontal(target)
	await _pulse("jump")
	for frame in 20:
		_entry_horizontal(target)
		await _step()
	await _required_dash(aim)
	for frame in 480:
		if respawns>0 or required_events["bumper"]>0 or stage.transitioning or stage.completed: break
		_entry_horizontal(target)
		await _step()
	_check(required_events["jump"]==1 and required_events["dash"]==1,"The omission performs its actual Jump and Dash")
	_check(required_events["spring"]==0 and required_events["bumper"]==0,"Without Spring this tested direction reaches no actual reflection")
	_required_no_exit(index)
	print("REQUIRED_SPRING room=",index+1," aim=",aim," events=",required_events," deaths=",respawns)


func _wind_required(resource: String, delay: int) -> void:
	var room := await _required_setup(29)
	var wind: Area2D = room.get_node("Winds/Updraft")
	if resource=="wind":
		wind.wind_acceleration = 0
		Input.action_press("wall_grab")
		await _step()
		_check(player.get_held_object()==room.get_node("Items/Parachute"),"Only wind is omitted; the actual parachute remains held")
	else:
		room.get_node("Items/Parachute").queue_free()
		await _step(2)
		_check(player.get_held_object()==null and wind.wind_acceleration==2400,"Only the parachute is omitted; the actual wind remains enabled")
	for frame in 150:
		_entry_horizontal(room.get_node("Gates/Up").position.x)
		await _step()
		if absf(_x()-room.get_node("Gates/Up").position.x)<8 and absf(player.velocity.x)<40: break
	_check(player.is_on_floor() and respawns==0 and player._winds.has(wind.get_instance_id()),"The live entrance preparation really overlaps its wind")
	if failed: return
	await _pulse("jump")
	for frame in 360:
		if respawns>0 or required_events["up"]>0: break
		_entry_horizontal(room.get_node("Gates/Up").position.x)
		if frame==delay: await _required_dash(Vector2.UP)
		await _step()
	_check(required_events["jump"]==1 and required_events["dash"]==1,"The resource omission really performs Jump and the delayed upward Dash")
	_check(required_events["up"]==0 and required_events["spring"]==0 and required_events["bumper"]==0,"The tested resource omission reaches neither Up nor a launch")
	_required_no_exit(29)
	print("REQUIRED_RESOURCE omitted=",resource," delay=",delay," events=",required_events," deaths=",respawns)


func _up_captures_prior_bypass(lane: float) -> void:
	var room := await _required_setup(29)
	Input.action_press("wall_grab")
	await _step()
	_check(player.get_held_object()==room.get_node("Items/Parachute"),"The former native bypass starts with its real parachute")
	for frame in 900:
		_entry_horizontal(lane)
		await _step()
		if player.position.y<=985 or respawns>0 or player.gravity_direction<0: break
	# These prefixes formerly reached y985 normally, then Up-Dashed into all reflections.
	# Capture occurs before that Dash; do not count them as three executed Dash negatives.
	_check(respawns==0 and required_events["up"]>0 and player.gravity_direction==-1,"The widened real Up captures this former normal-gravity bypass before its Dash point")
	_check(required_events["dash"]==0 and required_events["spring"]==0 and required_events["bumper"]==0,"The capture is a real Up contact before any Dash or launch")
	_required_no_exit(29)
	print("REQUIRED_UP_CAPTURE lane=",lane," p=",Vector2(_x(),player.position.y)," events=",required_events)


func _required_dash(aim: Vector2) -> void:
	_release_inputs()
	if aim.x!=0: Input.action_press("move_right" if aim.x>0 else "move_left")
	if aim.y!=0: Input.action_press("move_down" if aim.y>0 else "move_up")
	_check(player.is_dash_ready(),"The live tested fixture actually has its Dash")
	await _pulse("dash")


func _supported_by(body: Node) -> bool:
	if not player.is_on_floor() or player.gravity_direction!=-1: return false
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		if contact.get_collider()==body and contact.get_normal().dot(Vector2.DOWN)>.8: return true
	return false


func _required_no_exit(index: int) -> void:
	_check(stage.room_index==index and not stage.transitioning and not stage.completed,"The omission reaches no actual room exit or Goal")
	_release_inputs()
