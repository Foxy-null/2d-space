extends "res://tests/tower_fourth_route_test.gd"

const DIRECTIONS := [Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]
const KINDS := ["20_wall","20_refill","21_spring","21_boot","22_launch","22_bumper","22_spring","23_boot","23_companion","23_wall","24_parachute","24_wind","24_boot","24_upper","25_launch","25_bumper","25_refill"]
var attempts := 0
var actual_steps := 0
var actual_transports := 0
var actual_throws := 0

func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected = arg.trim_prefix("--only=")
	for kind in KINDS:
		if selected != "" and selected != kind and not kind.begins_with(selected+"_"): continue
		for timing in [16,24,40]:
			for direction in DIRECTIONS:
				await _missing_fourth(kind,direction,timing)
				if failed:return
		print("FOURTH_REQUIRED kind=",kind," attempts=",attempts)
	if selected in ["", "steps"]:
		for direction in DIRECTIONS:
			await _step_comparison(direction)
			if failed:return
			await _parachute_step(direction)
			if failed:return
	if selected in ["", "throws"]:
		for supported in [false,true]:
			for timing in [16,24,32]:
				for diagonal in [false,true]:
					await _throw_comparison(supported,timing,diagonal)
					if failed:return
	if selected in ["", "old_parachute"]:
		for timing in [16,24]:
			for direction in DIRECTIONS:
				await _old_parachute(direction,timing)
				if failed:return
	if selected in ["", "gap"]:
		for strength in [1.0,0.8]:
			for grace in [0,2,4,6]:
				await _gap_comparison(strength,grace)
				if failed:return
	_check(attempts > 0,"A known finite omission group actually ran")
	_release()
	current_scene.queue_free()
	await _step(3)
	print("TOWER_FOURTH_REQUIRED_TEST_OK checks=",checks," attempts=",attempts," actual_steps=",actual_steps," actual_transports=",actual_transports," actual_throws=",actual_throws)
	quit(1 if failed else 0)

func _missing_fourth(kind: String, direction: Vector2, timing: int) -> void:
	var section := int(kind.split("_")[0])-1
	await _fresh_fourth(section)
	monitor_view = false
	var target := ""
	var airborne := false
	match kind:
		"20_wall":
			player.wall_actions_enabled = false
			await _more_walk(-282)
			target = "Fourth20Wall"
		"20_refill":
			await _more_climb("Fourth20Wall",true)
			_off("Fourth20Dash")
			await _more_walk(-380)
			target = "Fourth20AirRest"
		"21_spring":
			_off("Fourth21Spring")
			await _more_walk(700)
			target = "Fourth21Rest"
		"21_boot":
			_off("Fourth21Boot")
			await _fourth_spring(700,Vector2(100,-25700))
			await _more_walk(-150)
			target = "Fourth22Checkpoint"
		"22_launch", "22_bumper", "22_spring":
			target = "Fourth22Rest"
			if kind == "22_spring":
				await _more_bounce(800,"Fourth22Bumper",Vector2(850,-27280))
				_off("Fourth22Spring")
				await _more_walk(1400)
				target = "Fourth23Checkpoint"
			elif kind == "22_bumper":
				_off("Fourth22Bumper")
				_horizontal(800)
				await _await_launch_long()
				airborne = true
			else:
				_off("Fourth22Launch")
				await _more_walk(800)
		"23_boot", "23_companion", "23_wall":
			target = "Fourth23Rest"
			if kind != "23_companion": await _more_grab("Fourth23Companion")
			if kind == "23_wall":
				await _more_boot(1800,"Fourth23Boot",Vector2(1300,-28420))
				await _more_walk(560)
				player.wall_actions_enabled = false
				target = "Fourth24Checkpoint"
			else:
				if kind == "23_boot": _off("Fourth23Boot")
				await _more_walk(1800)
		"24_parachute", "24_wind", "24_boot", "24_upper":
			target = "Fourth24UpperRest"
			if kind in ["24_boot","24_upper"]:
				_off("Fourth24Boot")
				await _fourth_updraft_rest()
				if kind == "24_boot":
					await _fourth_down_rest()
					await _more_walk(-930)
				else:
					await _more_walk(-350)
				_check(not player.is_air_jump_ready(),"The boot omission never acquires its resource during the legitimate descent")
				target = "Fourth25Checkpoint"
			else:
				if kind == "24_wind":
					await _more_walk(450)
					await _more_grab("Fourth24Parachute")
					stage.get_node("Items/Fourth24Wind").wind_acceleration = 0
				await _more_walk(800)
		"25_launch", "25_bumper", "25_refill":
			target = "Fourth25Rest"
			if kind == "25_refill":
				await _more_bounce(-1700,"Fourth25Bumper",Vector2(-1550,-31780))
				_off("Fourth25Dash")
				await _more_walk(-1450)
				target = "FourthSummit"
			elif kind == "25_bumper":
				_off("Fourth25Bumper")
				_horizontal(-1700)
				await _await_launch_long()
				airborne = true
			else:
				_off("Fourth25Launch")
				await _more_walk(-1700)
	if failed:return
	await _finite_flight(section,_world_floor(target),direction,timing,airborne)
	attempts += 1

