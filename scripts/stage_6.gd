extends Node2D

const PLAYER = preload("res://scenes/player.tscn")
const CHASER = preload("res://scripts/chaser.gd")
const ROOM = preload("res://scripts/stage_6_room.gd")
const BACKDROP = preload("res://scripts/stage_backdrop.gd")
const CLEAR = preload("res://scripts/stage_clear.gd")

@export var enemy_avatar: Texture2D
@export_range(4, 12) var defeat_hits_required := 6
@export var escape_seconds := 20.0
var room_index := 0
var completed := false
var transitioning := false
var help_visible := false
var ending := ""
var player: PlayerController
var enemy: PlayerController
var room: StageSixRoom
var camera: Camera2D
var _world: Node2D
var _backdrop: StageBackdrop
var _title: Label
var _status: Label
var _stamina: ProgressBar
var _hint: Label
var _help: PanelContainer
var _message: Label
var _completion: Label
var _projectiles: Array[Dictionary] = []
var _immunity_left := 0.0
var _hit_grace := 0.0
var _chase_delay := 0.0
var _capture_pending := false
var _game_over_pending := false
var _loading := false
var _generation := 0
var _previous_player := Vector2.ZERO
var _previous_enemy := Vector2.ZERO
var _player_arrived := false
var defeat_hits := 0
var escape_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("environment_theme", 3)
	var background := CanvasLayer.new()
	background.layer = -10
	add_child(background)
	_backdrop = BACKDROP.new()
	background.add_child(_backdrop)
	_world = Node2D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	player = PLAYER.instantiate()
	player.name = "Player"
	player.use_default_respawn_bounds = false
	_world.add_child(player)
	player.get_node("Camera2D").enabled = false
	enemy = PLAYER.instantiate()
	enemy.set_script(CHASER)
	enemy.set("avatar_texture", enemy_avatar)
	enemy.name = "Chaser"
	enemy.use_default_respawn_bounds = false
	_world.add_child(enemy)
	enemy.set("target", player)
	player.add_collision_exception_with(enemy)
	enemy.add_collision_exception_with(player)
	player.respawned.connect(_on_player_respawned)
	player.object_released.connect(_on_release.bind(player))
	enemy.object_released.connect(_on_release.bind(enemy))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	_world.add_child(camera)
	camera.make_current()
	_build_hud()
	_load_room(0)


func _load_room(index: int) -> void:
	_loading = true
	_generation += 1
	_projectiles.clear()
	if is_instance_valid(room):
		# Release old references before removing the old room's rigid bodies.
		player.respawn(false)
		enemy.respawn(false)
		room.free()
	room_index = index
	room = ROOM.new()
	room.number = index
	_world.add_child(room)
	room.arrival.activated.connect(func(): _player_arrived = room.arrival.activator == player)
	set_meta("environment_theme", 3 if index < 6 else 4)
	_backdrop.environment_theme = 3 if index < 6 else 4
	player.set_respawn_position(room.spawn)
	enemy.set_respawn_position(room.enemy_spawn)
	player.respawn()
	enemy.call("reset_pursuit")
	enemy.set("course", room)
	enemy.set("preferred_item", room.preferred_item)
	enemy.set("active", false)
	_chase_delay = -1.0 if room.prepared else room.chase_delay
	_player_arrived = false
	defeat_hits = 0
	escape_elapsed = 0.0
	_immunity_left = 0.6
	_hit_grace = 0.0
	_capture_pending = false
	_message.hide()
	_loading = false
	transitioning = false
	player.controls_enabled = true
	enemy.controls_enabled = true
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	camera.reset_smoothing()
	_update_hud()


