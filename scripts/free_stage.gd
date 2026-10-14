extends Node2D

var completed := false

@onready var player: PlayerController = $Player


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.set_respawn_position($Spawn.global_position)
	player.respawned.connect(_on_respawned)
	player.respawn()
	$Camera2D.make_current()
	$HUD/Margin/Panel/Rows/Title.text = "自由制作ステージ"
	$HUD/Margin/Panel/Rows/Controls.text = "移動：A/D・方向キー / スティック　ジャンプ：Space・W / A・×"
	$HUD/Margin/Panel/Rows/WallControls.text = "壁を掴む：Shift / ZL・ZR　ダッシュ：X / B・○　やり直し：R / Start"
	$HUD/Margin/Panel/Rows/StaminaLabel.text = "壁スタミナ（着地で回復）"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_stage_select") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_stage_select()


func _on_respawned() -> void:
	for area in $Objects.find_children("*", "Area2D", true, false):
		if area.has_method("reset_for_respawn") and not area is Grabbable:
			area.reset_for_respawn()


func _retry() -> void:
	player.respawn()


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()


func _return_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
