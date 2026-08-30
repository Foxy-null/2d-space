extends CanvasLayer

@export var player_path: NodePath


func _ready() -> void:
	var player := get_node(player_path) as PlayerController
	player.gravity_changed.connect(_on_gravity_changed)
	_on_gravity_changed(player.gravity_direction < 0)


func _on_gravity_changed(is_inverted: bool) -> void:
	$Margin/Panel/Rows/Gravity.text = "GRAVITY: UP" if is_inverted else "GRAVITY: DOWN"