func _off(name: String) -> void:
	stage.get_node("Items/"+name).monitoring = false

func _world_floor(name: String) -> Rect2:
	var shape: CollisionShape2D = stage.get_node("Terrain/"+name+"/Collision")
	return shape.global_transform*shape.shape.get_rect()

func _finite_flight(section: int, target: Rect2, direction: Vector2, timing: int, airborne := false) -> void:
	var before := respawns
	if not airborne: await _upper_pulse("jump")
	var started := Engine.get_physics_frames()
	var dashed := false
	var reached := false
	var next_extra := 16
	actions.clear()
	for frame in 360:
		if not player.is_dashing():
			Input.action_release("move_up")
			Input.action_release("move_down")
			_horizontal(target.get_center().x)
		var elapsed := Engine.get_physics_frames()-started
		if elapsed >= next_extra and not player.is_dashing() and player.get_available_extra_jump_count()>0:
			await _upper_pulse("jump")
			next_extra += 16
		if elapsed >= timing and not dashed:
			_release_direction(direction)
			await _upper_pulse("dash")
			dashed = true
		if player.wall_actions_enabled and player.is_on_wall() and frame%12 == 0: await _upper_pulse("jump")
		await _step()
		reached = reached or stage.checkpoint_index > section or stage.completed or (player.is_on_floor() and absf(player.position.y+26-target.position.y)<5 and player.position.x>=target.position.x-18 and player.position.x<=target.end.x+18)
		if reached or respawns>before:break
	_check(not reached,"The omitted real resource cannot be replaced by a finite jump/extra/Dash/wall route: cp=%d target=%s direction=%s timing=%d p=%s actions=%s"%[section+1,target,direction,timing,player.position,actions])
	_release()

func _release_direction(direction: Vector2) -> void:
	for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
	if direction.x != 0:Input.action_press("move_right" if direction.x>0 else "move_left",upper_strength)
	if direction.y != 0:Input.action_press("move_down" if direction.y>0 else "move_up")

func _step_comparison(direction: Vector2) -> void:
	await _fresh_fourth(22)
	monitor_view = false
	await _more_grab("Fourth23Companion")
	await _more_walk(1800)
	_off("Fourth23Boot")
	var object := await _stand_on_real_object()
	Input.action_press("wall_grab")
	await _upper_pulse("jump")
	_check(player.get_held_object()==object and player.velocity.y < -100,"The actual physical support is picked up by the simultaneous normal jump")
	await _finite_flight(22,_world_floor("Fourth23Rest"),direction,20,true)
	attempts += 1

func _old_parachute(direction: Vector2, timing: int) -> void:
	await _fresh_fourth(18)
	monitor_view = false
	await _parachute_course()
	_check(stage.checkpoint_index==19 and respawns==0 and player.get_held_object()==stage.get_node("Items/Parachute19"),"The same actual old parachute is physically transported through its nineteenth course")
	actual_transports += 1
	player.wall_actions_enabled = false
	await _more_walk(-282)
	await _finite_flight(19,_world_floor("Fourth20Wall"),direction,timing)
	attempts += 1

