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
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.14
@export var hit_stop_seconds := 0.055

var gravity_direction := 1
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _spawn_position := Vector2.ZERO
var _hit_stop_running := false

@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	_spawn_position = global_position
	_apply_up_direction()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_W, KEY_UP]:
		_jump_buffer_left = jump_buffer_time
	elif event.physical_keycode == KEY_R:
		respawn()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_left = jump_buffer_time

	_coyote_left = coyote_time if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	var input_axis := Input.get_axis("ui_left", "ui_right")
	input_axis += float(Input.is_physical_key_pressed(KEY_D))
	input_axis -= float(Input.is_physical_key_pressed(KEY_A))
	input_axis = clampf(input_axis, -1.0, 1.0)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, input_axis * move_speed, acceleration * delta)

	var down := Vector2.DOWN * gravity_direction
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
			_consume_jump()

	move_and_slide()
	if global_position.y < -260.0 or global_position.y > 980.0:
		respawn()


func set_gravity_direction(direction: int, with_hit_stop := true) -> void:
	var next_direction := -1 if direction < 0 else 1
	if next_direction == gravity_direction:
		return
	gravity_direction = next_direction
	velocity.y = 0.0
	_apply_up_direction()
	var target_rotation := PI if gravity_direction < 0 else 0.0
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(visuals, "rotation", target_rotation, 0.12)
	gravity_changed.emit(gravity_direction < 0)
	if with_hit_stop and hit_stop_seconds > 0.0:
		_run_hit_stop()


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	set_gravity_direction(1, false)


func _consume_jump() -> void:
	_jump_buffer_left = 0.0
	_coyote_left = 0.0


func _apply_up_direction() -> void:
	up_direction = Vector2.UP * gravity_direction
	floor_snap_length = 8.0


func _run_hit_stop() -> void:
	if _hit_stop_running:
		return
	_hit_stop_running = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = 0.08
	await get_tree().create_timer(hit_stop_seconds, true, false, true).timeout
	Engine.time_scale = previous_scale
	_hit_stop_running = false
