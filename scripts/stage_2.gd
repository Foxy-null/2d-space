extends Node2D

const SECTION_HEIGHT := 720.0
const START_Y := 640.0
const TITLES := ["壁をつないで", "バネで上へ", "空中ダッシュの連鎖", "追加ジャンプの階段", "生物と登る", "頂上への連携"]
const HINTS := [
	"Shiftで壁を掴み、上へ登ってから反対の壁へキック。小さな足場で休憩できます。",
	"緑のバネで上昇。跳んだ先の壁を掴んで次の足場へ。",
	"空中の緑のクリスタルでダッシュ回復。上へのダッシュをつなごう。",
	"紫の靴で追加ジャンプ。上昇が止まるころにもう一度跳び、上ダッシュで足場へ。",
	"緑の生物をShiftで保持すると追加ジャンプ。追加ジャンプと上ダッシュで足場へ。",
	"バネ・クリスタル・壁キックをつないで頂上の到着台へ。",
]

var checkpoint_index := 0
var completed := false
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
	for point in checkpoints.get_children():
		var sign := Node2D.new()
		sign.name = "Sign"
		point.add_child(sign)
		sign.draw.connect(_draw_checkpoint.bind(sign, point.get_index()))
		point.get_node("Label").add_theme_color_override("font_color", ArtDraw.INK)
	_set_checkpoint(0)
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(delta: float) -> void:
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
	var target_y := _camera_target_y()
	camera.position.y = lerpf(camera.position.y, target_y, 1.0 - exp(-8.0 * delta))
	_update_hud()


func _camera_target_y() -> float:
	# 右端の休憩足場を、ポーズボタンの下に見せる。
	return clampf(player.position.y - (120.0 if checkpoint_index == 3 else 80.0), -3920.0, 360.0)


func _set_checkpoint(index: int) -> void:
	checkpoint_index = index
	var point: Vector2 = checkpoints.get_child(index).position
	player.set_respawn_position(point + Vector2(0, -28))
	for child in checkpoints.get_children():
		var mark := "↺ " if child.get_index() == index else ("✓ " if child.get_index() < index else "")
		child.get_node("Label").text = mark + "%02d" % (child.get_index() + 1)
		child.get_node("Sign").queue_redraw()


func _draw_checkpoint(canvas: Node2D, index: int) -> void:
	var reached := index <= checkpoint_index
	var color := ArtDraw.GOLD if index == checkpoint_index else ArtDraw.MINT
	ArtDraw.box(canvas, Rect2(-106, -5, 20, 5), ArtDraw.CREAM, 1)
	canvas.draw_line(Vector2(-96, -47), Vector2(-96, -3), ArtDraw.INK, 6, true)
	canvas.draw_line(Vector2(-96, -47), Vector2(-96, -3), ArtDraw.CREAM, 2, true)
	var flag := PackedVector2Array([Vector2(-96, -47), Vector2(-63, -36), Vector2(-96, -25)])
	if reached:
		ArtDraw.polygon(canvas, flag, color)
	else:
		flag.append(flag[0])
		canvas.draw_polyline(flag, ArtDraw.INK, 5, true)
		canvas.draw_polyline(flag, ArtDraw.CREAM, 2, true)
	ArtDraw.footprints(canvas, Vector2(0, 5), 0.5)


func _on_respawned() -> void:
	$Goal.reset_for_respawn()
	for crystal in $Items.get_children():
		if crystal.has_method("reset_for_respawn") and not crystal is Grabbable:
			crystal.reset_for_respawn()
	peak_y = player.position.y
	camera.position = Vector2(640, _camera_target_y())
	camera.reset_smoothing()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	for hint in $Hints.get_children():
		hint.visible = value


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()
	$Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "星のぼりの塔　%02d / 06" % (checkpoint_index + 1)
	$HUD/Info/Rows/Status.text = "高度 %dm　ダッシュ %s　追加ジャンプ %d" % [maxi(0, int((START_Y - player.position.y) / 10.0)), "●" if player.is_dash_ready() else "○", player.get_available_extra_jump_count()]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = TITLES[checkpoint_index] + "：" + HINTS[checkpoint_index]
