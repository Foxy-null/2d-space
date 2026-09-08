extends CanvasLayer

@export var player_path: NodePath


func _ready() -> void:
	var player := get_node(player_path) as PlayerController
	player.gravity_changed.connect(_on_gravity_changed)
	player.resources_changed.connect(_on_resources_changed)
	_on_gravity_changed(player.gravity_direction < 0)
	_on_resources_changed(player.get_wall_stamina(), player.wall_stamina_max, player.is_dash_ready(), player.is_air_jump_ready())


func _on_gravity_changed(is_inverted: bool) -> void:
	$Margin/Panel/Rows/Gravity.text = "GRAVITY: UP" if is_inverted else "GRAVITY: DOWN"


func _on_resources_changed(stamina: float, stamina_max: float, dash_ready: bool, air_jump_ready: bool) -> void:
	$Margin/Panel/Rows/Stamina.max_value = stamina_max
	$Margin/Panel/Rows/Stamina.value = stamina
	$Margin/Panel/Rows/Resources.text = "DASH: %s   AIR JUMP: %s" % ["READY" if dash_ready else "USED", "READY" if air_jump_ready else "NONE"]
