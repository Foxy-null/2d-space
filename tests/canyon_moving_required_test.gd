extends "res://tests/canyon_applications_required_test.gd"

func _run() -> void:
	_isolate_collection()
	progress=root.get_node("CollectionProgress")
	var mode:="direct"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):mode=arg.trim_prefix("--case=")
	for aim in NATIVE_AIMS:
		for delay in [12,20,28]:
			var room:=await _comparison_setup(33)
			room.get_node("Items/Boots").monitoring=false
			if mode=="spring":
				room.get_node("Items/Spring").monitoring=false
				await _pulse("jump")
				for frame in delay:
					_entry_horizontal(400)
					await _step()
			else:
				await _moving_first(1.0)
				if failed:return
				if mode=="boots":
					await _land_at_wide_rest()
					for frame in 240:
						_entry_horizontal(1940)
						await _step()
						if absf(_x()-1940)<5 and absf(player.velocity.x)<15:break
					_check(player.is_on_floor(),"The Boot omission starts on the real floor beyond the curtain")
					await _pulse("jump")
				for frame in delay:
					_entry_horizontal(1950)
					await _step()
			if player.is_dash_ready():await _actual_dash(aim)
			for frame in 600:
				if respawns>0 or stage.next_bumper>3 or stage.completed:break
				if mode=="spring":_entry_horizontal(400)
				else:_entry_horizontal(1950)
				await _step()
			_check(action_events.jump==(0 if mode=="direct" else 1),"The finite omission executes the actual Spring or ordinary Jump takeoff")
			_check(action_events.air_jump==0,"The finite omission grants no Boot jump")
			if mode=="spring":_check(action_events.bumper==0,"The tested bare Jump and Dash cannot reach the first reflection")
			else:_check(action_events.fourth==0,"The tested direct or bare-rest jump cannot reach the fourth reflection without Boot")
			_finish_comparison(33,"The real omitted resource")
			if failed:return
			attempts+=1
	_release_inputs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("CANYON_MOVING_REQUIRED_TEST_OK case=",mode," attempts=",attempts," checks=",checks)
	quit()
