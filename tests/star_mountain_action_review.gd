extends SceneTree
## Reproducible asset tables and controlled in-engine motion/attack footage.

const OUT := "res://deliverables/star-mountain-update/"
const ART := "res://assets/enemies/star-mountain/"
var stage
var source: AnimatedSprite2D
var font := SystemFont.new()
var caption: Label
var enemy_ai := false
var attacks := false
var elapsed := 0.0
var seen: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	font.font_names = PackedStringArray(["Noto Sans CJK JP"])
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.player.set_physics_process(false)
	source = stage.enemy.get_node("Visuals/EnemySprite")
	if OS.get_cmdline_user_args().has("--movie"):
		stage.enemy.movement_action.connect(func(action): print("VIDEO_ACTION ", action))
		await _movie()
	else:
		source.set_process(false)
		await _tables()
	print("STAR_MOUNTAIN_ACTION_REVIEW_OK")
	quit()


func _tables() -> void:
	stage.hide()
	stage.get_node("HUD").hide()
	root.size = Vector2i(1680, 1900)
	root.content_scale_size = root.size
	var canvas := _canvas()
	_label(canvas, "星間山荒・大赤斑｜動作と使用素材 1/2", Rect2(32, 20, 1620, 55), 38)
	_label(canvas, "忍者52px ／ 敵の立ち128px（約2.46倍）。各枠は同じ倍率で、足元と胴体位置を合わせて表示。", Rect2(32, 86, 1620, 70), 25)
	var rows := [
		["立ち・右", "idle", 0, "sozai15.png", "待機・着地・クリア時の立ち姿"],
		["立ち・左", "idle_left", 0, "sozai156.png", "専用の左向き原画。再反転なし"],
		["歩行A", "walk", 0, "sozai22.png", "地上移動中、Bと速度に応じ交互表示"],
		["歩行B", "walk", 1, "sozai3.png", "足元を揃えてA/Bを切り替え"],
		["ジャンプ", "jump", 0, "sozai4.png", "上昇・追加ジャンプ・壁蹴り・ばね"],
		["下降", "descend", 0, "sozai5.png", "重力方向への速度45〜500px/s"],
		["速い落下", "jump", 0, "sozai4.pngを左へ45度", "500px/s以上。やられ画像とは別"],
		["物運び・歩行A", "carry_walk", 0, "sozai7.png", "地上で荷物を持って歩く。Bと交互"],
		["物運び・歩行B", "carry_walk", 1, "sozai8.png", "下降姿勢の固定を解消"],
		["物運び・停止／空中", "descend", 0, "sozai5.png（共用）", "保持停止・保持ジャンプ・傘の滑空"],
		["壁掴み・壁登り", "wall_climb", 0, "sozai11.png", "トゲ壁も登れる。現在は1枚の姿勢"],
		["被弾・やられ", "defeated", 0, "sozai6.png", "怯み・決着で使用。落下には使わない"],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var at := Vector2(24 + (i % 3) * 552, 180 + (i / 3) * 416)
		_card(canvas, Rect2(at, Vector2(536, 398)))
		_label(canvas, row[0], Rect2(at + Vector2(16, 12), Vector2(504, 42)), 28)
		_label(canvas, row[3], Rect2(at + Vector2(16, 58), Vector2(504, 40)), 23)
		var foot := at + Vector2(322, 310)
		_ninja(canvas, at + Vector2(100, 310), 1.6)
		_pose(canvas, row[1], row[2], foot, 1.6, -PI / 4.0 if i == 6 else 0.0)
		_label(canvas, row[4], Rect2(at + Vector2(16, 330), Vector2(504, 58)), 22)
	await _capture("素材表-01-基本動作.png")
	canvas.free()
	root.size = Vector2i(1680, 2000)
	root.content_scale_size = root.size
	canvas = _canvas()
	_label(canvas, "星間山荒・大赤斑｜動作と使用素材 2/2", Rect2(32, 20, 1620, 55), 38)
	_label(canvas, "軌跡や渦の大きさを除いて体の倍率を調整。白い体色と原画を保持し、灰の雲だけ生成済み素材を使用。", Rect2(32, 86, 1620, 70), 25)
	var cards := [
		["ダッシュ", "sozai9.png", "8方向ダッシュ。荷物を持つ間は腕を上げた保持姿勢を優先。"],
		["スーパーダッシュ", "sozai10_-_.png", "地上ダッシュ直後のジャンプで切り替え。共有の移動処理を使用。"],
		["投げる・捕獲後の投げ返し", "sozai12.png", "渦を含む原画。捕獲をしのいだ際の短い怯みより優先して表示。"],
		["同じトゲの2状態", "sozai_c1.png → sozai_c2.png", "c1：待機0.65秒／c2：炎を付けて追尾。刺さるとc1へ戻る。"],
		["灰で固まった雨", "sozai_e.png", "雲ができてから落下。交互に隙間を空けて6波。地形で止まる。"],
		["火山の煙 → 渦巻く灰の雲", "sozaif.pngを元に作成した灰の雲", "灰色の煙が集まり、黄色い渦が循環。狙った場所は固定。"],
	]
	for i in cards.size():
		var at := Vector2(24 + (i % 2) * 828, 180 + (i / 2) * 588)
		_card(canvas, Rect2(at, Vector2(812, 568)))
		_label(canvas, cards[i][0], Rect2(at + Vector2(18, 14), Vector2(776, 45)), 29)
		_label(canvas, cards[i][1], Rect2(at + Vector2(18, 65), Vector2(776, 44)), 24)
		if i < 3:
			_ninja(canvas, at + Vector2(100, 400), 1.5)
			_pose(canvas, ["dash", "superdash", "throwback"][i], 0, at + Vector2(620 if i == 2 else 465, 400), 1.5 if i < 2 else 1.25)
		elif i == 3:
			_texture(canvas, ART + "homing-neutral.png", Rect2(at + Vector2(170, 150), Vector2(130, 250)), Rect2(744, 336, 54, 226))
			_texture(canvas, ART + "homing-flight.png", Rect2(at + Vector2(500, 150), Vector2(130, 250)), Rect2(728, 368, 92, 252))
			_label(canvas, "c1　待機", Rect2(at + Vector2(160, 420), Vector2(220, 40)), 24)
			_label(canvas, "c2　追尾飛行", Rect2(at + Vector2(490, 420), Vector2(290, 40)), 24)
		elif i == 4:
			for column in 3:
				_texture(canvas, ART + "ash-rain.png", Rect2(at + Vector2(170 + column * 170, 160), Vector2(50, 220)))
		else:
			_texture(canvas, ART + "ash-cloud.png", Rect2(at + Vector2(70, 180), Vector2(670, 245)))
		_label(canvas, cards[i][2], Rect2(at + Vector2(18, 480), Vector2(776, 76)), 24)
	await _capture("素材表-02-攻撃とダッシュ.png")
	canvas.free()


func _canvas() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var canvas := Control.new()
	layer.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("edf2f7")
	background.size = root.size
	canvas.add_child(background)
	return canvas


func _card(parent: Node, rect: Rect2) -> void:
	var block := ColorRect.new()
	block.color = Color.WHITE
	block.position = rect.position
	block.size = rect.size
	parent.add_child(block)


func _pose(parent: Node, pose: String, index: int, foot: Vector2, zoom: float, turn := 0.0) -> void:
	source.animation = pose
	source.frame = index
	source.apply_frame(-1 if pose in ["idle_left", "throwback"] else 1)
	var pivot := Node2D.new()
	pivot.position = foot
	parent.add_child(pivot)
	var picture := Sprite2D.new()
	picture.texture = source.sprite_frames.get_frame_texture(pose, index)
	picture.scale = source.scale * zoom
	picture.flip_h = source.flip_h
	picture.rotation = turn
	picture.position = (source.position - Vector2(0, 26)) * zoom
	pivot.add_child(picture)


func _ninja(parent: Node, foot: Vector2, zoom: float) -> void:
	var picture := Sprite2D.new()
	picture.texture = load("res://assets/characters/tachi.png")
	picture.scale = Vector2.ONE * 52.0 / 661.0 * zoom
	picture.position = foot - Vector2(0, 26 * zoom)
	parent.add_child(picture)


func _texture(parent: Node, file: String, rect: Rect2, crop := Rect2()) -> void:
	var original: Texture2D = load(file)
	var texture := AtlasTexture.new()
	texture.atlas = original
	texture.region = crop if crop.has_area() else Rect2(original.get_image().get_used_rect())
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = rect.position
	picture.size = rect.size
	parent.add_child(picture)


func _label(parent: Node, text: String, rect: Rect2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("20334b"))
	parent.add_child(label)
	return label


func _capture(file: String) -> void:
	await _step(4)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + file) == OK)


