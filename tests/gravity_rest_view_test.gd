extends "res://tests/gravity_third_route_test.gd"

const HUD_PATHS := ["HUD/Margin/Panel", "HUD/PauseButton", "HUD/Status"]
var observe_view := false
var observe_course := false


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_rest_view_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for strength in [1.0, 0.8]:
		for hints in [false, true]:
			third_strength = strength
			para_strength = strength
			await _fresh(16)
			stage.set_hints_visible(hints)
			observe_course = true
			observe_view = true
			await _third_entry(16)
			_check(respawns == 0 and player.is_on_floor() and player.gravity_direction == -1, "The real entrance reaches the inverted ceiling and rests safely for three seconds")
			_rest_view()
			if failed: return
			observe_view = false
			await _retry()
			_check(stage.room_index == 16 and not stage.cleared.has(16) and player.gravity_direction == 1 and player.is_dash_ready() and stage.hints_visible == hints, "Actual R restores the normal entrance while keeping the selected hint state")
			observe_view = true
			await _third_entry(16)
			_rest_view()
			if failed: return
			await _third_vertical(Vector2.DOWN, 20, 1)
			await _third_goal()
			_check(stage.cleared.has(16) and respawns == 1 and actions.get("dash", 0) == 2 and actions.get("dash_crystal", 0) == 1 and flips == [-1, 1, -1, 1], "The retry and original two descending Dashes, real Crystal and Down contact reach the actual arrival")
			observe_view = false
			await _cross_room_boundary()
			_check(stage.room_index == 17 and not stage.transitioning and player.controls_enabled, "The actual arrival still opens the exit and reaches the next controllable room")
			_check(progress.get_count("gravity") == 0, "The main course leaves optional scrolls untouched")
			observe_course = false
			print("GRAVITY_REST_VIEW strength=", strength, " hints=", hints)
	_release_inputs()
	current_scene.queue_free()
	await _step(5)
	if FileAccess.file_exists(progress.save_path): DirAccess.remove_absolute(progress.save_path)
	print("GRAVITY_REST_VIEW_TEST_%s checks=%d" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _rest_view() -> void:
	var room: Node2D = stage.rooms.get_child(16)
	_check(stage.get_node("HUD/Status").position.y > 360, "The HUD reaches its original lower layout before the real ceiling rest")
	for path in ["DownGate", "DownGate/Arrow", "DashCrystal"]:
		_check(room.get_node(path).is_visible_in_tree(), "The next real action remains visible with either hint state: " + path)
	# Include the gate's 13px ink stroke and the Crystal's drawn side marks.
	for entry in [["DownGate/CollisionShape2D", 7.0], ["DashCrystal/CollisionShape2D", 12.0]]:
		var shape: CollisionShape2D = room.get_node(entry[0])
		_bounds(shape.get_global_transform_with_canvas() * shape.shape.get_rect().grow(entry[1]), "The actual next " + entry[0])
		if failed: return
	var arrow: Control = room.get_node("DownGate/Arrow")
	_bounds(arrow.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, arrow.size).grow(5), "The complete Down arrow and its outline")
	_player_view()


func _player_view() -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	_bounds(shape.get_global_transform_with_canvas() * shape.shape.get_rect(), "The real player collision")
	var sprite: AnimatedSprite2D = player.get_node("Visuals/Body")
	_check(sprite.is_visible_in_tree(), "The real player artwork remains visible")
	var size := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
	_bounds(sprite.get_global_transform_with_canvas() * Rect2(-size * 0.5, size), "The complete real player artwork")


func _bounds(bounds: Rect2, label: String) -> void:
	_check(root.get_visible_rect().grow(-4).encloses(bounds), label + " has four pixels of viewport clearance: " + str(bounds))
	if failed: return
	for path in HUD_PATHS:
		var panel: Control = stage.get_node(path)
		_check(not panel.is_visible_in_tree() or not panel.get_global_rect().grow(4).intersects(bounds), label + " has four pixels of clearance from visible " + path)


func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if not observe_course or not is_instance_valid(stage) or stage.transitioning or stage.room_index != 16: continue
		if observe_view: _player_view()
		if player.gravity_direction == 1:
			var room: Node2D = stage.rooms.get_child(16)
			var original_y := clampf(player.position.y - 80, float(room.get_meta("room_top", 0.0)) + 360, float(room.get_meta("room_bottom", 720.0)) - 360)
			_check(is_equal_approx(stage._camera_position().y, original_y), "Normal gravity keeps the original camera target during entry, R and the actual descent")
