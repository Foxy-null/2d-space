class_name PlayerController
extends CharacterBody2D

signal gravity_changed(is_inverted: bool)
signal resources_changed(stamina: float, stamina_max: float, dash_ready: bool, air_jump_ready: bool)

signal carry_changed(label: String)
signal respawned
signal movement_action(action: String)
signal object_released(object: Grabbable, was_thrown: bool)

@export var wall_actions_enabled := true
@export var dash_enabled := true

@export var grab_range := 60.0
@export var carry_offset := Vector2(0, -48)
@export var throw_move_threshold := 80.0
@export var object_push_speed := 120.0
@export var overlap_separation_speed := 60.0
@export var parachute_launch_grace := 0.15
@export var weight := 1.0
var _held: Grabbable
var _separating_objects: Array[Grabbable] = []
var _parachute_grace_left := 0.0

@export var move_speed := 360.0
@export var ground_acceleration := 2600.0
@export var air_acceleration := 1700.0
@export var gravity_acceleration := 1900.0
@export var max_fall_speed := 900.0
@export var jump_speed := 650.0
@export var wall_jump_speed := 430.0
@export var wall_slide_speed := 170.0
@export var wall_climb_speed := 230.0
@export var wall_stick_speed := 40.0
@export var mantle_distance := 38.0
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.14
@export var wall_stamina_max := 3.0
@export var wall_stamina_climb_rate := 1.0
@export var wall_stamina_rest_rate := 1.0 / 3.0
@export var dash_speed := 900.0
@export var dash_duration := 0.15
@export var dash_end_speed_ratio := 2.0 / 3.0
@export var superdash_window := 0.12

var gravity_direction := 1
var facing_direction := 1
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _spawn_position := Vector2.ZERO
var _wall_grabbing := false
var _last_wall_normal := Vector2.ZERO
var _wall_stamina := 3.0
var _grab_exhausted := false
var _dash_ready := true
var _air_jump_ready := false
var _dash_left := 0.0
var _dash_direction := Vector2.ZERO
var _superdash_left := 0.0
var _superdash_speed := 0.0
var _gravity_tween: Tween
var _ready_color: Color
var _last_resources: Array = []
# Ignore cached contacts immediately after teleporting or changing up_direction.
var _contacts_valid := false
var _motion_velocity := Vector2.ZERO
var _motion_frame := -2
var _impact_velocity := Vector2.ZERO
var _impact_frame := -2
var _winds: Dictionary = {}
var controls_enabled := true

