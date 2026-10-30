extends Control

const ENTRIES := [
	{"name": "忍者ぶっとびくん", "category": "キャラクター", "image": "ninja", "text": "このゲームの主人公。ジャンプ・壁登り・ダッシュで星々の道を進みます。\n\n動きながら持つボタンを離すと投擲、止まって離すと足元へ置きます。横重力では↑↓で壁沿いを歩きます。"},
	{"name": "星間山荒・大赤斑", "category": "UMA妖怪エイリアン", "image": "res://assets/enemies/star-mountain/idle.png", "text": "総称：UMA妖怪エイリアン\n個体名：星間山荒・大赤斑\n\n忍者より大きな、棘に耐性を持つ追跡者。見つけると追跡し、見失うと最後に見た場所を調べます。棘の壁も登れますが、箱の投擲では怯みます。\n\n離れると灰雲や山なりの長針、動く相手へは短針の連射など、状況で技を選びます。攻撃の構えと隙はメッセージで確認できます。"},
	{"name": "緑の相棒", "category": "キャラクター", "scene": "res://scenes/jump_creature.tscn", "text": "持つと追加ジャンプを使える相棒です。保持したまま着地すると力が戻ります。\n\n通常ジャンプの上昇が終わるころに追加ジャンプを使うと、遠い足場へ渡れます。"},
	{"name": "赤い和傘", "category": "キャラクター・防御", "scene": "res://scenes/parachute_creature.tscn", "text": "持つと滑空し、上昇気流に乗れます。ステージ6では持っている間に傘が開き、頭上から来る針や灰の雨を防ぎます。\n\n横や下からの攻撃、地面に残った露出した棘先は防げません。ダッシュ中は傘が閉じるため、移動と防御を使い分けましょう。"},
	{"name": "軽い箱", "category": "運搬・防御", "scene": "res://scenes/grabbable.tscn", "text": "運んでスイッチへ置いたり、敵へ投げて怯ませたりできます。敵の飛行針を受けると箱に刺さり、箱と一緒に動きます。\n\n地形に刺さった針の露出した先端へ投げると、先端を覆った固定足場になります。固定後の箱は持ち直せません。"},
	{"name": "重い箱", "category": "運搬・重量", "scene": "res://scenes/heavy_object.tscn", "text": "重い重量スイッチを動かす箱。運ぶ間は移動やジャンプが弱くなります。段差では先へ投げ、自分は空身で追いかける方法もあります。\n\n最終戦の逃走出口の下、奥のくぼみに置くと封鎖装置へ通電します。通電だけでは敵を封じ込められません。"},
	{"name": "長針と山なりの長針", "category": "敵の攻撃", "image": "res://assets/enemies/star-mountain/originals/sozai_a.png", "text": "直線3連射と、上へ放って重力で降らせる10本の山なり攻撃。着弾時の角度を保って地形に刺さり、露出した後端だけが危険になります。\n\n長針はひびのある足場を壊せます。刺さった先端は箱で覆って道へ変えられます。"},
	{"name": "短針の扇形・連射", "category": "敵の攻撃", "image": "res://assets/enemies/star-mountain/originals/sozai_b.png", "text": "5方向の扇形と、約0.08秒ごとに18発放つ連射。連射は見えている忍者の動きに合わせて狙いをゆっくり変えます。壁の裏へ隠れると狙いを見失います。\n\n箱を盾にする、射線を外す、発射後の隙に反撃する方法があります。連射の細かい針は数秒で崩れますが、箱で固定した足場は残ります。"},
	{"name": "追尾トゲ", "category": "敵の攻撃", "image": "res://assets/enemies/star-mountain/homing-flight.png", "text": "6個を同時に放ちます。白い待機状態から炎をつけて飛び、一定時間だけ忍者を追尾します。\n\n急旋回には限界があり、青みがかった後は直進します。壁や箱へ誘導する、頭上へ来たときに傘で防ぐ方法があります。"},
	{"name": "灰雲と固まった雨", "category": "敵の攻撃", "image": "res://assets/enemies/star-mountain/ash-cloud.png", "text": "遠くへ逃げた忍者の進路を予測し、火山の煙から渦巻く灰雲を作ります。雲の場所と落下列を予告し、交互の列から8波・計36本を降らせます。\n\n屋根の下へ逃げる、進む向きを変える、傘や箱で受けるなどが有効です。地面に残る灰は8秒で崩れます。箱で覆った固定足場は維持します。"},
	{"name": "四面の棘ブロック", "category": "地形の仕掛け", "scene": "res://scenes/spike_block.tscn", "text": "四面に棘を持つ動くブロック。ステージ4とステージ6で登場します。端で折り返す動きを、待避できる足場から観察しましょう。\n\n忍者には危険ですが、大赤斑は棘の上も歩けます。"},
	{"name": "ばね", "category": "移動の仕掛け", "scene": "res://scenes/spring.tscn", "text": "触れると勢いよく跳ねます。重力で床になった壁や天井に置かれたばねもあります。\n\n飛び出した後のダッシュと追加ジャンプを一度に使わず、順番につなぐと遠くへ届きます。"},
	{"name": "バンパー", "category": "移動の仕掛け", "scene": "res://scenes/pinball_spring.tscn", "text": "丸い面へ入った方向に応じて弾き返す仕掛け。入る角度によって飛び出す方向が変わります。\n\nステージ5では番号順につなぎ、ステージ6では逃走路や高い道への移動に使います。"},
	{"name": "重力ゲート", "category": "地形の仕掛け", "scene": "res://scenes/gravity_gate.tscn", "text": "通ると矢印の方向へ重力が変わります。壁や天井を新しい床にして進めます。\n\n横重力の移動は画面の↑↓、ジャンプは重力に逆らう方向です。最後は↓ゲートで普段の床へ戻れます。"},
	{"name": "回復クリスタル", "category": "能力の回復", "scene": "res://scenes/refill_crystal.tscn", "text": "緑はダッシュ、紫は追加ジャンプを補います。足場と次の回復地点を見て、能力を使う順番を決めましょう。\n\n壁スタミナは着地や休息で回復します。敵の攻撃で回復低下中は、着地しても徐々に回復します。通常時は着地で即時全回復します。"},
	{"name": "重量スイッチ", "category": "地形の仕掛け", "scene": "res://scenes/pressure_button.tscn", "text": "箱や重箱を置いて動かします。足りない重さでは扉が開きません。金の線が対応する扉や檻を示します。\n\n開く装置と閉じる装置があります。置いた箱を持ち去ると、条件を失うものもあります。"},
	{"name": "到着スイッチと隔壁", "category": "部屋の出口", "scene": "res://scenes/arrival_switch.tscn", "text": "足跡の台へ着地し、押し込むと作動します。ステージ6の道中では隔壁が開くだけなので、その先の通路を走り抜けて次の部屋へ進みます。\n\n追跡者は背後の壁を破って追ってきます。最終部屋では条件を満たした到着台が逃走クリアになります。"},
]

