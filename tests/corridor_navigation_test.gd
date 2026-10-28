extends "res://tests/corridor_sixth_route_test.gd"

const LEFT_ROOMS := [25, 28, 31, 34]


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://corridor_navigation_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	await _new_stage()
	await _enter(0)
	_check(player.facing_direction == 1, "A right-going entrance initially faces its course")
	var left_rooms: Array[int] = []
	for room in stage.rooms.get_children():
		if room.travel_direction == -1: left_rooms.append(room.get_index())
	_check(left_rooms == LEFT_ROOMS, "The regression covers every left-going companion room")
	for strength in [1.0, 0.8]:
		for index in LEFT_ROOMS:
			await _entrance(index, strength)
			if failed: return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	await _fifth_cleanup()
	print("CORRIDOR_NAVIGATION_TEST_OK checks=", checks)
	quit()


func _entrance(index: int, strength: float) -> void:
	await _new_stage()
	await _enter(index)
	stage.set_hints_visible(false)
	var room: Node2D = stage.rooms.get_child(index)
	var facing: int = player.facing_direction
	var companion: Grabbable = room.get_node("Items/JumpCreature")
	_hold()
	await step(2)
	_check(player.get_held_object() == companion, "Grab this entrance's actual companion")
	if strength == 1.0: await _entrance_capture("room%d_entrance" % [index + 1])
	var before := deaths
	Input.action_press("move_right", strength)
	_check(is_equal_approx(Input.get_axis("move_left", "move_right"), strength), "The mistaken entrance input uses the actual reported strength")
	await step(120)
	_check(deaths == before and stage.room_index == index and player.get_held_object() == companion, "Holding right retains the companion without a retry or transfer: room%d strength=%.1f retries=%d" % [index + 1, strength, deaths - before])
	if failed: return
	_check(player.is_on_floor() and player.is_on_wall() and player.get_wall_normal().x < -0.8, "The entrance's back side is a solid wall")
	_check(facing == room.travel_direction, "The entrance initially faces its course")
	var sprite: AnimatedSprite2D = companion.get_node("Visuals/Body")
	var size := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
	var artwork: Rect2 = sprite.global_transform * Rect2(-size * 0.5, size)
	var spike: SpikeBlock = room.get_node("Hazards/LeftEdgeSpikes")
	var extent := spike.hit_extent()
	var hazard: Rect2 = spike.global_transform * Rect2(-extent, extent * 2)
	_check(artwork.position.y - hazard.end.y >= 8, "The full companion artwork, including its ears, has clear space below the upper spikes")
	_check(root.get_visible_rect().encloses(sprite.get_global_transform_with_canvas() * Rect2(-size * 0.5, size)), "The full carried artwork remains inside the viewport")
	print("CORRIDOR_ENTRY_CLEARANCE room=", index + 1, " strength=", strength, " pixels=", artwork.position.y - hazard.end.y)
	if strength == 1.0: await _entrance_capture("room%d_backstop" % [index + 1])
	await _pulse("reset")
	release()
	await step(6)
	_check(deaths == before + 1 and player.position.distance_to(Vector2(room.position.x + room.entrance_x, room.entrance_top - 26)) < 2 and player.facing_direction == room.travel_direction, "R restores the actual entrance and its course-facing direction")
	_hold()
	await step(2)
	_check(player.get_held_object() == companion, "Reclaim the same real companion after R")
	var start := _more_x()
	Input.action_press("move_left", strength)
	for frame in 60:
		await step()
		if start - _more_x() > 60 or deaths > before + 1: break
	_hold()
	_check(start - _more_x() > 60 and deaths == before + 1 and stage.room_index == index and player.get_held_object() == companion, "The real companion can safely restart toward the left course")


func _entrance_capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/corridor-navigation")
	_check(root.get_texture().get_image().save_png("res://docs/screenshots/corridor-navigation/%s.png" % label) == OK, "Save the actual entrance and full carried companion")
