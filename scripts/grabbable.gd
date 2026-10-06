class_name Grabbable
extends RigidBody2D

@export var weight := 0.5
@export var throw_speed := 450.0
@export var carry_name := "OBJECT"
@export var move_multiplier := 1.0
@export var acceleration_multiplier := 1.0
@export var jump_multiplier := 1.0
@export var visual_width := 63.0

var carrier: PlayerController
var _spawn_transform: Transform2D
var _free_collision_layer: int
var _free_collision_mask: int
var _artwork_size: Vector2
var release_physics_frame := -2
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	add_to_group("grabbable")
	_spawn_transform = global_transform
	_free_collision_layer = collision_layer
	_free_collision_mask = collision_mask
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	_artwork_size = (collider.shape as RectangleShape2D).size
	var sprite := visuals.get_node("Body") as AnimatedSprite2D
	if sprite != null:
		_artwork_size = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size() * sprite.scale
	# Each instance owns its enlarged shape; animation never resizes shared physics.
	collider.shape = collider.shape.duplicate()
	(collider.shape as RectangleShape2D).size = _artwork_size * (visual_width / _artwork_size.x)
	_update_visuals()


func _process(_delta: float) -> void:
	_update_visuals()


func _update_visuals() -> void:
	var size := _artwork_size
	var sprite := visuals.get_node("Body") as AnimatedSprite2D
	if sprite != null:
		size = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size() * sprite.scale
	var visual_scale := visual_width / size.x
	var held := is_instance_valid(carrier)
	var gravity := carrier.gravity_direction if held else 1
	visuals.scale = Vector2.ONE * visual_scale
	visuals.rotation = PI if gravity < 0 else 0.0
	# Align the artwork's bottom with its full-size collider in either gravity.
	var support: float = (collider.shape as RectangleShape2D).size.y * 0.5
	visuals.position.y = (support - size.y * visual_scale * 0.5) * gravity
	visuals.position.x = 0.0


func begin_carry(player: PlayerController) -> void:
	carrier = player
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	collision_layer = 0
	collision_mask = 0


func end_carry(release_velocity: Vector2) -> void:
	carrier = null
	release_physics_frame = Engine.get_physics_frames()
	collision_layer = _free_collision_layer
	collision_mask = _free_collision_mask
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
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


func is_position_clear(at: Vector2, player: PlayerController) -> bool:
	# Release may overlap the player; its separation routine handles that pair.
	return get_world_2d().direct_space_state.intersect_shape(space_query(at, player), 1).is_empty()
