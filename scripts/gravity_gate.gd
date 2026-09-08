extends Area2D

@export_enum("Down:1", "Up:-1") var target_gravity := -1:
	set(value):
		target_gravity = value
		if is_node_ready():
			_update_visuals()


func _ready() -> void:
	_update_visuals()
	body_entered.connect(_on_body_entered)


func _update_visuals() -> void:
	var tint := Color(1.0, 0.3, 0.35) if target_gravity < 0 else Color(0.55, 0.98, 1.0)
	$Arrow.text = "↓" if target_gravity > 0 else "↑"
	$Arrow.add_theme_color_override("font_color", tint)
	$Glow.color = Color(tint, 0.22)


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_gravity_direction"):
		body.set_gravity_direction(target_gravity)
