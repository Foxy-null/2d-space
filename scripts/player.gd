class_name PlayerController
extends CharacterBody2D

signal gravity_changed(is_inverted: bool)

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

var gravity_direction := 1
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _spawn_position := Vector2.ZERO
var _wall_grabbing := false
var _last_wall_normal := Vector2.ZERO

@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	_spawn_position = global_position
	_apply_up_direction()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		respawn()
	var wants_wall_grab := Input.is_action_pressed("wall_grab") and is_on_wall_only()
	if Input.is_action_just_pressed("jump") or (not wants_wall_grab and Input.is_action_just_pressed("move_up")):
		_jump_buffer_left = jump_buffer_time

	_coyote_left = coyote_time if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	var input_axis := Input.get_axis("move_left", "move_right")
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, input_axis * move_speed, acceleration * delta)

	var down := Vector2.DOWN * gravity_direction
	var climb_axis := Input.get_axis("move_up", "move_down")
	_wall_grabbing = wants_wall_grab
	if _wall_grabbing:
		_last_wall_normal = get_wall_normal()
		velocity = Vector2(-_last_wall_normal.x * wall_stick_speed, climb_axis * wall_climb_speed)
	else:
		velocity += down * gravity_acceleration * delta
		var falling_speed := velocity.dot(down)
		if falling_speed > max_fall_speed:
			velocity += down * (max_fall_speed - falling_speed)
		if is_on_wall_only() and falling_speed > wall_slide_speed:
			velocity += down * (wall_slide_speed - falling_speed)

	if _jump_buffer_left > 0.0:
		if is_on_floor() or _coyote_left > 0.0:
			velocity.y = -gravity_direction * jump_speed
			_consume_jump()
		elif is_on_wall_only():
			velocity = Vector2(get_wall_normal().x * wall_jump_speed, -gravity_direction * jump_speed)
			_wall_grabbing = false
			_consume_jump()

	var was_wall_grabbing := _wall_grabbing
	move_and_slide()
	if was_wall_grabbing and not is_on_wall() and climb_axis < -0.5 and Input.is_action_pressed("wall_grab"):
		_try_mantle()
	if global_position.y < -260.0 or global_position.y > 980.0:
		respawn()


func set_gravity_direction(direction: int) -> void:
	var next_direction := -1 if direction < 0 else 1
	if next_direction == gravity_direction:
		return
	gravity_direction = next_direction
	velocity.y = 0.0
	_apply_up_direction()
	var target_rotation := PI if gravity_direction < 0 else 0.0
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(visuals, "rotation", target_rotation, 0.12)
	gravity_changed.emit(gravity_direction < 0)


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_wall_grabbing = false
	set_gravity_direction(1)


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