@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	_spawn_position = global_position
	_ready_color = $Visuals/Body.color
	_wall_stamina = wall_stamina_max
	_apply_up_direction()
	_notify_resources()


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	if Input.is_action_just_pressed("reset"):
		respawn()
		return
	var grounded := _contacts_valid and is_on_floor()
	var on_wall := _contacts_valid and is_on_wall()
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO
	var wall_grab_at_start := _wall_grabbing
	_parachute_grace_left = maxf(0.0, _parachute_grace_left - delta)
	_superdash_left = maxf(_superdash_left - delta, 0.0)
	# Dash starts before release so a simultaneous release inherits dash velocity.
	var input_axis := Input.get_axis("move_left", "move_right")
	if absf(input_axis) > 0.1:
		facing_direction = 1 if input_axis > 0.0 else -1
	if dash_enabled and Input.is_action_just_pressed("dash") and _dash_ready and not is_dashing():
		_start_dash(grounded)
	_update_grab_input()
	# Standing still can clear the cached wall contact. Probe both sides so
	# grounded grabbing does not require another horizontal input.
	if wall_actions_enabled and grounded and not on_wall and Input.is_action_pressed("wall_grab") and get_held_object() == null and not is_dashing():
		var collision := KinematicCollision2D.new()
		for side in [facing_direction, -facing_direction]:
			if test_move(global_transform, Vector2(side, 0), collision) and absf(collision.get_normal().x) > 0.5:
				wall_normal = collision.get_normal()
				on_wall = true
				break
	var wants_wall_grab := wall_actions_enabled and Input.is_action_pressed("wall_grab") and on_wall and get_held_object() == null
	if Input.is_action_just_pressed("jump") or (not wants_wall_grab and not is_dashing() and not (dash_enabled and Input.is_action_pressed("dash")) and Input.is_action_just_pressed("jump_up")):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_coyote_left = coyote_time if grounded else maxf(_coyote_left - delta, 0.0)
	if is_dashing():
		_tick_dash(delta, grounded)
	else:
		var acceleration := get_effective_acceleration(grounded)
		velocity.x = move_toward(velocity.x, input_axis * get_effective_move_speed(), acceleration * delta)
		var down := Vector2.DOWN * gravity_direction
		var climb_axis := Input.get_axis("move_up", "move_down")
		_wall_grabbing = wants_wall_grab and not _grab_exhausted
		if _wall_grabbing and not grounded:
			var rate := wall_stamina_climb_rate if climb_axis * gravity_direction < -0.5 else wall_stamina_rest_rate
			_wall_stamina = maxf(_wall_stamina - delta * rate, 0.0)
			if _wall_stamina <= 0.0:
				_grab_exhausted = true
				_wall_grabbing = false
		if _wall_grabbing:
			_last_wall_normal = wall_normal
			velocity = Vector2(-_last_wall_normal.x * wall_stick_speed, climb_axis * wall_climb_speed)
		else:
			velocity += down * gravity_acceleration * delta
			_apply_wind(delta)
			var falling_speed := velocity.dot(down)
			if falling_speed > max_fall_speed:
				velocity += down * (max_fall_speed - falling_speed)
			var pressing_into_wall := on_wall and input_axis * get_wall_normal().x < -0.1
			if wall_actions_enabled and pressing_into_wall and falling_speed > wall_slide_speed:
				velocity += down * (wall_slide_speed - minf(falling_speed, max_fall_speed))
		_apply_parachute()
		_try_jump(grounded, on_wall)
		var was_wall_grabbing := _wall_grabbing
		_move_player()
		if was_wall_grabbing and not is_on_wall() and climb_axis * gravity_direction < -0.5 and Input.is_action_pressed("wall_grab"):
			_try_mantle()
	if not is_on_wall():
		_wall_grabbing = false
	# Use the position after movement/mantling when the wall hold ends.
	if wall_grab_at_start and not _wall_grabbing:
		_update_grab_input()
	_contacts_valid = true
	if is_on_floor() and not grounded:
		_refill_on_landing()
	if global_position.y < -260.0 or global_position.y > 980.0:
		respawn()
	_notify_resources()


func _start_dash(grounded: bool) -> void:
	_impact_frame = -2
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.is_zero_approx():
		_dash_direction = Vector2(facing_direction, 0.0)
	else:
		var angle := roundf(direction.angle() / (PI / 4.0)) * (PI / 4.0)
		_dash_direction = Vector2.RIGHT.rotated(angle).round().normalized()
	_dash_ready = false
	_dash_left = dash_duration
	_wall_grabbing = false
	_superdash_left = 0.0
	_superdash_speed = 0.0
	if grounded and absf(_dash_direction.y) < 0.01:
		_superdash_left = dash_duration + superdash_window
		_superdash_speed = _dash_direction.x * dash_speed * dash_end_speed_ratio
	velocity = _dash_direction * dash_speed
	movement_action.emit("dash")


func _tick_dash(delta: float, grounded: bool) -> void:
	velocity = _dash_direction * dash_speed
	if grounded and _superdash_left > 0.0 and _jump_buffer_left > 0.0:
		_dash_left = 0.0
		_try_jump(true, false)
		_move_player()
		return
	_move_player()
	_dash_left = maxf(_dash_left - delta, 0.0)
	if not is_dashing():
		# Use collision-resolved velocity so a blocked component is not restored.
		velocity *= dash_end_speed_ratio
		if is_on_wall():
			_superdash_left = 0.0
		if grounded and is_on_floor():
			_dash_ready = true


func _try_jump(grounded: bool, on_wall: bool) -> void:
	if _jump_buffer_left <= 0.0:
		return
	if grounded or _coyote_left > 0.0:
		if _superdash_left > 0.0:
			velocity.x = _superdash_speed
			velocity.y = -gravity_direction * jump_speed
			movement_action.emit("superdash")
		else:
			velocity.y = -gravity_direction * get_effective_jump_speed()
			movement_action.emit("jump")
	elif wall_actions_enabled and on_wall:
		velocity = Vector2(get_wall_normal().x * wall_jump_speed, -gravity_direction * jump_speed)
		movement_action.emit("wall_jump")
	elif _air_jump_ready:
		_air_jump_ready = false
		velocity.y = -gravity_direction * get_effective_jump_speed()
		movement_action.emit("air_jump")
	elif get_held_object() != null and _held.consume_extra_jump():
		velocity.y = -gravity_direction * get_effective_jump_speed()
		movement_action.emit("creature_jump")
	else:
		return
	_wall_grabbing = false
	_superdash_left = 0.0
	_consume_jump()