func _setup(text: String, enemy_at: Vector2, player_at: Vector2) -> void:
	stage._load_room(1)
	stage.room.set_physics_process(false)
	for item in stage.room.get_node("Items").get_children():
		item.free()
	stage.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.player.set_physics_process(false)
	source = stage.enemy.get_node("Visuals/EnemySprite")
	stage.enemy.position = enemy_at
	stage.player.position = player_at
	stage.enemy.active = true
	stage.enemy._pickup_left = 99.0
	stage.enemy._needle_cooldown = 99.0
	stage.enemy._attack_cooldown = 99.0
	stage.enemy._trail.clear()
	stage.camera.position = Vector2(640, 550)
	stage.camera.reset_smoothing()
	stage._previous_player = player_at
	stage._previous_enemy = enemy_at
	stage._status.text = "動作確認用の配置・入力 ／ ゲーム内の物理・画像・攻撃処理を使用"
	stage._hint.text = text
	stage.get_node("HUD/Progress").show()
	if is_instance_valid(caption):
		caption.queue_free()
	caption = _label(stage.get_node("HUD"), text, Rect2(24, 110, 1230, 90), 25)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color("101427"))
	caption.add_theme_constant_override("outline_size", 5)
	elapsed = 0.0


func _movie() -> void:
	_setup("① 忍者とのサイズ比較 ／ 歩行A・B → ダッシュ → スーパーダッシュ", Vector2(170, 794), Vector2(1040, 794))
	enemy_ai = true
	await _demo(150)
	print("VIDEO_FIRST_POSES ", seen.keys())
	_setup("② 物を持って地上を歩く ／ sozai7・8が交互に切り替わる", Vector2(200, 794), Vector2(1000, 794))
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = stage.enemy.position + Vector2(35, -15)
	stage.room.get_node("Items").add_child(box)
	stage.enemy._pickup_left = 0.0
	assert(stage.enemy.try_begin_grab(box))
	stage.enemy._pickup_left = 99.0
	await _demo(150)
	_setup("③ トゲの床を歩き、トゲの壁を登る ／ 敵はトゲ完全耐性", Vector2(360, 794), Vector2(550, 794))
	stage.room._hazard(Rect2(330, 820, 700, 40))
	stage.room._hazard(Rect2(670, 560, 75, 260))
	await _demo(45)
	stage.player.position = Vector2(900, 534)
	await _demo(180)
	_setup("④ 追尾トゲ ／ c1で待機 → c2で点火・追尾 → 地形に刺さる", Vector2(220, 794), Vector2(680, 794))
	enemy_ai = false
	attacks = true
	stage.enemy._needle_variant = 2
	stage.enemy._needle_cooldown = 0.0
	stage.player.set_physics_process(true)
	await _demo(110)
	Input.action_press("move_right")
	await _demo(40)
	Input.action_release("move_right")
	Input.action_press("jump")
	Input.action_press("move_left")
	await _demo(35)
	Input.action_release("jump")
	Input.action_release("move_left")
	await _demo(175)
	_setup("⑤ 火山の煙を灰の雲へ ／ 黄色い予告の後、固まった灰が降る", Vector2(220, 794), Vector2(700, 794))
	stage.enemy._needle_variant = 3
	stage.enemy._needle_cooldown = 0.0
	stage.player.set_physics_process(true)
	await _demo(135)
	Input.action_press("move_right")
	await _demo(55)
	Input.action_release("move_right")
	await _demo(260)
	_setup("⑥ 捕獲後の投げ返し ／ その後の被弾姿勢はsozai6（落下とは別）", Vector2(540, 794), Vector2(565, 794))
	attacks = false
	stage.player.set_physics_process(true)
	stage._capture()
	await _demo(75)
	stage.enemy.apply_stun(1.5)
	await _demo(100)
	for pose in ["walk", "carry_walk", "dash", "superdash", "wall_climb", "throwback", "defeated"]:
		print("VIDEO_CHECK ", pose, " ", seen.has(pose))
		assert(seen.has(pose), "Video must actually show " + pose)
	print("VIDEO_POSES ", seen.keys())


func _demo(count: int) -> void:
	stage.enemy.set_physics_process(enemy_ai)
	for index in count:
		var delta := 1.0 / 60.0
		elapsed += delta
		if attacks:
			stage.enemy._update_needle_attack(delta)
			# Do not begin another attack while reviewing this individual pattern.
			if stage.enemy._needle_recovery > 0.0:
				stage.enemy._needle_cooldown = 99.0
		stage._hit_grace = maxf(0.0, stage._hit_grace - delta)
		stage._update_needles(delta)
		for cloud in stage.room.get_node("AshClouds").get_children():
			cloud.advance(delta)
		stage._check_projectiles()
		stage._previous_player = stage.player.position
		stage._previous_enemy = stage.enemy.position
		await _step()
		seen[source.animation] = true


func _step(count := 1) -> void:
	for index in count:
		await physics_frame
		await process_frame