func _physics_process(delta: float) -> void:
	if _loading or transitioning or help_visible or completed or _game_over_pending:
		return
	_immunity_left = maxf(0.0, _immunity_left - delta)
	_hit_grace = maxf(0.0, _hit_grace - delta)
	if _chase_delay < 0.0 and player.position.distance_to(room.spawn) > 155.0:
		_chase_delay = room.chase_delay
	elif _chase_delay >= 0.0:
		_chase_delay = maxf(0.0, _chase_delay - delta)
		if _chase_delay <= 0.0:
			enemy.set("active", true)
	if _out_of_course(player) or _touches_hazard(player, _previous_player):
		player.respawn()
		return
	if _out_of_course(enemy) or _touches_hazard(enemy, _previous_enemy):
		enemy.call("reset_pursuit", true)
	_check_projectiles()
	if not _capture_pending and _immunity_left <= 0.0 and enemy.get("active") and enemy.stun_left <= 0.0 and enemy.get_held_object() == null and _actor_rect(enemy).grow(2).intersects(_actor_rect(player)):
		_capture()
	if _game_over_pending:
		return
	if room_index == 11:
		if enemy.get("active") and room.battle_arena.has_point(player.position) and room.battle_arena.has_point(enemy.position):
			escape_elapsed = minf(escape_seconds, escape_elapsed + delta)
		room.update_escape(escape_elapsed >= escape_seconds)
	if room_index == 11 and room.seal_enemy(enemy, player):
		_complete("封じ込め成功")
	elif room.exit_open and (_player_arrived or room.exit_rect.has_point(player.position)) and (room_index != 11 or (room.all_weight_doors_open() and room.escape_unlocked)):
		if room_index == 11:
			_complete("逃走成功")
		else:
			transitioning = true
			_load_room.call_deferred(room_index + 1)
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	_update_hud()


func _on_player_respawned() -> void:
	if _loading or not is_instance_valid(room):
		return
	_generation += 1
	_capture_pending = false
	_hit_grace = 0.0
	_projectiles.clear()
	_message.hide()
	room.reset_state()
	enemy.call("reset_pursuit")
	enemy.set("active", false)
	_chase_delay = -1.0 if room.prepared else room.chase_delay
	_player_arrived = false
	defeat_hits = 0
	escape_elapsed = 0.0
	_immunity_left = 0.6
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	camera.reset_smoothing()


static func capture_probability(stamina: float, maximum: float) -> float:
	return 1.0 - clampf(stamina / maximum, 0.0, 1.0) if maximum > 0.0 else 1.0


func _capture() -> void:
	if _capture_pending or enemy.get_held_object() != null:
		return
	_capture_pending = true
	escape_elapsed = 0.0
	var probability := capture_probability(player.get_wall_stamina(), player.wall_stamina_max)
	if randf() < probability:
		_game_over()
		return
	var generation := _generation
	_immunity_left = 2.25
	player.apply_stun(0.25)
	enemy.apply_stun(0.4)
	enemy.set("throw_pose_left", 0.5)
	_message.text = "捕獲をしのいだ！　投げ返し後 2秒間は再捕獲されません"
	_message.show()
	await get_tree().create_timer(0.25, false).timeout
	if generation != _generation or completed or _game_over_pending:
		return
	var back := room.spawn
	var closest := INF
	for index in room.route.size():
		var distance := player.position.distance_squared_to(room.route[index])
		if distance < closest:
			closest = distance
			back = room.spawn if index == 0 else room.route[index - 1]
	var direction := (back - player.position).normalized()
	if direction.is_zero_approx():
		direction = -player.get_walk_axis()
	player.apply_stun(0.3, direction * 650.0 - player.get_gravity_vector() * 220.0)
	_immunity_left = 2.0
	_capture_pending = false
	await get_tree().create_timer(1.6, false).timeout
	if generation == _generation and not completed and not _game_over_pending:
		_message.hide()


func _game_over() -> void:
	_game_over_pending = true
	player.controls_enabled = false
	enemy.controls_enabled = false
	_message.text = "ゲームオーバー\n捕獲されました — ステージ選択へ戻ります"
	_message.show()
	await get_tree().create_timer(1.2, false).timeout
	_return_to_select()


