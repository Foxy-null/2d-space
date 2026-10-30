extends SceneTree

const ART := "res://assets/enemies/star-mountain/"
const ROWS := [
	["立ち", "sozai15", "idle"], ["歩行A", "sozai22", "walk-a"],
	["歩行B", "sozai3", "walk-b"], ["ジャンプ", "sozai4", "jump"],
	["下降", "sozai5", "descend"], ["やられ・原本維持", "sozai6", "defeated"],
]
var stage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://deliverables")
	if OS.get_cmdline_user_args().has("--movie"):
		var success: bool = await _movie()
		if not success:
			quit(1)
			return
	else:
		await _comparison()
	print("STAR_MOUNTAIN_VISUAL_REVIEW_OK")
	quit()


func _comparison() -> void:
	root.size = Vector2i(1280, 1000)
	root.content_scale_size = Vector2i(1280, 1000)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("eaf0f5")
	background.size = Vector2(1280, 1000)
	canvas.add_child(background)
	_label(canvas, "星間山荒・大赤斑　原本とゲーム使用画像の比較", Vector2(24, 16), 26)
	_label(canvas, "左：原本　右：使用画像　｜　ジャンプの透明穴1画素だけ補正。白い描線・模様は保持", Vector2(24, 56), 18)
	for index in ROWS.size():
		var row: Array = ROWS[index]
		var at := Vector2(16 + (index % 3) * 424, 96 + (index / 3) * 444)
		var card := ColorRect.new()
		card.position = at
		card.size = Vector2(408, 424)
		card.color = Color.WHITE
		canvas.add_child(card)
		_label(canvas, row[0], at + Vector2(12, 8), 21)
		_label(canvas, "原本", at + Vector2(12, 42), 16)
		_label(canvas, "使用画像", at + Vector2(216, 42), 16)
		_picture(canvas, ART + "originals/" + row[1] + ".png", Rect2(at + Vector2(8, 70), Vector2(188, 240)))
		_picture(canvas, ART + row[2] + ".png", Rect2(at + Vector2(212, 70), Vector2(188, 240)))
		_label(canvas, row[1] + ".png", at + Vector2(12, 390), 15)
		if row[2] == "jump":
			_label(canvas, "補正した (56, 224) の周辺を拡大", at + Vector2(12, 300), 15)
			_detail(canvas, ART + "originals/sozai4.png", at + Vector2(60, 324))
			_detail(canvas, ART + "jump.png", at + Vector2(264, 324))
	await _step(4)
	await _capture("enemy-comparison.png")
	canvas.queue_free()
	await _step(2)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	canvas = Control.new()
	root.add_child(canvas)
	background = ColorRect.new()
	background.color = Color("eaf0f5")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	_label(canvas, "星間山荒・大赤斑　姿勢の割り当てと表示サイズ", Vector2(24, 20), 26)
	_label(canvas, "忍者：高さ52px　敵：高さ96px（約1.85倍）　／　やられは横倒しのため高さ58px", Vector2(24, 62), 18)
	_sprite(canvas, "res://assets/characters/tachi.png", Vector2(76, 200), 52.0)
	_sprite(canvas, ART + "idle.png", Vector2(200, 200), 96.0)
	_label(canvas, "原寸比較：忍者 ／ 敵", Vector2(290, 150), 20)
	for index in ROWS.size():
		var at := Vector2(32 + index * 208, 220)
		_label(canvas, ROWS[index][0], at, 18)
		_sprite(canvas, ART + ROWS[index][2] + ".png", at + Vector2(90, 180), 58.0 if index == 5 else 96.0)
		_label(canvas, "96px" if index != 5 else "58px", at + Vector2(50, 214), 16)
	_label(canvas, "落下：ジャンプ画像を左へ45度傾ける。やられ画像は使用しません。", Vector2(24, 560), 21)
	_label(canvas, "危険なのは針の先端だけ。箱を刺し込むと固定された安全な足場になります。", Vector2(24, 610), 20)
	var falling := _sprite(canvas, ART + "jump.png", Vector2(1140, 650), 96.0)
	falling.rotation = -PI / 4.0
	await _step(4)
	await _capture("enemy-poses.png")
	canvas.queue_free()
	await _step(2)
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/screenshots/stage-selection.png") == OK)


func _movie() -> bool:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(5)
	stage = current_scene
	stage.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.enemy.position = Vector2(160, 794)
	stage.player.position = Vector2(460, 794)
	stage.camera.position = Vector2(640, 600)
	stage.camera.reset_smoothing()
	stage.room._block(Rect2(900, 380, 24, 440))
	_label(stage.get_node("HUD"), "動作確認：針に箱を刺し込み、安全な足場にする", Vector2(24, 110), 23, Color.WHITE)
	await _step(30)
	stage.player.set_physics_process(false)
	var directions: Array[Vector2] = [Vector2.RIGHT]
	stage._spawn_needles(Vector2(550, 500), directions, 0)
	await _demo_step(70)
	var needle = stage.room.needles.get_child(0)
	if not needle.stuck:
		push_error("Preview needle must really hit the wall")
		return false
	var box: Grabbable = stage.room.LIGHT.instantiate()
	box.position = Vector2(620, 450)
	stage.room.get_node("Items").add_child(box)
	box.linear_velocity = Vector2(700, 0)
	stage._on_release(box, true, stage.player)
	await _demo_step(50)
	if box.pinned_to != needle or not box.freeze:
		push_error("Preview must use an actual swept box throw")
		return false
	stage.player.position = box.position - Vector2(0, 150)
	stage.player.velocity = Vector2.ZERO
	stage.player.set_physics_process(true)
	await _demo_step(80)
	if not stage.player.is_on_floor():
		push_error("Preview player must physically land on the pinned box")
		return false
	await _capture("stage6-platform.png")
	await _demo_step(90)
	return true


func _demo_step(count: int) -> void:
	for frame in count:
		stage._update_needles(1.0 / 60.0)
		stage._check_projectiles()
		await _step(1)


func _picture(parent: Node, path: String, rect: Rect2) -> void:
	var source: Texture2D = load(path)
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = source.get_image().get_used_rect()
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = cropped
	picture.position = rect.position
	picture.size = rect.size
	parent.add_child(picture)


func _sprite(parent: Node, path: String, foot: Vector2, height: float) -> Sprite2D:
	var source: Texture2D = load(path)
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = source.get_image().get_used_rect()
	var sprite := Sprite2D.new()
	sprite.texture = cropped
	sprite.scale = Vector2.ONE * height / cropped.get_height()
	sprite.position = foot - Vector2(0, height * 0.5)
	parent.add_child(sprite)
	return sprite


func _detail(parent: Node, path: String, at: Vector2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = Rect2(50, 218, 12, 12)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.texture = texture
	picture.position = at
	picture.size = Vector2(60, 60)
	parent.add_child(picture)


func _label(parent: Node, text: String, at: Vector2, size: int, color := Color("203048")) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://deliverables/" + file) == OK)


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
