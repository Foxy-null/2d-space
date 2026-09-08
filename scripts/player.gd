class_name PlayerController
extends CharacterBody2D

signal gravity_changed(is_inverted: bool)
signal resources_changed(stamina: float, stamina_max: float, dash_ready: bool, air_jump_ready: bool)

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
var _spring_refill_frame := -1
var _motion_velocity := Vector2.ZERO
var _motion_frame := -2
var _impact_velocity := Vector2.ZERO
var _impact_frame := -2
var _winds: Dictionary = {}

@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	_spawn_position = global_position
	_ready_color = $Visuals/Body.color
	_wall_stamina = wall_stamina_max
	_apply_up_direction()
	_notify_resources()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		respawn()
		return
	var grounded := _contacts_valid and is_on_floor()
	var on_wall := _contacts_valid and is_on_wall_only()
	var wants_wall_grab := Input.is_action_pressed("wall_grab") and on_wall
	if Input.is_action_just_pressed("jump") or (not wants_wall_grab and not is_dashing() and not Input.is_action_pressed("dash") and Input.is_action_just_pressed("move_up")):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_coyote_left = coyote_time if grounded else maxf(_coyote_left - delta, 0.0)
	_superdash_left = maxf(_superdash_left - delta, 0.0)
	var input_axis := Input.get_axis("move_left", "move_right")
	if absf(input_axis) > 0.1:
		facing_direction = 1 if input_axis > 0.0 else -1
	if Input.is_action_just_pressed("dash") and _dash_ready and not is_dashing():
		_start_dash(grounded)
	if is_dashing():
		_tick_dash(delta, grounded)
	else:
		var acceleration := ground_acceleration if grounded else air_acceleration
		velocity.x = move_toward(velocity.x, input_axis * move_speed, acceleration * delta)
		var down := Vector2.DOWN * gravity_direction
		var climb_axis := Input.get_axis("move_up", "move_down")
		_wall_grabbing = wants_wall_grab and not _grab_exhausted
		if _wall_grabbing:
			var rate := wall_stamina_climb_rate if climb_axis * gravity_direction < -0.5 else wall_stamina_rest_rate
			_wall_stamina = maxf(_wall_stamina - delta * rate, 0.0)
			if _wall_stamina <= 0.0:
				_grab_exhausted = true
				_wall_grabbing = false
		if _wall_grabbing:
			_last_wall_normal = get_wall_normal()
			velocity = Vector2(-_last_wall_normal.x * wall_stick_speed, climb_axis * wall_climb_speed)
		else:
			velocity += down * gravity_acceleration * delta
			_apply_wind(delta)
			var falling_speed := velocity.dot(down)
			if falling_speed > max_fall_speed:
				velocity += down * (max_fall_speed - falling_speed)
			var pressing_into_wall := on_wall and input_axis * get_wall_normal().x < -0.1
			if pressing_into_wall and falling_speed > wall_slide_speed:
				velocity += down * (wall_slide_speed - minf(falling_speed, max_fall_speed))
		_try_jump(grounded, on_wall)
		var was_wall_grabbing := _wall_grabbing
		_move_player()
		if was_wall_grabbing and not is_on_wall() and climb_axis * gravity_direction < -0.5 and Input.is_action_pressed("wall_grab"):
			_try_mantle()
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
	elif on_wall:
		velocity = Vector2(get_wall_normal().x * wall_jump_speed, -gravity_direction * jump_speed)
	elif _air_jump_ready:
		_air_jump_ready = false
		velocity.y = -gravity_direction * jump_speed
	else:
		return
	_wall_grabbing = false
	_superdash_left = 0.0
	_consume_jump()


func _refill_on_landing() -> void:
	_wall_stamina = wall_stamina_max
	_grab_exhausted = false
	_dash_ready = true
	_air_jump_ready = _spring_refill_frame == Engine.get_physics_frames()


func refill_movement_resources() -> void:
	_dash_ready = true
	_air_jump_ready = true
	_wall_stamina = wall_stamina_max
	_grab_exhausted = false
	_spring_refill_frame = Engine.get_physics_frames()
	_notify_resources()


func launch_from_spring(launch_velocity: Vector2) -> void:
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
	var had_floor := _contacts_valid and is_on_floor()
	var had_wall := _contacts_valid and is_on_wall()
	var had_ceiling := _contacts_valid and is_on_ceiling()
	_motion_velocity = velocity
	_motion_frame = Engine.get_physics_frames()
	move_and_slide()
	# Area delivery can lag an impact by two physics ticks. Keep the first impact
	# instead of replacing it with gravity against a settled floor.
	if (is_on_floor() and not had_floor) or (is_on_wall() and not had_wall) or (is_on_ceiling() and not had_ceiling):
		_impact_velocity = _motion_velocity
		_impact_frame = _motion_frame


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
	var direction := acceleration.normalized()
	# Limit only wind's addition along the resultant direction. Existing faster
	# jump/launch momentum is not truncated. Overlaps use the largest active cap.
	var addition := minf(acceleration.length() * delta, maxf(speed_limit - velocity.dot(direction), 0.0))
	velocity += direction * addition


func refill_from_crystal() -> void:
	_dash_ready = true
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
	if _gravity_tween:
		_gravity_tween.kill()
	_gravity_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gravity_tween.tween_property(visuals, "rotation", PI if gravity_direction < 0 else 0.0, 0.12)
	gravity_changed.emit(gravity_direction < 0)


func respawn() -> void:
	_spring_refill_frame = -1
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
