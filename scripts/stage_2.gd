extends Node2D

const SECTION_HEIGHT := 720.0
const START_Y := 640.0
const ASSIST_BLOCK := preload("res://scenes/assist_block.tscn")
const ASSIST_POSITIONS := [
	[Vector2(490, 550), Vector2(490, 190)],
	[Vector2(770, -170), Vector2(860, -880)],
	[Vector2(490, -890)],
	[Vector2(770, -1610), Vector2(880, -2280)],
	[Vector2(490, -2330), Vector2(490, -2690), Vector2(410, -3020)],
	[Vector2(770, -3050)],
]
const TITLES := ["壁をつないで", "バネで上へ", "空中ダッシュの連鎖", "追加ジャンプの階段", "生物と登る", "頂上への連携"]
const HINTS := [
	"Shiftで壁を掴み、上へ登ってから反対の壁へキック。小さな足場で休憩できます。",
	"緑のバネで上昇。跳んだ先の壁を掴んで次の足場へ。",
	"空中の緑のクリスタルでダッシュ回復。斜め上のダッシュをつなごう。",
	"紫のクリスタルで空中ジャンプを追加。上昇が止まるころにもう一度ジャンプ。",
	"緑の生物をShiftで保持すると追加ジャンプ。壁を掴むときは生物を手放そう。",
	"バネ・クリスタル・壁キックをつないで頂上の到着台へ。",
]

var checkpoint_index := 0
var section_deaths := 0
var assist_enabled := false
var completed := false
var help_visible := false
var hints_visible := false
var peak_y := START_Y

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var checkpoints: Node2D = $Checkpoints


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	$Goal.activated.connect(_on_completed)
	$Goal.set_progress(0, 0, "", "", false)
	$HUD/HelpButton.pressed.connect(func(): set_help_visible(not help_visible))
	$HUD/AssistBlockButton.pressed.connect(_toggle_assist)
	$HUD/Help/Rows/Resume.pressed.connect(func(): set_help_visible(false))
	$HUD/Help/Rows/Hints.toggled.connect(_set_hints)
	$HUD/Help/Rows/Retry.pressed.connect(_retry)
	$HUD/Help/Rows/Return.pressed.connect(_return_to_select)
	_set_checkpoint(0)
	player.respawn()
	camera.make_current()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_stage_hints"):
		set_help_visible(not help_visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("return_to_stage_select"):
		get_viewport().set_input_as_handled()
		if help_visible:
			set_help_visible(false)
		else:
			_return_to_select()


func _physics_process(delta: float) -> void:
	if help_visible:
		return
	for block in $AssistBlocks.get_children():
		if player in block.get_collision_exceptions() and not _assist_overlaps_player(block):
			block.remove_collision_exception_with(player)
	# 更新は着地時のみ。通過しただけでは復帰地点を変えない。
	if player.is_on_floor():
		for index in range(checkpoint_index + 1, checkpoints.get_child_count()):
			var point: Vector2 = checkpoints.get_child(index).position
			if absf(player.position.x - point.x) < 130.0 and absf(player.position.y - (point.y - 26.0)) < 6.0:
				_set_checkpoint(index)
	peak_y = minf(peak_y, player.position.y)
	# 最高到達点からの大きな落下、または復帰地点より下への落下で再開。
	var checkpoint_y: float = checkpoints.get_child(checkpoint_index).position.y
	if player.position.y > minf(checkpoint_y + 180.0, peak_y + SECTION_HEIGHT - 80.0):
		section_deaths += 1
		player.respawn()
	var target_y := clampf(player.position.y - 80.0, -3920.0, 360.0)
	camera.position.y = lerpf(camera.position.y, target_y, 1.0 - exp(-8.0 * delta))
	_update_hud()


func _set_checkpoint(index: int) -> void:
	checkpoint_index = index
	section_deaths = 0
	assist_enabled = false
	for block in $AssistBlocks.get_children():
		block.queue_free()
	var point: Vector2 = checkpoints.get_child(index).position
	player.set_respawn_position(point + Vector2(0, -28))
	for child in checkpoints.get_children():
		child.get_node("Label").modulate = Color(0.45, 1, 0.72) if child.get_index() <= index else Color(0.65, 0.78, 0.95)


func _on_respawned() -> void:
	for crystal in $Items.get_children():
		if crystal.has_method("reset_for_respawn") and not crystal is Grabbable:
			crystal.reset_for_respawn()
	peak_y = player.position.y
	camera.position = Vector2(640, clampf(player.position.y - 80.0, -3920.0, 360.0))
	camera.reset_smoothing()


func set_help_visible(value: bool) -> void:
	help_visible = value
	$HUD/Help.visible = value
	$HUD/AssistBlockButton.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
	player.controls_enabled = not value
	if value:
		$HUD/Help/Rows/Resume.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _set_hints(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	for hint in $Hints.get_children():
		hint.visible = value


func _retry() -> void:
	set_help_visible(false)
	player.respawn()


func _toggle_assist() -> void:
	if section_deaths < 5 or completed:
		return
	assist_enabled = not assist_enabled
	if assist_enabled:
		for point in ASSIST_POSITIONS[checkpoint_index]:
			var block := ASSIST_BLOCK.instantiate()
			block.position = point
			$AssistBlocks.add_child(block)
			if _assist_overlaps_player(block):
				block.add_collision_exception_with(player)
	else:
		for block in $AssistBlocks.get_children():
			block.free()
	set_help_visible(false)
	_update_hud()


func _assist_overlaps_player(block: StaticBody2D) -> bool:
	var block_shape: CollisionShape2D = block.get_node("CollisionShape2D")
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	return block_shape.shape.collide(block_shape.global_transform, player_shape.shape, player_shape.global_transform)


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()
	$Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/AssistBlockButton.visible = section_deaths >= 5 and not completed
	$HUD/AssistBlockButton.text = "？ ブロックを解除" if assist_enabled else "？ おたすけブロック"
	$HUD/AssistBlockButton.tooltip_text = "その場で追加した足場を解除します。再設置もできます。" if assist_enabled else "その場でこの区間に足場を%d個追加します。" % ASSIST_POSITIONS[checkpoint_index].size()
	$HUD/Info/Rows/Title.text = "ステージ2　星のぼりの塔　｜　%02d / 06　%s" % [checkpoint_index + 1, TITLES[checkpoint_index]]
	$HUD/Info/Rows/Status.text = "高度 %dm　　ダッシュ：%s　　追加ジャンプ：%d　　復帰地点：%d" % [maxi(0, int((START_Y - player.position.y) / 10.0)), "使用可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), checkpoint_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[checkpoint_index]