func _on_release(object: Grabbable, thrown: bool, source: PlayerController) -> void:
	if not thrown:
		return
	_projectiles.append({"object": weakref(object), "source": source, "previous": object.position, "life": 3.0})


func _check_projectiles() -> void:
	for index in range(_projectiles.size() - 1, -1, -1):
		var entry := _projectiles[index]
		var object: Grabbable = entry.object.get_ref()
		entry.life -= get_physics_process_delta_time()
		if not is_instance_valid(object) or object.carrier != null or entry.life <= 0.0:
			_projectiles.remove_at(index)
			continue
		var target := player if entry.source == enemy else enemy
		var previous_target := _previous_player if target == player else _previous_enemy
		var half: Vector2 = (object.collider.shape as RectangleShape2D).size * 0.5
		var extent := object.collider.global_transform.x.abs() * half.x + object.collider.global_transform.y.abs() * half.y + Vector2.ONE
		var target_rect := _actor_rect(target)
		var rect := Rect2(target_rect.position - extent, target_rect.size + extent * 2.0)
		var from: Vector2 = entry.previous + target.position - previous_target
		if _segment_hits_rect(from, object.position, rect):
			if target == enemy:
				if room_index == 11 and enemy.stun_left <= 0.0 and room.all_weight_doors_open() and room.battle_arena.has_point(enemy.position) and room.battle_arena.has_point(player.position):
					defeat_hits += 1
					if defeat_hits >= defeat_hits_required:
						_complete("決着成功")
				if enemy.stun_left <= 0.0:
					enemy.apply_stun(2.0)
			elif _hit_grace <= 0.0:
				player.apply_stun(0.3, (object.position - entry.previous).normalized() * 140, player.wall_stamina_max / 3.0)
				_hit_grace = 0.4
			_projectiles.remove_at(index)
		elif object.linear_velocity.length() < 100.0:
			_projectiles.remove_at(index)
		else:
			entry.previous = object.position


static func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false


func _actor_rect(actor: PlayerController) -> Rect2:
	var dimensions := Vector2(52, 36) if abs(actor.gravity_direction) == 2 else Vector2(36, 52)
	return Rect2(actor.position - dimensions * 0.5, dimensions)


func _out_of_course(actor: PlayerController) -> bool:
	return not Rect2(Vector2(-65, -150), room.size + Vector2(130, 300)).has_point(actor.position)


func _touches_hazard(actor: PlayerController, previous: Vector2) -> bool:
	var half := _actor_rect(actor).size * 0.5
	var rectangles: Array = room.hazards.duplicate()
	for entry in room.moving_hazards:
		rectangles.append(entry.current)
	for rect: Rect2 in rectangles:
		if _segment_hits_rect(previous, actor.position, Rect2(rect.position - half, rect.size + half * 2.0)):
			return true
	return false


func _complete(result: String) -> void:
	if completed or _game_over_pending:
		return
	completed = true
	ending = result
	player.controls_enabled = false
	enemy.controls_enabled = false
	_message.hide()
	_completion.show()
	_hint.text = "%s！　ステージ6をクリアしました" % result


func _update_camera() -> void:
	camera.position = player.position.clamp(Vector2(640, 360), room.size - Vector2(640, 360))


