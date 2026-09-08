class_name Grabbable
extends RigidBody2D

@export var weight := 0.5
@export var throw_speed := 450.0
@export var carry_name := "OBJECT"
@export var move_multiplier := 1.0
@export var acceleration_multiplier := 1.0
@export var jump_multiplier := 1.0

var carrier: PlayerController
var _spawn_transform: Transform2D
@onready var collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("grabbable")
	_spawn_transform = global_transform
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE


func begin_carry(player: PlayerController) -> void:
	carrier = player
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	add_collision_exception_with(player)


func end_carry(release_velocity: Vector2) -> void:
	if is_instance_valid(carrier):
		remove_collision_exception_with(carrier)
	carrier = null
	freeze = false
	sleeping = false
	linear_velocity = release_velocity
	angular_velocity = 0.0


func reset_for_respawn() -> void:
	end_carry(Vector2.ZERO)
	global_transform = _spawn_transform
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	refill_extra_jump()


func extra_jump_count() -> int:
	return 0


func consume_extra_jump() -> bool:
	return false


func refill_extra_jump() -> void:
	pass


func fall_speed_limit() -> float:
	return INF


func shape_transform_at(at: Vector2) -> Transform2D:
	var transform := global_transform
	transform.origin = at
	return transform * collider.transform


func space_query(at: Vector2, player: PlayerController) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collider.shape
	query.transform = shape_transform_at(at)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid(), player.get_rid()]
	query.margin = 0.1
	return query


func is_position_safe(at: Vector2, player: PlayerController) -> bool:
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	if collider.shape.collide(shape_transform_at(at), player_shape.shape, player_shape.global_transform):
		return false
	return get_world_2d().direct_space_state.intersect_shape(space_query(at, player), 1).is_empty()


func safe_motion_fraction(from: Vector2, motion: Vector2, player: PlayerController, check_player := true) -> float:
	if check_player:
		var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
		if collider.shape.collide_with_motion(shape_transform_at(from), motion, player_shape.shape, player_shape.global_transform, Vector2.ZERO):
			return 0.0
	var query := space_query(from, player)
	query.motion = motion
	return get_world_2d().direct_space_state.cast_motion(query)[0]


func grab_start_position(player: PlayerController) -> Vector2:
	if is_position_safe(global_position, player):
		return global_position
	# Resting rigid bodies can settle a fraction of a pixel into a surface.
	# Use the engine's separation vector, bounded to one pixel, before sweeping.
	var parameters := PhysicsTestMotionParameters2D.new()
	parameters.from = global_transform
	parameters.motion = Vector2.ZERO
	parameters.margin = 0.2
	parameters.recovery_as_collision = true
	var result := PhysicsTestMotionResult2D.new()
	PhysicsServer2D.body_test_motion(get_rid(), parameters, result)
	var correction := result.get_travel()
	var recovered := global_position + correction
	if correction.length() <= 1.0 and is_position_safe(recovered, player):
		return recovered
	return Vector2(INF, INF)
