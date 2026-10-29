extends Node2D

const SECTION_HEIGHT := 720.0
const START_Y := 640.0
const TITLES := ["壁をつないで", "バネで上へ", "空中ダッシュの連鎖", "追加ジャンプの階段", "生物と登る", "空中の分かれ道", "壁から空中のつなぎ", "バネの左折り返し", "靴と相棒でジグザグ", "相棒と壁キック", "横風と反射", "大きな折り返し", "壁から長い回廊へ", "逆風の反射と左折り返し", "運んで横断し壁へ", "壁から二段の空中資源へ", "反射と追加ジャンプの横断", "左の壁から風の入口へ", "傘で風を渡る", "壁の上から空中を継ぐ", "バネと靴で左へ", "反射から次のバネへ", "相棒と靴から壁へ", "風の上から下を回る", "反射から上の空中資源へ", "投げて登り再び運ぶ", "回復を取りに折り返す", "張り出しの下から", "反射から風を越える", "滑空から上昇風へ", "上空の折り返し", "壁の上の相棒", "回復からバネへ", "反射と壁の頂上"]
const HINTS := [
	"Shiftで目の前の壁を掴んで上へ。広い足場で休み、ジャンプと上ダッシュで次の旗へ。",
	"バネで上昇。空中で左右を調整し、次の足場へ着地しよう。",
	"空中の緑のクリスタルでダッシュ回復。上へのダッシュをつなごう。",
	"紫の靴で追加ジャンプ。上昇が止まるころにもう一度跳び、上ダッシュで足場へ。",
	"緑の生物をShiftで保持すると追加ジャンプ。追加ジャンプと上ダッシュで足場へ。",
	"入口のバネから上ダッシュ。緑のダッシュ回復か紫の追加ジャンプをつないで次の旗へ。",
	"広い入口から壁を登り、休憩から回復ダッシュへ。運んだ相棒も使える。",
	"右のバネで左の休憩へ。小さなバネから次の旗を目指そう。",
	"靴と相棒の追加ジャンプを重ね、右上の棚から左へ折り返そう。",
	"相棒を持って壁から壁へ。上の休憩から追加ジャンプとダッシュをつなごう。",
	"バネで反射板の上へ回り込み、反射後は横風を見て左の旗へ。",
	"靴で右へ渡り、バネから回復ダッシュや相棒の追加ジャンプで左の次の旗へ。",
	"壁の上から回復ダッシュ。長い棚を右へ進み、バネで次の旗へ。",
	"バネから反射板の上へ。広い棚を左へ横断し、次のバネへ。",
	"相棒と靴の追加ジャンプで二度渡り、相棒を置いて左の壁を登ろう。",
	"相棒を持って壁キック。上の棚から相棒ジャンプと回復ダッシュへ。",
	"反射で左の棚へ。相棒と靴を重ねて右のバネへ渡ろう。",
	"靴と相棒で左の棚へ。相棒を置いて壁を登り、バネと回復ダッシュで次の旗へ。",
	"傘で上昇風へ入り、右の棚で休む。バネから次の風へ入り、左の旗へ滑空しよう。",
	"壁を登って回復ダッシュへ。広い棚から右の旗へ渡ろう。",
	"バネで左上へ。靴のジャンプで上の旗へ。",
	"バネで丸い反射の上へ。右の棚に着地して次のバネへ。",
	"相棒と靴で左の棚へ。対向壁を登り、上の旗へ。",
	"傘で風へ。左上で休み、左下の棚から靴で折り返そう。",
	"バネと反射で上の棚へ。回復ダッシュで次の旗へ。",
	"相棒を上へ運び、壁を登って再取得。右の棚へ渡ろう。",
	"左の回復や運んだ相棒で上の棚へ。右の壁を登ろう。",
	"張り出しの下からバネへ。上で休み、次の壁へ。",
	"反射板の上へ回り込み、左の風と靴をつないで旗へ。",
	"傘で左下へ滑空。向こうの風から右上へ。",
	"靴から反射へ。回復をつないで次の旗へ。",
	"壁を登り、上の相棒と左上の旗へ。",
	"左の回復や運んだ相棒で棚へ。バネで右上へ。",
	"靴から反射し、棚の先の壁へ。上のバネで到着台へ。",
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
		point.get_node("Label").add_theme_color_override("font_color", ArtDraw.CREAM if point.get_index() >= 19 else ArtDraw.INK)
	_set_checkpoint(0)
	player.respawn()
	camera.make_current()
	_update_hud()
	set_hints_visible(false)


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
	var checkpoint_fall_margin := 420.0 if checkpoint_index == 29 else 180.0
	if player.position.y > minf(checkpoint_y + checkpoint_fall_margin, peak_y + SECTION_HEIGHT - 80.0):
		player.respawn()
	var target_y := _camera_target_y()
	camera.position.x = lerpf(camera.position.x, _camera_target_x(), 1.0 - exp(-8.0 * delta))
	camera.position.y = lerpf(camera.position.y, target_y, 1.0 - exp(-8.0 * delta))
	_update_hud()


func _camera_target_x() -> float:
	if checkpoint_index >= 19:
		var lead := -340.0 if checkpoint_index == 20 else (-200.0 if checkpoint_index in [22, 23] else 100.0)
		if checkpoint_index == 25: lead = 450.0
		if checkpoint_index == 33 and player.position.y < -42300: lead = -250.0
		if checkpoint_index == 29: lead = 450.0 if player.position.y < -37300.0 else -450.0
		if checkpoint_index == 20 and player.position.y < -25680.0: lead = 100.0
		if checkpoint_index == 21 and player.position.y < -27200.0 and player.position.x > 1000.0: lead = 400.0
		if checkpoint_index == 23 and player.position.y > -30350.0: lead = 0.0
		return clampf(player.position.x + lead, -2600.0 if checkpoint_index >= 29 else -2000.0, 2400.0)
	if checkpoint_index == 18:
		var lead := 0.0
		if player.position.y < -24000.0:
			if player.position.x > 400.0: lead = -450.0
		elif player.position.y < -23100.0 and player.position.x < 400.0:
			lead = 100.0
		return clampf(player.position.x + lead, -800.0, 1400.0)
	if checkpoint_index >= 12:
		var lead := 240.0 if checkpoint_index == 17 or (checkpoint_index in [13, 16] and player.position.x >= 100.0) else 0.0
		if checkpoint_index == 16 and player.position.y < checkpoints.get_child(16).position.y - 640.0: lead = 0.0
		return clampf(player.position.x - lead, -800.0, 1400.0)
	if checkpoint_index not in [2, 7, 11]:
		return 640.0
	# 寄り道の着地点を、踏切やバネに触れる前に見せる。
	var follow_from := 600.0 if checkpoint_index == 7 else 360.0
	return clampf(640.0 + (player.position.x - follow_from) * 3.0, 0.0, 640.0)


func _camera_target_y() -> float:
	if checkpoint_index >= 19:
		var upper_glide := checkpoint_index == 23 and player.position.y < -30350.0
		var offset := 0.0 if upper_glide else -300.0 + maxf(player.velocity.y, 0.0) * 0.2
		if checkpoint_index == 27 and player.position.y > -34400.0: offset = -80.0
		if checkpoint_index == 29: offset = 40.0 if player.position.y < -37300.0 else 80.0
		return clampf(player.position.y + offset, $Goal.position.y - 280.0, 360.0)
	if checkpoint_index == 18:
		var offset := -80.0
		if player.position.y < -23150.0 and (player.position.x < 500.0 or player.position.y < -24280.0):
			offset = 100.0
		elif player.position.y > -23050.0 and player.position.y < -22800.0:
			offset = -260.0
		return clampf(player.position.y + offset, checkpoints.get_child(19).position.y - 280.0, 360.0)
	# 左上の任意枝では床と帰路を残し、主経路の上段棚では再び追従する。
	if checkpoint_index == 16 and player.position.x < 100.0 and player.position.y > checkpoints.get_child(16).position.y - 640.0:
		return clampf(checkpoints.get_child(16).position.y - 300.0, $Goal.position.y - 240.0, 360.0)
	var look_up := 300.0 if checkpoint_index >= 12 else (260.0 if checkpoint_index == 8 else (160.0 if checkpoint_index == 11 else (120.0 if checkpoint_index == 3 else 80.0)))
	if checkpoint_index == 16 and player.position.y < checkpoints.get_child(16).position.y - 400.0: look_up = 225.0
	# バネに乗る前に、反射板と最初の着地点を見せる。
	if checkpoint_index in [7, 10] or (checkpoint_index == 11 and player.position.y < -9920.0):
		look_up = 300.0
	return clampf(player.position.y - look_up, $Goal.position.y - 240.0, 360.0)


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
	camera.position = Vector2(_camera_target_x(), _camera_target_y())
	camera.reset_smoothing()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	$Goal/Bubble.visible = value
	for hint in $Hints.get_children():
		hint.visible = value


func _on_completed() -> void:
	completed = true
	CollectionProgress.mark_cleared("tower")
	$HUD/Completion.show()
	$Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info.position = Vector2(24, 620) if checkpoint_index >= 19 else Vector2(24, 16)
	if checkpoint_index == 22 or checkpoint_index >= 25 or (checkpoint_index == 21 and player.position.y < -27200.0):
		$HUD/Info.position.y = 16
	if checkpoint_index == 33 and player.position.y < -42300: $HUD/Info.position.y = 250
	$HUD/Info/Rows/Title.text = "星のぼりの塔　%02d / %02d" % [checkpoint_index + 1, checkpoints.get_child_count()]
	$HUD/Info/Rows/Status.text = "高度 %dm　ダッシュ %s　追加ジャンプ %d" % [maxi(0, int((START_Y - player.position.y) / 10.0)), "●" if player.is_dash_ready() else "○", player.get_available_extra_jump_count()]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.position.y = 16 if checkpoint_index == 19 or (checkpoint_index == 24 and player.position.y < -31700.0) else 110
	if checkpoint_index == 29 and (player.position.x < -1000.0 or player.position.y < -37300.0): $HUD/Hint.position.y = 560
	if checkpoint_index >= 31: $HUD/Hint.position.y = 140 if checkpoint_index == 31 else 180
	$HUD/Hint.text = TITLES[checkpoint_index] + "：" + HINTS[checkpoint_index]
