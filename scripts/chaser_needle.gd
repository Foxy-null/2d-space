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
var anchor: CollisionObject2D
var anchor_transform := Transform2D.IDENTITY
var impact_normal := Vector2.ZERO
var acceleration := Vector2.ZERO
var stuck_left := 8.0
var blocked := false
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
	return global_position - Vector2.RIGHT.rotated(global_rotation) * length if stuck else global_position


func is_dangerous() -> bool:
	return not is_queued_for_deletion() and not anchor is Grabbable and not (is_instance_valid(pinned_box) and pinned_box.pinned_to == self)


func advance(delta: float, player: PlayerController) -> void:
	flew = false
	previous_tip = tip_position()
	if stuck:
		if not is_instance_valid(anchor) or (not anchor is Grabbable and anchor.collision_layer == 0):
			queue_free()
			return
		global_transform = anchor.global_transform * anchor_transform
		if not anchor is Grabbable and not is_instance_valid(pinned_box):
			stuck_left -= delta
			picture.modulate.a = clampf(stuck_left, 0.0, 1.0)
			if stuck_left <= 0.0:
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
		if tracking_left <= 0.0:
			picture.modulate = Color("a9ddff")
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var next := global_position + velocity * delta + acceleration * delta * delta * 0.5
	velocity += acceleration * delta
	if not velocity.is_zero_approx():
		rotation = velocity.angle()
	flew = true
	flight_start = global_position
	flight_end = next
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1, [shooter.get_rid(), player.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	# Held objects have their physics layer disabled, so intercept them explicitly.
	var held := player.get_held_object()
	if held != null and held.carry_name in ["OBJECT", "HEAVY", "PARACHUTE"]:
		var transform := held.collider.global_transform.affine_inverse()
		var half: Vector2 = (held.collider.shape as RectangleShape2D).size * 0.5
		var entry := _entry(transform * global_position, transform * next, Rect2(-half, half * 2.0))
		var wall_entry := INF if hit.is_empty() else global_position.distance_to(hit.position) / maxf(0.001, global_position.distance_to(next))
		var canopy := held.carry_name == "PARACHUTE"
		if entry < wall_entry and (not canopy or (not player.is_dashing() and velocity.dot(player.get_gravity_vector()) > 50.0)):
			flight_end = global_position.lerp(next, entry)
			blocked = true
			if canopy:
				queue_free()
			else:
				stick(flight_end, -velocity.normalized(), held)
			return
	if hit.is_empty():
		global_position = next
		return
	flight_end = hit.position
	if hit.collider is Grabbable:
		blocked = true
		if hit.collider.carry_name in ["OBJECT", "HEAVY"]:
			stick(hit.position, hit.normal, hit.collider)
		else:
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


func stick(at: Vector2, normal: Vector2, body: CollisionObject2D) -> void:
	# Preserve existing footholds; identical impacts do not stack redundant hazards.
	var incoming := velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT.rotated(global_rotation)
	var tip := at - incoming * length
	for needle in course.needles.get_children():
		if needle != self and needle.stuck and needle.anchor == body and needle.tip_position().distance_to(tip) < 3.0:
			queue_free()
			return
	stuck = true
	anchor = body
	global_position = at
	rotation = incoming.angle()
	impact_normal = normal
	anchor_transform = body.global_transform.affine_inverse() * global_transform
	velocity = Vector2.ZERO
	picture.position.x = -length * 0.5
	if variant == 2:
		_set_picture(false)
	if body is Grabbable:
		previous_tip = tip_position()
		return
	if course.entrance_area.has_point(tip_position()):
		queue_free()
		return
	course.limit_stuck_needles(self)
	var surface := StaticBody2D.new()
	surface.collision_layer = 2
	surface.collision_mask = 0
	surface.position.x = -length * 0.5
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
	var found := false
	# Shallow impacts need the box offset away from terrain while still covering the tip.
	var half: Vector2 = (box.collider.shape as RectangleShape2D).size * 0.5
	var extent := absf(impact_normal.x) * half.x + absf(impact_normal.y) * half.y
	for distance in range(0, maxi(1, int(extent)), 2):
		var candidate := tip_position() + impact_normal * distance
		var transform := box.collider.global_transform
		var box_extent := transform.x.abs() * half.x + transform.y.abs() * half.y
		var player_extent := Vector2(26, 18) if abs(player.gravity_direction) == 2 else Vector2(18, 26)
		var overlaps_player := Rect2(candidate - box_extent, box_extent * 2.0).intersects(Rect2(player.position - player_extent, player_extent * 2.0))
		if not overlaps_player and box.is_position_clear(candidate, player):
			at = candidate
			found = true
			break
	if not found:
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


static func _entry(from: Vector2, to: Vector2, rect: Rect2) -> float:
	if rect.has_point(from):
		return 0.0
	var direction := to - from
	var lower := 0.0
	var upper := 1.0
	for axis in 2:
		if absf(direction[axis]) < 0.00001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return INF
			continue
		var a: float = (rect.position[axis] - from[axis]) / direction[axis]
		var b: float = (rect.end[axis] - from[axis]) / direction[axis]
		lower = maxf(lower, minf(a, b))
		upper = minf(upper, maxf(a, b))
		if lower > upper:
			return INF
	return lower
