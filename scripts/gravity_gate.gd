extends Area2D

@export_enum("Down:1", "Up:-1") var target_gravity := -1


func _ready() -> void:
	$Arrow.text = "↓" if target_gravity > 0 else "↑"
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_gravity_direction"):
		body.set_gravity_direction(target_gravity)