func _update_hud() -> void:
	_title.text = "ステージ6　追跡者の終域　｜　%02d / 12　%s" % [room_index + 1, StageSixRoom.TITLES[room_index]]
	var chance := roundi(capture_probability(player.get_wall_stamina(), player.wall_stamina_max) * 100)
	var direction: String = {1: "↓", -1: "↑", 2: "→", -2: "←"}[player.gravity_direction]
	_status.text = "重力 %s　 捕獲時の失敗率 %3d%%　 ダッシュ %s　 追加ジャンプ %d　｜　%s" % [direction, chance, "可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), "追跡中" if enemy.get("active") else ("追跡まで %.1f秒" % _chase_delay if _chase_delay >= 0 else "準備区間：入口から進むと追跡開始")]
	_stamina.max_value = player.wall_stamina_max
	_stamina.value = player.get_wall_stamina()
	if not completed:
		_hint.text = StageSixRoom.HINTS[room_index]
		if room_index == 11:
			_hint.text += "\n決着 %d/%d（怯み中は無効）　逃走封印 あと%d秒 / 鍵 %s" % [defeat_hits, defeat_hits_required, ceili(maxf(0.0, escape_seconds - escape_elapsed)), "取得済" if room.key_collected else "未取得"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _game_over_pending:
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


func set_help_visible(value: bool) -> void:
	if completed:
		return
	help_visible = value
	_help.visible = value
	get_tree().paused = value
	if value:
		_help.get_node("Rows/Resume").grab_focus()
	else:
		get_viewport().gui_release_focus()


func _return_to_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _exit_tree() -> void:
	get_tree().paused = false


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	var info := _panel(Rect2(16, 12, 1020, 112))
	hud.add_child(info)
	var rows := VBoxContainer.new()
	info.add_child(rows)
	_title = _text("", 24)
	rows.add_child(_title)
	_status = _text("", 18)
	rows.add_child(_status)
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(340, 14)
	_stamina.show_percentage = false
	_stamina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("8dd9ab")
	fill.set_corner_radius_all(5)
	_stamina.add_theme_stylebox_override("fill", fill)
	var gauge := HBoxContainer.new()
	gauge.add_theme_constant_override("separation", 12)
	gauge.add_child(_text("壁スタミナ", 16))
	gauge.add_child(_stamina)
	rows.add_child(gauge)
	var help_button := Button.new()
	help_button.position = Vector2(1050, 16)
	help_button.size = Vector2(212, 48)
	help_button.text = "操作・やり直し [H]"
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.pressed.connect(func(): set_help_visible(not help_visible))
	hud.add_child(help_button)
	var footer := _panel(Rect2(16, 604, 1248, 104))
	hud.add_child(footer)
	_hint = _text("", 19)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_hint)
	_message = _text("", 27)
	_message.position = Vector2(120, 270)
	_message.size = Vector2(1040, 120)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.hide()
	hud.add_child(_message)
	_completion = Label.new()
	_completion.name = "Completion"
	_completion.set_script(CLEAR)
	_completion.hide()
	hud.add_child(_completion)
	_help = _panel(Rect2(280, 140, 720, 460))
	_help.name = "Help"
	_help.hide()
	hud.add_child(_help)
	var menu := VBoxContainer.new()
	menu.name = "Rows"
	menu.add_theme_constant_override("separation", 18)
	_help.add_child(menu)
	menu.add_child(_text("ステージ6　操作とルール", 30))
	menu.add_child(_text("移動 WASD / 方向キー / スティック\nジャンプ Space / A　 ダッシュ X / B\n持つ Shift / ZL・ZR　動きながら離すと投げる\n横重力の歩行は↑↓。捕獲失敗でステージ選択へ。\n落下・トゲ・R / Startは現在の部屋をやり直す。", 20))
	for label in ["続ける", "この部屋をやり直す", "ステージ選択へ戻る"]:
		var button := Button.new()
		button.custom_minimum_size.y = 48
		button.text = label
		menu.add_child(button)
		match label:
			"続ける":
				button.name = "Resume"
				button.pressed.connect(func(): set_help_visible(false))
			"この部屋をやり直す":
				button.pressed.connect(func(): set_help_visible(false); player.respawn())
			_:
				button.pressed.connect(_return_to_select)


func _panel(rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14243bed")
	style.border_color = Color("6f9fba")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0f4ff"))
	label.add_theme_color_override("font_outline_color", Color("102034"))
	label.add_theme_constant_override("outline_size", 4)
	return label