func _refill_on_landing() -> void:
	if get_held_object() != null:
		_held.refill_extra_jump()
	_wall_stamina = wall_stamina_max
	_grab_exhausted = false
	_dash_ready = true


func refill_movement_resources() -> void:
	_dash_ready = true
	_wall_stamina = wall_stamina_max
	_grab_exhausted = false
	_notify_resources()


func launch_from_spring(launch_velocity: Vector2) -> void:
	_parachute_grace_left = parachute_launch_grace
	_dash_left = 0.0
	_dash_direction = Vector2.ZERO
	_superdash_left = 0.0
	_superdash_speed = 0.0
	_wall_grabbing = false
	_consume_jump()
	# Cached floor/wall contacts must not turn this launch into a floor jump/grab.
	_contacts_valid = false
	velocity = launch_velocity
	_motion_velocity = launch_velocity
	_motion_frame = Engine.get_physics_frames()
	_impact_frame = -2
	refill_movement_resources()


func get_environment_velocity() -> Vector2:
	# Area signals arrive after physics synchronization. Preserve incident velocity
	# even if move_and_slide already removed its floor/wall normal component.
	if _impact_frame >= 0 and _impact_frame >= Engine.get_physics_frames() - 2:
		return _impact_velocity
	if _motion_frame >= Engine.get_physics_frames() - 1:
		return _motion_velocity
	return velocity


func _move_player() -> void:
	_separate_overlapping_objects()
	var had_floor := _contacts_valid and is_on_floor()
	var had_wall := _contacts_valid and is_on_wall()
	var had_ceiling := _contacts_valid and is_on_ceiling()
	_motion_velocity = velocity
	_motion_frame = Engine.get_physics_frames()
	move_and_slide()
	# Cap contact pushes so walking/dashing cannot launch free rigid bodies.
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var object := collision.get_collider() as Grabbable
		if object == null or is_instance_valid(object.carrier):
			continue
		var direction := -collision.get_normal()
		var speed := clampf(_motion_velocity.dot(direction), 0.0, object_push_speed)
		var addition := maxf(speed - object.linear_velocity.dot(direction), 0.0)
		object.apply_central_impulse(direction * addition * object.mass)
	if get_held_object() != null:
		_update_carry_position()
	# Area delivery can lag an impact by two physics ticks. Keep the first impact
	# instead of replacing it with gravity against a settled floor.
	if (is_on_floor() and not had_floor) or (is_on_wall() and not had_wall) or (is_on_ceiling() and not had_ceiling):
		_impact_velocity = _motion_velocity
		_impact_frame = _motion_frame


func _ignore_overlapping_object(object: Grabbable) -> void:
	var shape: CollisionShape2D = $CollisionShape2D
	if not shape.shape.collide(shape.global_transform, object.collider.shape, object.collider.global_transform):
		return
	if not _separating_objects.has(object):
		_separating_objects.append(object)
		add_collision_exception_with(object)
		object.add_collision_exception_with(self)


func _clear_object_separation(object) -> void:
	if not is_instance_valid(object):
		_separating_objects = _separating_objects.filter(func(entry): return is_instance_valid(entry))
		return
	_separating_objects.erase(object)
	remove_collision_exception_with(object)
	object.remove_collision_exception_with(self)


func _separate_overlapping_objects() -> void:
	var shape: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		if hit.collider is Grabbable and not is_instance_valid(hit.collider.carrier):
			_ignore_overlapping_object(hit.collider)
	for object in _separating_objects.duplicate():
		if not is_instance_valid(object) or is_instance_valid(object.carrier):
			_clear_object_separation(object)
			continue
		if not shape.shape.collide(shape.global_transform, object.collider.shape, object.collider.global_transform):
			_clear_object_separation(object)
			continue
		# Native penetration recovery can wedge both bodies between a low ceiling
		# and floor. Separate this pair gently while still colliding with terrain.
		var direction: Vector2 = (global_position - object.global_position).normalized()
		var distance := overlap_separation_speed * get_physics_process_delta_time()
		if direction.is_zero_approx() or test_move(global_transform, direction * distance):
			direction = Vector2(-facing_direction if is_zero_approx(direction.x) else signf(direction.x), 0)
			if test_move(global_transform, direction * distance):
				direction = -direction
		move_and_collide(direction * distance)
		var addition: float = maxf(overlap_separation_speed - object.linear_velocity.dot(-direction), 0.0)
		object.apply_central_impulse(-direction * addition * object.mass)


