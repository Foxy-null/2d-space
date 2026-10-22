extends Node2D

const SECTION_HEIGHT := 720.0
const START_Y := 640.0
const TITLES := ["壁をつないで", "バネで上へ", "空中ダッシュの連鎖", "追加ジャンプの階段", "生物と登る", "頂上への連携"]
const HINTS := [
	"Shiftで壁を掴み、上へ登ってから反対の壁へキック。小さな足場で休憩できます。",
	"床のばねで上昇。跳んだ先の壁を掴んで次の足場へ。",
	"空中の緑のクリスタルでダッシュ回復。斜め上のダッシュをつなごう。",
	"紫のクリスタルで空中ジャンプを追加。上昇が止まるころにもう一度ジャンプ。",
	"緑の生物をShiftで保持すると追加ジャンプ。壁を掴むときは生物を手放そう。",
	"バネ・クリスタル・壁キックをつないで頂上の到着台へ。",
]

const GUIDES := [
	"壁へ向かってShiftを押し、↑で上端まで登ってからSpaceで反対の壁へ蹴り返します。\n途中の小さな足場へ一度着地してスタミナを戻してください。掴み続けて一気に登ろうとすると途中で手が離れます。\n復帰地点は目印の足場へ着地すると更新され、通過しただけでは更新されません。",
	"床のばねで上がった後、跳んだ先の壁をShiftで掴みます。壁の上から次の足場へ移って着地し、続くばねへ向かってください。\nばねの発射でダッシュとスタミナが戻るので、横へ届かないときは上昇中に斜め上ダッシュを足します。",
	"最初の空中ダッシュで緑の速度マークへ入り、補充されたダッシュを次の緑へつなぎます。\n上昇が弱まってから斜め上へ使うと距離を稼げます。回復前にXを押し直しても発動しないので、HUDが「使用可」になったことを確認してください。",
	"紫のばね靴を取って、通常ジャンプの上昇が止まるころに追加ジャンプを使います。\n小さな段ごとに着地し、次の紫へ届く位置から跳んでください。早く連打すると二つの上昇が重なり、上の足場まで届きにくくなります。",
	"緑の生物をShiftで持ち、通常ジャンプ→頂点付近で相棒の追加ジャンプ、とつなぎます。\n相棒を持ったまま足場へ着地すると追加ジャンプが戻ります。壁を登る必要があるときは、安全な足場で止まって相棒を置いてから壁を掴んでください。",
	"ばねで上昇し、緑でダッシュを補充して次の壁へ入ります。壁を掴んだら蹴り返し、紫や相棒の追加ジャンプを上昇の終わりに使ってください。\n頂上は通過ではなく足跡の到着台へ着地してクリアします。落ちた場合は最後に着地した復帰地点から再開できます。"
]

var checkpoint_index := 0
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
	$HUD/Help/Rows/Actions/Resume.pressed.connect(func(): set_help_visible(false))
	$HUD/Help/Rows/Hints.toggled.connect(_set_hints)
	$HUD/Help/Rows/Actions/Retry.pressed.connect(_retry)
	$HUD/Help/Rows/Actions/Return.pressed.connect(_return_to_select)
	$HUD/Help.close_requested.connect(func(): set_help_visible(false))
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
		player.respawn()
	var target_y := clampf(player.position.y - 80.0, -3920.0, 360.0)
	camera.position.y = lerpf(camera.position.y, target_y, 1.0 - exp(-8.0 * delta))
	_update_hud()


func _set_checkpoint(index: int) -> void:
	checkpoint_index = index
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
	player.controls_enabled = not value
	get_tree().paused = value
	if value:
		$HUD/Help.show_hint("ステージ2　%02d / 06　%s" % [checkpoint_index + 1, TITLES[checkpoint_index]], GUIDES[checkpoint_index])
		$HUD/Help/Rows/Actions/Resume.grab_focus()
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


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()
	$Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ2　星のぼりの塔　｜　%02d / 06　%s" % [checkpoint_index + 1, TITLES[checkpoint_index]]
	$HUD/Info/Rows/Status.text = "高度 %dm　　ダッシュ：%s　　追加ジャンプ：%d　　復帰地点：%d" % [maxi(0, int((START_Y - player.position.y) / 10.0)), "使用可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), checkpoint_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[checkpoint_index]


func _exit_tree() -> void:
	get_tree().paused = false
