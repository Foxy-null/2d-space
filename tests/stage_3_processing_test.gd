extends SceneTree

var failed := false
var checks := 0
var stage: Node2D
var progress: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://stage_3_processing_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	await _spike_drawing()
	await _room_updates()
	await _native_scroll_transfer()
	for index in stage.rooms.get_child_count():
		stage._set_room(index, false)
		stage.player.respawn()
		await _step(3)
		var active_rooms: Array = stage.rooms.get_children().filter(func(room): return room.can_process())
		_check(active_rooms == [stage.rooms.get_child(index)], "Only the current room updates: room%d" % [index + 1])
	current_scene.queue_free()
	await _step(3)
	if FileAccess.file_exists(progress.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("STAGE_3_PROCESSING_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _spike_drawing() -> void:
	var draws := [0, 0]
	var static_spike := SpikeBlock.new()
	static_spike.travel = Vector2.ZERO
	static_spike.ceiling_strip = true
	static_spike.strip_half_width = 60
	static_spike.stage_group = &"stage_three"
	static_spike.position = Vector2(72, 400)
	static_spike.draw.connect(func(): draws[0] += 1)
	stage.rooms.get_child(0).add_child(static_spike)
	var moving_spike := SpikeBlock.new()
	moving_spike.travel = Vector2(64, 0)
	moving_spike.stage_group = &"stage_three"
	moving_spike.position = Vector2(1000, 300)
	moving_spike.draw.connect(func(): draws[1] += 1)
	stage.rooms.get_child(0).add_child(moving_spike)
	await _step(4)
	_check(draws[0] > 0 and draws[1] > 0, "Both spike variants draw initially")
	var static_draws: int = draws[0]
	var moving_draws: int = draws[1]
	var moving_position := moving_spike.position
	await _step(30)
	_check(draws[0] == static_draws, "Static spike strips reuse their cached drawing")
	_check(draws[1] > moving_draws and moving_spike.position != moving_position, "Moving spikes retain their motion and redrawn track")
	var hits := [0]
	static_spike.player_hit.connect(func(): hits[0] += 1)
	stage.player.global_position = static_spike.global_position
	await _step(5)
	_check(hits[0] == 1 and stage.player.position.distance_to(stage.player._spawn_position) < 5, "Cached static spikes still kill and respawn the player exactly once")
	_check(draws[0] > static_draws, "Respawn explicitly refreshes the static spike drawing")
	static_spike.queue_free()
	moving_spike.queue_free()
	await _step(2)


func _room_updates() -> void:
	var gate: Area2D = stage.rooms.get_child(4).get_node("UpGate")
	var wind: Area2D = stage.rooms.get_child(4).get_node("Headwind")
	var gate_position := gate.position
	var wind_time: float = wind._time
	await _step(20)
	_check(gate.position == gate_position and wind._time == wind_time, "Inactive moving gates and wind animations stop updating")
	_check(not PhysicsServer2D.area_get_space(gate.get_rid()).is_valid(), "Inactive room areas leave the physics space")
	stage._set_room(4, false)
	stage.player.respawn()
	await _step(20)
	_check(gate.position != gate_position and wind._time != wind_time, "Entering a room resumes its gate and wind")
	_check(PhysicsServer2D.area_get_space(gate.get_rid()).is_valid(), "Entering a room restores its physics areas")
	gate_position = gate.position
	wind_time = wind._time
	paused = true
	await _step(10)
	_check(gate.position == gate_position and wind._time == wind_time, "The active room still respects pause")
	paused = false
	stage._set_room(0, false)
	stage.player.respawn()
	await _step(4)
	_check(not PhysicsServer2D.area_get_space(gate.get_rid()).is_valid(), "Leaving a room suspends its physics areas again")


func _native_scroll_transfer() -> void:
	var scroll: Area2D
	for area in stage.rooms.get_child(0).find_children("*", "Area2D", true, false):
		if area.get_script() == load("res://scripts/scroll_collectible.gd"):
			scroll = area
			break
	_check(scroll != null, "Use a native scroll nested inside the first room")
	if scroll == null:
		return
	scroll.global_position = stage.player.global_position
	await _step(3)
	_check(scroll._follower == stage.player and not scroll._secured, "A real overlap starts the native pending scroll")
	stage._on_arrival(0)
	stage._transition_to(1)
	_check(not stage.rooms.get_child(0).can_process() and scroll.can_process() and scroll.is_visible_in_tree(), "A pending scroll stays active and visible after its room stops")
	await _step(80)
	_check(scroll._secured and progress.has_scroll(scroll.stage_id, scroll.scroll_id), "The native scroll secures on the next room's safe landing")
	stage._transition_to(0)
	await _step(30)
	_check(stage.room_index == 0 and stage.cleared.has(0) and stage.rooms.get_child(0).can_process(), "Backtracking restores the cleared room")
	_check(stage.rooms.get_child(0).get_node("ExitBarrier/Collision").disabled, "Backtracking preserves the opened exit")


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
