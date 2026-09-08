extends Area2D

signal pressed_changed(is_pressed: bool)

@export var required_weight := 2.0
@export var include_player := false
var total_weight := 0.0
var _pressed := false


func _physics_process(_delta: float) -> void:
	refresh_weight()


func refresh_weight() -> void:
	# The engine returns each body once, including bodies with multiple shapes.
	total_weight = 0.0
	for body in get_overlapping_bodies():
		if body is Grabbable:
			total_weight += body.weight
		elif include_player and body is PlayerController:
			total_weight += body.weight
	var next := total_weight >= required_weight
	if next != _pressed:
		_pressed = next
		pressed_changed.emit(_pressed)
	$Plate.color = Color(0.3, 1.0, 0.5) if _pressed else Color(0.7, 0.3, 0.15)
	$Plate.position.y = 3.0 if _pressed else 0.0


func is_pressed() -> bool:
	return _pressed
