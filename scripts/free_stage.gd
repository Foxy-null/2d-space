extends Node2D

const SECTION_WIDTH := 1280.0
const TITLES := ["ダッシュで助走", "緑をつなごう", "斜め上へ", "空中ジグザグ", "高低差のリレー", "流星フィニッシュ"]
const HINTS := [
	"ジャンプ → X / B・○で右へダッシュ。広い足場で着地して回復しよう。",
	"緑のクリスタルに触れるとダッシュ回復。次の緑へ続けて飛ぼう。",
	"方向入力＋ダッシュで斜め上へ。真ん中の足場でも休めます。",
	"上・下・上へダッシュをつなごう。細い足場は最後の立て直しに。",
	"緑の間隔が広がります。高低差に合わせて斜めダッシュを使おう。",
	"途中の足場はありません。緑を連続で拾い、最後の到着台へ！",
]

var checkpoint_index := 0
var completed := false

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var checkpoints: Node2D = $Checkpoints


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	_set_checkpoint(0)
	player.respawn()
	camera.make_current()
	$HUD/Margin/Panel/Rows/Controls.text = "移動：A/D・方向キー / スティック　ジャンプ：Space・W / A・×"
	$HUD/Margin/Panel/Rows/WallControls.text = "壁を掴む：Shift / ZL・ZR　ダッシュ：X / B・○　やり直し：R / Start"
	$HUD/Margin/Panel/Rows/StaminaLabel.text = "壁スタミナ（着地で回復）"
	_update_hud()


func _physics_process(_delta: float) -> void:
	if player.is_on_floor():
		for index in range(checkpoint_index + 1, checkpoints.get_child_count()):
			var spawn: Vector2 = checkpoints.get_child(index).get_node("Spawn").global_position
			if absf(player.position.x - spawn.x) < 130 and absf(player.position.y - spawn.y) < 6:
				_set_checkpoint(index)
	if player.position.y < -52 or player.position.y > 772:
		player.respawn()
	camera.position.x = clampf(player.position.x + 240, 640, checkpoints.get_child_count() * SECTION_WIDTH - 640)
	_update_hud()


func _set_checkpoint(index: int) -> void:
	checkpoint_index = index
	player.set_respawn_position(checkpoints.get_child(index).get_node("Spawn").global_position)
	for point in checkpoints.get_children():
		point.get_node("Label").modulate = Color(0.45, 1, 0.72) if point.get_index() <= index else Color(0.65, 0.78, 0.95)


func _update_hud() -> void:
	$HUD/Margin/Panel/Rows/Title.text = "自由制作　流星ダッシュ　%02d / %02d　%s" % [checkpoint_index + 1, checkpoints.get_child_count(), TITLES[checkpoint_index]]
	$HUD/Hint.text = HINTS[checkpoint_index]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_stage_select") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_stage_select()


func _on_respawned() -> void:
	for area in $Objects.find_children("*", "Area2D", true, false):
		if area.has_method("reset_for_respawn") and not area is Grabbable:
			area.reset_for_respawn()
	camera.position.x = clampf(player.position.x + 240, 640, checkpoints.get_child_count() * SECTION_WIDTH - 640)
	camera.reset_smoothing()


func _retry() -> void:
	player.respawn()


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()


func _return_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
