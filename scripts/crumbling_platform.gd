class_name CrumblingPlatform
extends StaticBody2D

enum State { READY, CRACKING, MISSING }
var size := Vector2(180, 16)
var player: PlayerController
var state := State.READY
var remaining := 0.0
var elapsed := 0.0
var collision: CollisionShape2D


func _ready() -> void:
	process_physics_priority = 10
	add_to_group("unstable_platform")
	collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = size
	collision.position = size * 0.5
	add_child(collision)


func _physics_process(delta: float) -> void:
	elapsed += delta
	if state == State.READY:
		if not player.is_on_floor():
			return
		for i in player.get_slide_collision_count():
			var contact := player.get_slide_collision(i)
			if contact.get_collider() == self and contact.get_normal().y < -0.7:
				state = State.CRACKING
				remaining = 0.5
	elif state == State.CRACKING:
		remaining -= delta
		if remaining <= 0:
			state = State.MISSING
			remaining = 2.0
			collision.set_deferred("disabled", true)
	else:
		remaining -= delta
		var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
		if remaining <= 0 and not collision.shape.collide(collision.global_transform, player_shape.shape, player_shape.global_transform):
			reset_for_respawn()
	queue_redraw()


func reset_for_respawn() -> void:
	state = State.READY
	remaining = 0.0
	collision.set_deferred("disabled", false)
	queue_redraw()


func _draw() -> void:
	if state == State.MISSING:
		return
	var shake := sin(elapsed * 75) * 2.0 if state == State.CRACKING and DisplayServer.accessibility_should_reduce_animation() != 1 else 0.0
	var rect := Rect2(Vector2(shake, 0), size)
	draw_rect(rect, Color("a6d9ef"))
	draw_rect(rect, Color("385e79"), false, 2)
	if state == State.CRACKING:
		draw_line(Vector2(size.x * 0.48 + shake, 2), Vector2(size.x * 0.56 + shake, size.y - 2), Color("385e79"), 2)
