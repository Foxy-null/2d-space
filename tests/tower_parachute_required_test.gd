extends "res://tests/tower_parachute_route_test.gd"

var attempts := 0
var actual_steps := 0
var carried := 0

const KINDS := ["parachute","wind_a","spring","wind_b","direct_wind_b","carried_companion","parachute_step","companion_step"]

func _run() -> void:
	progress = root.get_node("CollectionProgress")
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	checks += 1
	if not (only == "" or only == "transport" or only in KINDS):
		push_error("Unknown omission group: " + only)
		quit(1)
		return
	if only == "transport":
		await _fresh_para()
		monitor_view = false
		await _transport_companion()
		if failed: return
	else:
		for kind in KINDS:
			if only != "" and kind != only: continue
			for direction in [Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]:
				for timing in [16,24]:
					await _probe(kind,direction,timing)
					if failed: return
			print("TOWER_PARACHUTE_REQUIRED ",kind,": 16 directions/timings")
	_release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	current_scene.queue_free()
	await _step(5)
	OS.delay_msec(100)
	print("TOWER_PARACHUTE_REQUIRED_TEST_OK (",checks," checks, ",attempts," routes, ",actual_steps," actual steps, ",carried," actual transports; up-Dash ends, left input 1f, throw)")
	quit()

func _probe(kind: String, direction: Vector2, timing: int) -> void:
	await _fresh_para()
	monitor_view = false
	if kind in ["carried_companion","companion_step"]:
		await _transport_companion()
		if failed: return
	elif kind != "parachute":
		await _more_walk(-550)
		await _more_grab("Parachute19")
	if kind in ["spring","wind_b","parachute_step"]:
		await _wind_rise(-200,-23280)
		_horizontal(700)
		await _land_on(700,-22926,400)
		if kind=="wind_b": stage.get_node("Items/ParachuteWindB").wind_acceleration=0
		else: stage.get_node("Items/ParachuteSpring").monitoring=false
		await _more_walk(800 if kind=="wind_b" else (860 if kind=="parachute_step" else 900))
	elif kind=="direct_wind_b":
		stage.get_node("Items/ParachuteSpring").monitoring=false
		await _wind_rise(-200,-23280)
	else:
		if kind=="wind_a": stage.get_node("Items/ParachuteWindA").wind_acceleration=0
		if kind in ["carried_companion","companion_step"]:
			await _more_walk(-450)
		else:
			_horizontal(-200)
			for frame in 120:
				await _step()
				if absf(player.position.x+200)<10: break
	if kind in ["parachute_step","companion_step"]:
		var supported_object := await _stand_on_real_object()
		if failed: return
		Input.action_press("wall_grab")
		await _upper_pulse("jump")
		_check(player.get_held_object()==supported_object and player.velocity.y < -100,"A real simultaneous pickup/jump starts from the same physical support")
	elif kind=="wind_b":
		_horizontal(900)
		await _await_launch_long()
	elif kind!="direct_wind_b": await _upper_pulse("jump")
	if failed: return
	var before := respawns
	var reached := false
	var extra := false
	for frame in 360:
		if not player.is_dashing():
			Input.action_release("move_up")
			Input.action_release("move_down")
			_horizontal(900 if kind in ["spring","parachute_step","direct_wind_b"] else (-100 if kind=="wind_b" else 700))
		if frame>=20 and not extra and not player.is_dashing() and player.get_held_object()!=null and player.get_available_extra_jump_count()>0:
			await _upper_pulse("jump")
			extra=true
		if frame==timing:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if direction.x!=0: Input.action_press("move_right" if direction.x>0 else "move_left")
			if direction.y!=0: Input.action_press("move_down" if direction.y>0 else "move_up")
			await _upper_pulse("dash")
		await _step()
		if kind in ["spring","parachute_step","direct_wind_b"]: reached=reached or stage.get_node("Items/ParachuteWindB").overlaps_body(player)
		elif kind=="wind_b": reached=reached or stage.checkpoint_index>=19
		else: reached=reached or (player.is_on_floor() and player.position.y<=-22923)
		if respawns>before: break
	_check(not reached and not stage.completed,"Omitting %s cannot reach its real next resource/landing: direction=%s timing=%d pos=%s" % [kind,direction,timing,player.position])
	attempts+=1
	_release()

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


func _transport_companion() -> void:
	# The fixture starts at CP18; all transport after that point is actual input.
	stage._set_checkpoint(17)
	player.respawn()
	await _step(8)
	respawns = 0
	await _more_grab("More18Companion")
	await _more_boot(1200,"More18Boot",Vector2(800,-20960))
	await _more_walk(380)
	if failed: return
	var companion: Grabbable = player.get_held_object()
	_check(companion == stage.get_node("Items/More18Companion"),"The transport uses the actual preceding room's companion")
	await _upper_pulse("jump")
	await _step(20)
	await _upper_pulse("jump")
	await _step(20)
	await _upper_dash()
	for frame in 20:
		await _step()
		if not player.is_dashing(): break
	Input.action_release("move_up")
	Input.action_press("move_left")
	await _step()
	var before_throw := player.velocity
	Input.action_release("wall_grab")
	await _step()
	_check(player.get_held_object()==null and before_throw.x < 0 and before_throw.y < -500 and companion.linear_velocity.x < 0 and companion.linear_velocity.y < -900,"One real lateral frame after a pure up-Dash throws the companion up and across the wall")
	# Wait until the thrown object clears grab range before holding the wall.
	await _step(10)
	Input.action_press("wall_grab")
	Input.action_press("move_up")
	for frame in 300:
		_horizontal(300)
		await _step()
		if player.is_on_floor() and player.position.y < -21560: break
	_check(player.is_on_floor() and player.position.y < -21560 and player.get_held_object()==null and respawns==0,"The player really climbs the 600px wall while the thrown companion is free")
	for frame in 180:
		_horizontal(companion.position.x)
		Input.action_release("move_up")
		if frame%3 == 0: Input.action_release("wall_grab")
		else: Input.action_press("wall_grab")
		await _step()
		if player.get_held_object()==companion: break
	_check(player.get_held_object()==companion,"The real descending companion is recovered after the unheld wall climb")
	if failed: return
	Input.action_press("wall_grab")
	_horizontal(230)
	await _await_launch_long()
	_horizontal(-50)
	await _step(upper_jump_delay+28)
	await _upper_dash()
	for frame in 90:
		if not player.is_dashing(): _horizontal(-50)
		await _step()
		if not stage.get_node("Items/More18Dash").visible and not player.is_dashing(): break
	_check(not stage.get_node("Items/More18Dash").visible,"The carried route really reaches the old final refill")
	await _upper_dash()
	await _land_on(-100,-22346,240)
	await _more_walk(-400)
	_check(stage.checkpoint_index==18 and player.get_held_object()==companion and respawns==0,"Spring and real refilled Dash transport the same companion continuously to CP19")
	carried += 1