func register_wind(source: Node, acceleration: Vector2, max_speed: float) -> void:
	_winds[source.get_instance_id()] = [weakref(source), acceleration, maxf(max_speed, 0.0)]


func unregister_wind(source: Node) -> void:
	_winds.erase(source.get_instance_id())


func _apply_wind(delta: float) -> void:
	var acceleration := Vector2.ZERO
	var speed_limit := 0.0
	for id in _winds.keys():
		var wind: Array = _winds[id]
		var source: Node = wind[0].get_ref()
		if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():
			_winds.erase(id)
			continue
		acceleration += wind[1]
		speed_limit = maxf(speed_limit, wind[2])
	if is_dashing() or _wall_grabbing or acceleration.is_zero_approx():
		return
	var down := Vector2.DOWN * gravity_direction
	var lift := -acceleration.dot(down)
	var parachute_limit := _held.fall_speed_limit() if get_held_object() != null else INF
	if lift > 0.0 and not is_finite(parachute_limit):
		# Without a parachute, updrafts slow falling instead of adding lift.
		acceleration += down * lift
		velocity -= down * maxf(velocity.dot(down) - max_fall_speed * 0.5, 0.0)
		if acceleration.is_zero_approx():
			return
	var direction := acceleration.normalized()
	# Limit only wind's addition along the resultant direction. Existing faster
	# jump/launch momentum is not truncated. Overlaps use the largest active cap.
	var addition := minf(acceleration.length() * delta, maxf(speed_limit - velocity.dot(direction), 0.0))
	var wind_velocity := direction * addition
	if lift > 0.0 and is_finite(parachute_limit):
		# Cap only wind's lift, preserving faster jump/launch momentum and crosswind.
		var available_lift := maxf(parachute_limit + velocity.dot(down), 0.0)
		wind_velocity += down * maxf(-wind_velocity.dot(down) - available_lift, 0.0)
	velocity += wind_velocity


func refill_from_crystal() -> void:
	_dash_ready = true
	_notify_resources()


func grant_air_jump() -> void:
	_air_jump_ready = true
	_notify_resources()


func get_wall_stamina() -> float:
	return _wall_stamina


func is_dash_ready() -> bool:
	return _dash_ready


func is_air_jump_ready() -> bool:
	return _air_jump_ready


func is_dashing() -> bool:
	return _dash_left > 0.0


func _notify_resources() -> void:
	var state := [_wall_stamina, wall_stamina_max, _dash_ready, _air_jump_ready]
	if state != _last_resources:
		_last_resources = state
		$Visuals/Body.color = _ready_color if _dash_ready else Color(1.0, 0.5, 0.15, 1.0)
		resources_changed.emit(_wall_stamina, wall_stamina_max, _dash_ready, _air_jump_ready)


func set_gravity_direction(direction: int) -> void:
	var next_direction := -1 if direction < 0 else 1
	if next_direction == gravity_direction:
		return
	gravity_direction = next_direction
	if not is_dashing():
		velocity.y = 0.0
	_coyote_left = 0.0
	_contacts_valid = false
	_apply_up_direction()
	if get_held_object() != null:
		_update_carry_position()
	if _gravity_tween:
		_gravity_tween.kill()
	_gravity_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gravity_tween.tween_property(visuals, "rotation", PI if gravity_direction < 0 else 0.0, 0.12)
	gravity_changed.emit(gravity_direction < 0)


func set_respawn_position(location: Vector2) -> void:
	_spawn_position = location