func _parachute_step(direction: Vector2) -> void:
	await _fresh_fourth(23)
	monitor_view = false
	_off("Fourth24Boot")
	await _fourth_updraft_rest()
	await _fourth_down_rest()
	await _more_walk(-930)
	_check(not player.is_air_jump_ready(),"The real parachute support comparison starts without a previously acquired Boot")
	var object := await _stand_on_real_object()
	Input.action_press("wall_grab")
	await _upper_pulse("jump")
	_check(player.get_held_object()==object and player.velocity.y < -100,"The real parachute support is grabbed by the simultaneous normal jump")
	await _finite_flight(23,_world_floor("Fourth25Checkpoint"),direction,20,true)
	attempts += 1

func _throw_comparison(supported: bool,timing: int,diagonal: bool) -> void:
	await _fresh_fourth(22)
	monitor_view = false
	await _more_grab("Fourth23Companion")
	await _more_walk(1800)
	_off("Fourth23Boot")
	var object: Grabbable=player.get_held_object()
	if supported:
		await _stand_on_real_object()
		Input.action_press("wall_grab")
	await _upper_pulse("jump")
	_check(player.get_held_object()==object,"The real throw preparation holds the original companion")
	Input.action_press("move_left")
	await _step(timing)
	await _upper_pulse("jump")
	await _step(timing)
	_release_direction(Vector2(-1,-1) if diagonal else Vector2.UP)
	await _upper_pulse("dash")
	await _step(9)
	_release_direction(Vector2.LEFT)
	await _step(1)
	Input.action_release("wall_grab")
	await _step(1)
	_check(player.get_held_object()==null and object.carrier==null and object.release_physics_frame>=Engine.get_physics_frames()-2,"A real release after the dash throws the same companion")
	actual_throws+=1
	print("FOURTH_ACTUAL_THROW support=",supported," timing=",timing," diagonal=",diagonal," player=",player.position," object=",object.position," velocity=",object.linear_velocity)
	Input.action_press("wall_grab")
	await _finite_flight(22,_world_floor("Fourth23Rest"),Vector2(-1,-1),20,true)
	attempts+=1

func _stand_on_real_object() -> Grabbable:
	var object: Grabbable=player.get_held_object()
	var floor_y:=player.position.y
	Input.action_release("wall_grab")
	await _step(30)
	await _upper_pulse("jump")
	await _step(16)
	await _upper_dash()
	await _step(10)
	Input.action_release("move_up")
	var supported:=false
	for frame in 180:
		_horizontal(object.position.x)
		await _step()
		if player.is_on_floor() and player.position.y<floor_y-35:
			for collision in player.get_slide_collision_count():
				var contact := player.get_slide_collision(collision)
				supported=supported or (contact.get_collider()==object and contact.get_normal().dot(Vector2.UP)>0.8)
			if supported: break
	_check(supported,"The substitute genuinely stands on the dropped native object")
	actual_steps+=1

	return object

func _gap_comparison(strength: float,grace: int) -> void:
	upper_strength=strength
	await _fresh_fourth(19)
	monitor_view=false
	await _more_climb("Fourth20Wall",true)
	await _more_refill("Fourth20Dash",-380,Vector2(-350,-25060))
	await _more_walk(90)
	Input.action_press("move_right",strength)
	for frame in 60:
		await _step()
		if not player.is_on_floor():break
	_check(not player.is_on_floor(),"The ordinary-gap comparison actually runs off the native edge")
	await _step(grace)
	actions.clear()
	await _upper_pulse("jump")
	_check(actions.get("jump",0)==1,"The run-off comparison performs a real coyote jump")
	var reached:=false
	for frame in 240:
		_horizontal(620)
		await _step()
		reached=reached or stage.checkpoint_index>19 or (player.is_on_floor() and absf(player.position.y+25086)<4 and player.position.x>422)
		if reached or respawns>0:break
	_check(not reached and actions.get("dash",0)==0,"A real run-off/coyote jump cannot replace the horizontal gap dash")
	attempts+=1
	print("FOURTH_COYOTE axis=",strength," grace=",grace," reached=",reached," p=",player.position)
	_release()
