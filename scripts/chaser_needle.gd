extends Node2D

const TEXTURES := [
	preload("res://assets/enemies/star-mountain/originals/sozai_a.png"),
	preload("res://assets/enemies/star-mountain/originals/sozai_b.png"),
	preload("res://assets/enemies/star-mountain/homing-neutral.png"),
	preload("res://assets/enemies/star-mountain/ash-rain.png"),
]
const HOMING_FLIGHT := preload("res://assets/enemies/star-mountain/homing-flight.png")
var course: StageSixRoom
var shooter: PlayerController
var variant := 0
var velocity := Vector2.ZERO
var stuck := false
var previous_tip := Vector2.ZERO
var flight_start := Vector2.ZERO
var flight_end := Vector2.ZERO
var flew := false
var pinned_box: Grabbable
var anchor: StaticBody2D
var life := 3.0
var length := 84.0
var picture: Sprite2D
var neutral_left := 0.65
var tracking_left := 2.5


func _ready() -> void:
	length = [84.0, 48.0, 64.0, 54.0][variant]
	life = 5.0 if variant == 2 else 3.0
	picture = Sprite2D.new()
	_set_picture(false)
	picture.position.x = -length * 0.5
	add_child(picture)
	rotation = velocity.angle()
	previous_tip = global_position


func _set_picture(flying: bool) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = HOMING_FLIGHT if variant == 2 and flying else TEXTURES[variant]
	# The original c1/c2 canvases include isolated sketch marks outside the spine.
	texture.region = (Rect2(728, 368, 92, 252) if flying else Rect2(744, 336, 54, 226)) if variant == 2 else Rect2(texture.atlas.get_image().get_used_rect())
	picture.texture = texture
	picture.scale = Vector2.ONE * length / (texture.get_height() if variant >= 2 else texture.get_width())
	picture.rotation = PI / 2.0 if variant >= 2 else (-0.17 if variant == 0 else 0.0)


func tip_position() -> Vector2:
	return global_position + Vector2.RIGHT.rotated(rotation) * length if stuck else global_position


func is_dangerous() -> bool:
	return not is_queued_for_deletion() and not (is_instance_valid(pinned_box) and pinned_box.pinned_to == self)


func advance(delta: float, player: PlayerController) -> void:
	flew = false
	previous_tip = tip_position()
	if stuck:
		if not is_instance_valid(anchor) or anchor.collision_layer == 0:
			queue_free()
		return
	if variant == 2 and neutral_left > 0.0:
		var waiting := minf(neutral_left, delta)
		neutral_left -= waiting
		delta -= waiting
		if neutral_left <= 0.0:
			_set_picture(true)
		if delta <= 0.0:
			return
	if variant == 2 and tracking_left > 0.0:
		var turn := velocity.angle_to(player.global_position - global_position)
		var turn_limit := 2.3 * minf(delta, tracking_left)
		velocity = velocity.rotated(clampf(turn, -turn_limit, turn_limit))
		tracking_left = maxf(0.0, tracking_left - delta)
		rotation = velocity.angle()
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var next := global_position + velocity * delta
	flew = true
	flight_start = global_position
	flight_end = next
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1, [shooter.get_rid(), player.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
		return
	flight_end = hit.position
	if hit.collider is Grabbable:
		queue_free()
		return
	if variant == 0 and hit.collider.get_meta("needle_breakable", false):
		course.break_needle_platform(hit.collider)
		queue_free()
		return
	if hit.collider is StaticBody2D:
		stick(hit.position, hit.normal, hit.collider)
	else:
		queue_free()


func stick(at: Vector2, normal: Vector2, body: StaticBody2D) -> void:
	stuck = true
	anchor = body
	global_position = at
	rotation = normal.angle()
	velocity = Vector2.ZERO
	picture.position.x = length * 0.5
	if variant == 2:
		_set_picture(false)
	var surface := StaticBody2D.new()
	surface.collision_layer = 2
	surface.collision_mask = 0
	surface.position.x = length * 0.5
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(length, 6)
	surface.add_child(collision)
	add_child(surface)
	previous_tip = tip_position()


func pin_box(box: Grabbable, player: PlayerController) -> bool:
	if not stuck or not is_dangerous() or box.carry_name not in ["OBJECT", "HEAVY"] or box.carrier != null or is_instance_valid(box.pinned_to):
		return false
	var at := tip_position()
	if not box.is_position_clear(at, player):
		return false
	box.pinned_to = self
	box.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	box.freeze = true
	box.linear_velocity = Vector2.ZERO
	box.angular_velocity = 0.0
	box.global_position = at
	PhysicsServer2D.body_set_state(box.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, box.global_transform)
	pinned_box = box
	return true


func _exit_tree() -> void:
	if is_instance_valid(pinned_box) and pinned_box.pinned_to == self:
		pinned_box.end_carry(Vector2.ZERO)