func respawn() -> void:
	for object in _separating_objects.duplicate():
		_clear_object_separation(object)
	_held = null
	_parachute_grace_left = 0.0
	for object in get_tree().get_nodes_in_group("grabbable"):
		object.reset_for_respawn()
	carry_changed.emit("NONE")
	_air_jump_ready = false
	_motion_frame = -2
	_impact_frame = -2
	global_position = _spawn_position
	_dash_left = 0.0
	_dash_direction = Vector2.ZERO
	_superdash_left = 0.0
	_superdash_speed = 0.0
	set_gravity_direction(1)
	if _gravity_tween:
		_gravity_tween.kill()
	visuals.rotation = 0.0
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_wall_grabbing = false
	_last_wall_normal = Vector2.ZERO
	_contacts_valid = false
	facing_direction = 1
	_refill_on_landing()
	_notify_resources()
	respawned.emit()


func is_wall_grabbing() -> bool:
	return _wall_grabbing


func _consume_jump() -> void:
	_jump_buffer_left = 0.0
	_coyote_left = 0.0


func _apply_up_direction() -> void:
	up_direction = Vector2.UP * gravity_direction
	floor_snap_length = 8.0


func _try_mantle() -> void:
	if absf(_last_wall_normal.x) < 0.5:
		return
	var motion := Vector2(-_last_wall_normal.x * mantle_distance, 0.0)
	if not test_move(global_transform, motion):
		global_position += motion
		velocity = Vector2.ZERO


func get_held_object() -> Grabbable:
	return _held if is_instance_valid(_held) else null


func get_available_extra_jump_count() -> int:
	return int(_air_jump_ready) + (_held.extra_jump_count() if get_held_object() != null else 0)


func get_effective_move_speed() -> float:
	return move_speed * (_held.move_multiplier if get_held_object() != null else 1.0)


func get_effective_acceleration(grounded: bool) -> float:
	return (ground_acceleration if grounded else air_acceleration) * (_held.acceleration_multiplier if get_held_object() != null else 1.0)


func get_effective_jump_speed() -> float:
	return jump_speed * (_held.jump_multiplier if get_held_object() != null else 1.0)


func _apply_parachute() -> void:
	if get_held_object() == null or is_dashing() or _parachute_grace_left > 0.0:
		return
	var down := Vector2.DOWN * gravity_direction
	var excess := velocity.dot(down) - _held.fall_speed_limit()
	if excess > 0.0:
		velocity -= down * excess


func _update_grab_input() -> void:
	if get_held_object() != null:
		if not Input.is_action_pressed("wall_grab"):
			release_grab()
		return
	if not Input.is_action_pressed("wall_grab") or is_dashing():
		return
	# A direct shape query is synchronous (no Area enter/exit delivery delay).
	var shape := CircleShape2D.new()
	shape.radius = grab_range
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]
	var candidates: Array[Grabbable] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		if hit.collider is Grabbable and not candidates.has(hit.collider):
			candidates.append(hit.collider)
	candidates.sort_custom(func(a: Grabbable, b: Grabbable): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for object in candidates:
		if try_begin_grab(object):
			break


func try_begin_grab(object: Grabbable) -> bool:
	if get_held_object() != null or is_dashing() or not is_instance_valid(object) or is_instance_valid(object.carrier):
		return false
	if _wall_grabbing and not Input.is_action_just_pressed("wall_grab"):
		return false
	if global_position.distance_to(object.global_position) > grab_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, object.global_position, 0xFFFFFFFF, [get_rid(), object.get_rid()])
	query.hit_from_inside = true
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return false
	_held = object
	_clear_object_separation(object)
	object.begin_carry(self)
	_update_carry_position()
	_wall_grabbing = false
	carry_changed.emit(object.carry_name)
	return true


func _update_carry_position() -> void:
	_held.global_position = global_position + Vector2(carry_offset.x, carry_offset.y * gravity_direction)


func release_grab() -> bool:
	if get_held_object() == null:
		return false
	_update_carry_position()
	var target := _held.global_position
	if not _held.is_position_clear(target, self):
		var found := false
		var steps := maxi(1, ceili(target.distance_to(global_position)))
		for step in range(1, steps + 1):
			var candidate := target.lerp(global_position, float(step) / steps)
			if _held.is_position_clear(candidate, self):
				target = candidate
				found = true
				break
		if not found:
			return false
	var released := _held
	_held = null
	released.global_position = target
	_ignore_overlapping_object(released)
	var release_velocity := velocity
	if velocity.length() >= throw_move_threshold:
		release_velocity += velocity.normalized() * released.throw_speed
	released.end_carry(release_velocity)
	object_released.emit(released, velocity.length() >= throw_move_threshold)
	carry_changed.emit("NONE")
	return true
