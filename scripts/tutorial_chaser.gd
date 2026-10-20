extends CharacterBody2D

@export var move_speed := 230.0
var target: PlayerController
var active := false
var _spawn := Vector2.ZERO


func _ready() -> void:
	_spawn = position
	_update_visual()


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or not target.controls_enabled:
		return
	velocity.x = move_toward(velocity.x, signf(target.global_position.x - global_position.x) * move_speed, 1700.0 * delta)
	velocity.y += 1900.0 * delta
	if is_on_floor() and is_on_wall():
		velocity.y = -650.0
	move_and_slide()
	$Body.frame = 0 if is_on_floor() else 1
	$Body.flip_h = velocity.x < 0.0
	_update_visual()


func _update_visual() -> void:
	var size: Vector2 = $Body.sprite_frames.get_frame_texture("default", $Body.frame).get_size()
	$Body.scale = Vector2.ONE * 63.0 / size.x
	$Body.position.y = 26.0 - size.y * $Body.scale.y * 0.5


func reset_for_respawn() -> void:
	active = false
	position = _spawn
	velocity = Vector2.ZERO
	$Body.frame = 0
	_update_visual()


func touches_player() -> bool:
	return Rect2(global_position - Vector2(24, 26), Vector2(48, 52)).intersects(Rect2(target.global_position - Vector2(18, 26), Vector2(36, 52)))
