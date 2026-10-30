class_name ScrollCollectible
extends Area2D

@export var stage_id := ""
@export var scroll_id := ""

var _origin := Vector2.ZERO
var _follower: PlayerController
var _secured := false
var _safe_time := 0.0


func _ready() -> void:
	# Player movement and hazards update before the landing check.
	process_physics_priority = 20
	_origin = global_position
	_secured = CollectionProgress.has_scroll(stage_id, scroll_id)
	modulate.a = 0.25 if _secured else 1.0
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	ArtDraw.scroll(self)


func _on_body_entered(body: Node) -> void:
	if _secured or is_instance_valid(_follower) or not body is PlayerController:
		return
	# Enter notifications can arrive after retry; check the player's current sweep.
	var body_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var previous_motion: Vector2 = -body.get_environment_velocity() * get_physics_process_delta_time()
	if not $CollisionShape2D.shape.collide_with_motion($CollisionShape2D.global_transform, Vector2.ZERO, body_shape.shape, body_shape.global_transform, previous_motion):
		return
	_follower = body
	_follower.respawned.connect(reset_for_respawn)
	_safe_time = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_follower):
		return
	var target := _follower.global_position + Vector2(-44 * _follower.facing_direction, -32 * _follower.gravity_direction)
	global_position = global_position.lerp(target, minf(delta * 12, 1.0))
	if not _has_safe_landing():
		_safe_time = 0.0
		return
	_safe_time += delta
	if _safe_time < 0.2:
		return
	_safe_time = 0.0
	# A hazard's deferred death must finish before this landing can be saved.
	_secure.call_deferred()


func _secure() -> void:
	if not is_instance_valid(_follower) or not _has_safe_landing():
		return
	if CollectionProgress.collect_scroll(stage_id, scroll_id) != OK:
		return
	_secured = true
	modulate.a = 0.25
	_stop_following()


func _has_safe_landing() -> bool:
	if not _follower.controls_enabled or not _follower._contacts_valid or not _follower.is_on_floor() or _follower.is_dashing() or _follower.is_wall_grabbing():
		return false
	if absf(_follower.velocity.dot(_follower.up_direction)) > 1.0:
		return false
	var contact := KinematicCollision2D.new()
	return _follower.test_move(_follower.global_transform, -_follower.up_direction, contact) and contact.get_collider() is StaticBody2D and contact.get_normal().dot(_follower.up_direction) > cos(_follower.floor_max_angle)


func reset_for_respawn() -> void:
	if is_instance_valid(_follower) and _follower.room_transfer_in_progress:
		_safe_time = 0.0
		return
	if not _secured:
		_stop_following()


func _stop_following() -> void:
	if is_instance_valid(_follower):
		_follower.respawned.disconnect(reset_for_respawn)
	_follower = null
	_safe_time = 0.0
	global_position = _origin
