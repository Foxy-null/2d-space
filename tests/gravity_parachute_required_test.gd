extends "res://tests/gravity_parachute_route_test.gd"

const AIMS := [Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1),Vector2.DOWN,Vector2(1,1)]
var comparisons := 0


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_para_required_%d.cfg"%OS.get_process_id()
	progress._collected.clear()
	var only:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only=arg.trim_prefix("--only=")
	if only!="":
		if only=="refill": await _refill_comparisons()
		else: await _extras(only)
		await _required_finish()
		return
	for index in [21,22,23,24]:
		for missing in ["parachute","wind"]:
			for aim in AIMS:
				await _fresh_para(index)
				monitor_view = false
				if index==22:
					await _para_start(index)
					_release_inputs()
				else:
					if missing!="parachute": await _para_grab()
				var room: Node2D=stage.rooms.get_child(index)
				if missing=="parachute":
					room.get_node("Parachute").queue_free()
					await _step(2)
				else:
					room.get_node("InvertedUpdraft" if index==22 else "Updraft").wind_acceleration = 0
				var target: float = [820,1400,1550,820][index-21]
				var first_rest: float = [900,900,900,700][index-21]
				await _finite_attempt(target,first_rest,aim,index==22)
				_check(not stage.cleared.has(index),"Omitting %s cannot clear room %d for aim %s"%[missing,index+1,aim])
				comparisons+=1
				print("GRAVITY_PARA_REQUIRED room=%d missing=%s aim=%s deaths=%d"%[index+1,missing,aim,respawns])
	await _refill_comparisons()
	await _extras("all")
	await _required_finish()


func _refill_comparisons() -> void:
	for index in [23,24]:
		for aim in AIMS:
			await _fresh_para(index)
			monitor_view=false
			await _para_start(index)
			await _para_flip_rest(index)
			if index==24: await _para_deep_rest(index)
			stage.rooms.get_child(index).get_node("DashCrystal").queue_free()
			await _step(2)
			var takeoff:=1100.0 if index==23 else 1880.0
			var landing:=900.0 if index==23 else 2000.0
			await _para_walk(takeoff)
			_para_drive(takeoff,true)
			await _jump()
			await _step(para_gap)
			await _para_dash(aim)
			var deepest:=player.position.y
			for frame in 440:
				# Keep the favorable gate alignment; if Down is reached, steer onto the real exit floor.
				_para_drive(takeoff if player.gravity_direction<0 else landing,true)
				if frame%20==0 and (player.is_on_floor() or player.is_on_wall()): await _jump()
				await _step()
				if respawns>0: break
				deepest=maxf(deepest,player.position.y)
				_check(player.gravity_direction<0 and not stage.cleared.has(index),"Without the refill, a single representative Dash cannot reach the actual Down gate or arrival")
			comparisons+=1
			print("GRAVITY_PARA_REQUIRED room=%d missing=refill aim=%s deaths=%d deepest=%.2f"%[index+1,aim,respawns,deepest])


func _required_finish() -> void:
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_PARACHUTE_REQUIRED_TEST_%s %d comparisons %d checks"%["FAILED" if failed else "OK",comparisons,checks])
	quit(1 if failed else 0)


func _finite_attempt(target: float,support_y: float,aim: Vector2,inverted: bool) -> void:
	var before:=respawns
	_para_drive(target,true)
	await _jump()
	await _step(para_gap)
	await _para_dash(aim)
	for frame in 440:
		_para_drive(target,true)
		if player.get_held_object()==null: Input.action_press("move_down" if player.gravity_direction<0 else "move_up")
		if frame%20==0 and (player.is_on_floor() or player.is_on_wall()): await _jump()
		await _step()
		if respawns>before: break
		var landed := player.is_on_floor() and absf(player.position.y-(support_y+(26 if inverted else -26)))<4 and absf(_para_x()-target)<100
		_check(not landed,"The representative must not land beyond the missing mechanic (aim=%s, target=%.1f)"%[aim,target])
		_check(not stage.cleared.has(stage.room_index),"A representative must not reach the arrival")