var entries: ItemList
var heading: Label
var description: Label
var preview: SubViewport
var preview_world: Node2D
var description_scroll: ScrollContainer
var back: Button


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("10192e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)
	var title := _label("キャラクターと道具の図鑑", 32)
	rows.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(columns)
	entries = ItemList.new()
	entries.name = "Entries"
	entries.custom_minimum_size.x = 320
	entries.add_theme_font_size_override("font_size", 19)
	entries.add_theme_constant_override("v_separation", 16)
	columns.add_child(entries)
	for entry in ENTRIES:
		entries.add_item(entry.name)
		entries.set_item_tooltip(entries.item_count - 1, entry.category + "：" + entry.name)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	columns.add_child(detail)
	heading = _label("", 25)
	detail.add_child(heading)
	preview = SubViewport.new()
	preview.size = Vector2i(640, 245)
	preview.transparent_bg = true
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview)
	preview_world = Node2D.new()
	preview_world.position = Vector2(320, 130)
	preview.add_child(preview_world)
	var image := TextureRect.new()
	image.texture = preview.get_texture()
	image.custom_minimum_size.y = 245
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(image)
	description_scroll = ScrollContainer.new()
	description_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(description_scroll)
	description = _label("", 21)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_scroll.add_child(description)
	back = Button.new()
	back.name = "Return"
	back.custom_minimum_size.y = 44
	back.text = "ステージ選択に戻る　Esc / 戻るボタン"
	back.pressed.connect(_return)
	rows.add_child(back)
	entries.item_selected.connect(_select)
	entries.select(0)
	_select(0)
	entries.grab_focus.call_deferred()
	entries.focus_neighbor_bottom = entries.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(entries)
	var scrollbar := description_scroll.get_v_scroll_bar()
	scrollbar.focus_mode = Control.FOCUS_ALL
	entries.focus_neighbor_right = entries.get_path_to(scrollbar)
	scrollbar.focus_neighbor_left = scrollbar.get_path_to(entries)
	scrollbar.focus_neighbor_bottom = scrollbar.get_path_to(back)


func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	return label


func _select(index: int) -> void:
	var entry: Dictionary = ENTRIES[index]
	heading.text = "%s　/　%s" % [entry.category, entry.name]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = entry.text
	description_scroll.scroll_vertical = 0
	for child in preview_world.get_children():
		child.free()
	if entry.has("scene"):
		var object: Node2D = load(entry.scene).instantiate()
		preview_world.add_child(object)
		if object is Grabbable:
			object.freeze = true
			object.scale = Vector2.ONE * 2.0
		elif object is ArrivalSwitch:
			object.scale = Vector2.ONE * 1.2
			object.position.y = 60
		else:
			object.scale = Vector2.ONE * 1.8
		object.set_physics_process(false)
	else:
		var texture: Texture2D = load(entry.image) if entry.image != "ninja" else preload("res://assets/characters/ninja-frames.tres").get_frame_texture(&"idle", 0)
		var image := texture.get_image()
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
		var height := 200.0 if index == 1 else (110.0 if index == 0 else 190.0)
		sprite.scale = Vector2.ONE * minf(height / sprite.texture.get_height(), 500.0 / sprite.texture.get_width())
		preview_world.add_child(sprite)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return()


func _return() -> void:
	get_tree().set_meta("focus_gallery", true)
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
