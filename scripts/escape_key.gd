extends Area2D

signal collected


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 26.0
	add_child(collision)
	body_entered.connect(func(body):
		if visible and body is PlayerController and body.is_in_group("player"):
			hide()
			collected.emit()
	)


func reset_for_respawn() -> void:
	show()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 34, Color(1, 0.8, 0.2, 0.16))
	draw_arc(Vector2(-8, -8), 12, 0, TAU, 24, Color("ffdc78"), 6, true)
	draw_line(Vector2.ZERO, Vector2(19, 19), Color("ffdc78"), 6, true)
	draw_line(Vector2(12, 12), Vector2(20, 4), Color("ffdc78"), 6, true)
	draw_line(Vector2(18, 18), Vector2(26, 10), Color("ffdc78"), 6, true)