func _extras(only: String) -> void:
	if only in ["all","regressions"]:
		await _under_rest_regression()
		await _direct_regression()
	if only in ["all","steps"]:
		for index in [21,23,24]:
			for aim in AIMS: await _real_step(index,aim)
	if only in ["all","second_wind"]:
		for missing in ["parachute","wind"]:
			for aim in AIMS:
				await _fresh_para(24)
				monitor_view=false
				await _para_start(24)
				await _para_flip_rest(24)
				var room: Node2D=stage.rooms.get_child(24)
				if missing=="parachute":
					room.get_node("Parachute").queue_free()
					await _step(2)
				else:room.get_node("InvertedUpdraft").wind_acceleration=0
				await _finite_attempt(1800,1000,aim,true)
				comparisons+=1
				print("GRAVITY_PARA_REQUIRED room=25 missing=second_%s aim=%s deaths=%d"%[missing,aim,respawns])


func _under_rest_regression() -> void:
	await _fresh_para(23)
	monitor_view=false
	await _para_start(23)
	var hits:=[0]
	stage.rooms.get_child(23).get_node("RestUndersideSpikes").player_hit.connect(func():hits[0]+=1)
	_para_drive(1370)
	await _until(func():return player.gravity_direction==-1,180,"Enter Up before the ceiling landing")
	for frame in 6:
		_para_drive(1370)
		await _step()
	await _para_dash(Vector2.DOWN)
	for frame in 240:
		_para_drive(1460)
		await _step()
		if respawns>0:break
	_check(respawns>0 and hits[0]>0 and actions.get("crystal",0)==0 and not stage.cleared.has(23),"The formerly successful underside refuel actually hits visible native spikes")
	comparisons+=1
	print("GRAVITY_PARA_UNDER_REST_BLOCKED actual_hits=",hits[0])


func _direct_regression() -> void:
	await _fresh_para(24)
	monitor_view=false
	await _para_grab()
	var hits:=[0]
	stage.rooms.get_child(24).get_node("LowerWallSpikes").player_hit.connect(func():hits[0]+=1)
	_para_drive(650)
	await _until(func():return _para_x()>640,180,"Approach below the first high rest as in the actual bypass")
	await _para_dash(Vector2.RIGHT)
	for frame in 360:
		_para_drive(2500,true)
		if player.is_on_floor() and player.is_on_wall():await _jump()
		await _step()
		if respawns>0 or stage.cleared.has(24):break
	_check(respawns>0 and hits[0]>0 and not stage.cleared.has(24),"The formerly successful zero-flip direct glide actually hits the visible lower bulkhead spikes")
	comparisons+=1
	print("GRAVITY_PARA_DIRECT_BLOCKED actual_hits=",hits[0])


func _real_step(index: int,aim: Vector2) -> void:
	await _fresh_para(index)
	monitor_view=false
	var room:Node2D=stage.rooms.get_child(index)
	room.get_node("Updraft").wind_acceleration=0
	var creature:Grabbable=room.get_node("Parachute")
	await _para_walk(creature.position.x+(-100 if _para_x()<creature.position.x else 100))
	_para_drive(creature.position.x)
	await _jump()
	var supported:=false
	for frame in 180:
		_para_drive(creature.position.x)
		await _step()
		for contact in player.get_slide_collision_count():
			var collision:=player.get_slide_collision(contact)
			if collision.get_collider()==creature and collision.get_normal().dot(Vector2.UP)>0.8:supported=true
		if supported:break
	_check(supported and player.is_on_floor(),"Prepare an actual physical Parachute support before comparing the grab/jump step")
	Input.action_press("wall_grab")
	await _finite_attempt(1550 if index==23 else 820,700 if index==24 else 900,aim,false)
	_check(not stage.cleared.has(index),"The real object step does not replace the missing updraft")
	comparisons+=1
	print("GRAVITY_PARA_REAL_STEP room=%d actual_support=%s aim=%s"%[index+1,supported,aim])
