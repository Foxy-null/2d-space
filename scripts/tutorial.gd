extends Node2D

enum Phase { RUN, SLOW, WAIT, LANDING, FADE, CLEAR_INTRO, CLEAR }
const SLOW_DURATION := 0.42
const HALF_PLAYER := Vector2(18, 26)
const SCROLL_POSITION := Vector2(990, 260)
const CLEAR_IMAGES := [preload("res://assets/ui/stage_1_clear/background.png"), preload("res://assets/ui/stage_1_clear/rocket.png"), preload("res://assets/ui/stage_1_clear/text.png")]

var room_index := 0
var phase := Phase.RUN
var completed := false
var transitioning := false
var camera: Camera2D
var rooms: Node2D
var bridge: TutorialBridge
var _phase_elapsed := 0.0
var _clear_motion_time := 0.0
var _final_jump := false
var _wall_mantled := false
var _wall_guide_done := false
var _dash_armed := false
var _slow_start := Vector2.ZERO
var _slow_velocity := Vector2.ZERO
var _slow_bridge_time := 0.0
var _clear_accept_ready := false
var _leaving := false
var _death_pending := false
var _bubble: PanelContainer
var _prompt: Label
var _settings_button: Button
var _info: Label
var _fade: ColorRect
var _clear_art: Control
var _clear_layers: Array[TextureRect] = []
var _return_button: Button

@onready var player: PlayerController = $Player
@onready var ninja: AnimatedSprite2D = $Player/Visuals/Body


func _ready() -> void:
	process_physics_priority = 20
	player.get_node("Camera2D").enabled = false
	rooms = Node2D.new()
	rooms.name = "Rooms"
	rooms.z_index = -10
	rooms.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rooms)
	for index in 3:
		_build_room(index)
	camera = Camera2D.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(camera)
	camera.make_current()
	_build_ui()
	player.respawned.connect(_on_respawned)
	player.movement_action.connect(_on_movement)
	InputSettings.bindings_changed.connect(_update_prompt)
	_enter_room(0, false)
	StageIntro.play(self, player, camera)


func _build_room(index: int) -> void:
	var room := Node2D.new()
	room.position.x = TutorialLandscape.ORIGINS[index]
	rooms.add_child(room)
	var landscape := TutorialLandscape.new()
	landscape.room_index = index
	room.add_child(landscape)
	for polygon in TutorialLandscape.landforms(index):
		var body := StaticBody2D.new()
		var collision := CollisionPolygon2D.new()
		collision.polygon = polygon
		body.add_child(collision)
		room.add_child(body)
	for plank in TutorialLandscape.one_way_platforms(index):
		var body := StaticBody2D.new()
		body.name = "WoodPlatform%d" % room.get_child_count()
		body.position = plank.get_center()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = plank.size
		collision.shape = shape
		collision.one_way_collision = true
		body.add_child(collision)
		room.add_child(body)
	for hazard in TutorialLandscape.spikes(index):
		for x in range(int(hazard.position.x), int(hazard.end.x), 17):
			var area := Area2D.new()
			area.collision_layer = 0
			var collision := CollisionPolygon2D.new()
			collision.polygon = PackedVector2Array([Vector2(x, hazard.end.y), Vector2(x + 8, hazard.position.y), Vector2(x + 17, hazard.end.y)])
			area.add_child(collision)
			room.add_child(area)
			area.body_entered.connect(func(body):
				if body == player and room_index == index and phase == Phase.RUN:
					_queue_death()
			)
	if index == 1:
		var scroll := preload("res://scenes/scroll_collectible.tscn").instantiate() as ScrollCollectible
		scroll.position = SCROLL_POSITION
		scroll.stage_id = "tutorial"
		scroll.scroll_id = CollectionProgress.TUTORIAL_SCROLL
		room.add_child(scroll)
	if index == 2:
		bridge = TutorialBridge.new()
		room.add_child(bridge)


func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	_info = Label.new()
	_info.position = Vector2(24, 18)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	hud.add_child(_info)
	var pause := Button.new()
	pause.name = "PauseButton"
	pause.focus_mode = Control.FOCUS_NONE
	pause.text = "ポーズ [Esc]"
	pause.position = Vector2(1060, 18)
	pause.size = Vector2(196, 44)
	pause.pressed.connect($PauseMenu.open)
	hud.add_child(pause)
	_bubble = PanelContainer.new()
	_bubble.position = Vector2(540, 110)
	_bubble.custom_minimum_size = Vector2(440, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8df")
	style.border_color = Color("25251f")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_bubble.add_theme_stylebox_override("panel", style)
	hud.add_child(_bubble)
	var rows := VBoxContainer.new()
	_bubble.add_child(rows)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 32)
	_prompt.add_theme_color_override("font_color", Color("25251f"))
	rows.add_child(_prompt)
	_settings_button = Button.new()
	_settings_button.text = "操作設定を開く"
	_settings_button.custom_minimum_size.y = 44
	_settings_button.pressed.connect(InputSettings.open_settings)
	rows.add_child(_settings_button)
	var ending := CanvasLayer.new()
	ending.layer = 20
	add_child(ending)
	_fade = ColorRect.new()
	_fade.size = Vector2(1280, 720)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending.add_child(_fade)
	_clear_art = Control.new()
	_clear_art.size = Vector2(1280, 720)
	_clear_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending.add_child(_clear_art)
	for texture in CLEAR_IMAGES:
		var image := TextureRect.new()
		image.texture = texture
		image.size = Vector2(1280, 720)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clear_art.add_child(image)
		_clear_layers.append(image)
	_return_button = Button.new()
	_return_button.text = "ステージ選択へ"
	_return_button.position = Vector2(450, 626)
	_return_button.size = Vector2(380, 62)
	_return_button.theme = preload("res://assets/ui/menu-theme.tres")
	_return_button.pressed.connect(_return_to_select)
	ending.add_child(_return_button)
	_clear_art.hide()
	_return_button.hide()


func _enter_room(index: int, from_right: bool) -> void:
	room_index = clampi(index, 0, 2)
	for i in 3:
		rooms.get_child(i).visible = i == room_index
	var x := TutorialLandscape.WIDTHS[room_index] - 64 if from_right else 72.0
	var floor_y: float = TutorialLandscape.RIGHT_FLOORS[room_index] if from_right else TutorialLandscape.LEFT_FLOORS[room_index]
	player.set_respawn_position(Vector2(TutorialLandscape.ORIGINS[room_index] + x, floor_y - 26))
	player.respawn(true)


func _on_respawned() -> void:
	if completed:
		GameAudio.reset_scene()
	Engine.time_scale = 1.0
	GameAudio.music.pitch_scale = 1.0
	GameAudio.music.stream_paused = false
	get_tree().paused = false
	completed = false
	phase = Phase.RUN
	_phase_elapsed = 0.0
	_clear_motion_time = 0.0
	_final_jump = false
	_death_pending = false
	_wall_mantled = false
	_wall_guide_done = false
	player.controls_enabled = true
	ninja.set_process(true)
	player.dash_enabled = false
	bridge.reset()
	_fade.color.a = 0.0
	_clear_art.hide()
	_return_button.hide()
	_update_prompt()
	_update_camera()


func _queue_death() -> void:
	if _death_pending:
		return
	_death_pending = true
	_finish_death.call_deferred()


func _finish_death() -> void:
	if _death_pending and phase == Phase.RUN:
		player.respawn()


func _on_movement(action: String) -> void:
	if room_index == 1 and action == "mantle":
		_wall_mantled = true
	if room_index == 2 and action == "jump":
		var x := player.position.x - TutorialLandscape.ORIGINS[2]
		_final_jump = x >= 2280 and x <= 2440 and player.velocity.x > 250


func _menu_active() -> bool:
	return $PauseMenu.overlay.visible or InputSettings.panel.visible


func _physics_process(delta: float) -> void:
	if _menu_active():
		return
	if phase == Phase.LANDING:
		if player.is_dashing():
			player._tick_dash(delta, false)
		else:
			var target := 360.0 if player.position.x < TutorialLandscape.ORIGINS[2] + 2800 else 0.0
			player.velocity.x = move_toward(player.velocity.x, target, player.air_acceleration * delta)
			player.velocity.y += player.gravity_acceleration * delta
			player._move_player()
		player._contacts_valid = true
		if player.is_on_floor() and player.position.x >= TutorialLandscape.ORIGINS[2] + 2722:
			_complete()
		_update_camera()
		return
	if phase != Phase.RUN:
		return
	var local := player.position - Vector2(TutorialLandscape.ORIGINS[room_index], 0)
	if local.y > TutorialLandscape.HEIGHTS[room_index] - HALF_PLAYER.y or local.y < -160:
		player.respawn()
		return
	if local.x > TutorialLandscape.WIDTHS[room_index] and room_index < 2:
		_enter_room(room_index + 1, false)
		return
	if local.x < 0 and room_index > 0:
		_enter_room(room_index - 1, true)
		return
	if room_index == 0 and local.x < 18:
		player.position.x = 18
	if room_index == 1 and _wall_mantled and player.is_on_floor():
		_wall_guide_done = true
		_update_prompt()
	if room_index == 2:
		if not bridge.running and player.is_on_floor() and local.x >= 320 and local.x < 2680 and player.velocity.x > 5:
			bridge.running = true
			bridge.front = local.x - 96.0
		if player.is_on_floor():
			_final_jump = false
		if local.x >= 2500 and not player.is_on_floor():
			bridge.collapse_tip()
		if bridge.tip_collapsed and local.y >= 535 and player.velocity.y > 0 and _tip_would_catch(local):
			_start_slow()
	_update_camera()


func _tip_would_catch(local: Vector2) -> bool:
	if not _final_jump or player.velocity.x < 250:
		return false
	var discriminant := player.velocity.y * player.velocity.y + 2.0 * player.gravity_acceleration * (594.0 - local.y)
	if discriminant < 0:
		return false
	var remaining := (-player.velocity.y + sqrt(discriminant)) / player.gravity_acceleration
	var landing_x := local.x + player.velocity.x * remaining
	return remaining >= 0 and landing_x >= 2582 and landing_x <= 2698


func _start_slow() -> void:
	phase = Phase.SLOW
	_phase_elapsed = 0.0
	_slow_start = player.position
	_slow_velocity = player.velocity
	_slow_bridge_time = bridge.elapsed
	player.controls_enabled = false
	ninja.set_process(false)
	ninja.play("bonk")


func _process(delta: float) -> void:
	if _menu_active():
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_phase_elapsed += real_delta
	match phase:
		Phase.SLOW:
			var progress := clampf(_phase_elapsed / SLOW_DURATION, 0, 1)
			_place_slow(progress)
			Engine.time_scale = 0.06 + 0.94 * pow(1.0 - progress, 2)
			GameAudio.music.pitch_scale = Engine.time_scale
			if progress >= 1.0:
				_wait_for_dash()
		Phase.CLEAR_INTRO:
			_clear_art.modulate.a = minf(1.0, _phase_elapsed / 0.65)
			if _phase_elapsed >= 0.65:
				_show_clear()
		Phase.FADE:
			_fade.color.a = minf(1.0, _phase_elapsed / 0.45)
			if _phase_elapsed >= 0.45:
				_start_clear_intro()
		Phase.CLEAR:
			if not Input.is_action_pressed("ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_clear_accept_ready = true
				_return_button.disabled = false
				if get_viewport().gui_get_focus_owner() == null:
					_return_button.grab_focus()
	if phase in [Phase.CLEAR_INTRO, Phase.CLEAR] and DisplayServer.accessibility_should_reduce_animation() != 1:
		_clear_motion_time += real_delta
		_clear_layers[0].position.x = sin(_clear_motion_time * 0.35) * 2.0
		_clear_layers[1].position.y = sin(_clear_motion_time * 1.3) * 6.0
		_clear_layers[2].position.y = sin(_clear_motion_time * 0.55) * 2.0
	_update_camera()
	_info.text = "城から星空へ　%d / 3　　巻物 %d / 1" % [room_index + 1, CollectionProgress.get_count("tutorial")]


func _place_slow(progress: float) -> void:
	var physical_time := SLOW_DURATION * (0.06 * progress + 0.94 * (progress - progress * progress + progress * progress * progress / 3.0))
	player.position = _slow_start + _slow_velocity * physical_time + Vector2(0, player.gravity_acceleration * physical_time * physical_time / 2)
	player.velocity = _slow_velocity + Vector2(0, player.gravity_acceleration * physical_time)


func _wait_for_dash() -> void:
	_place_slow(1.0)
	var missing_world_time := SLOW_DURATION * (0.06 + 0.94 / 3.0) - (bridge.elapsed - _slow_bridge_time)
	if missing_world_time > 0:
		bridge.advance(missing_world_time)
	Engine.time_scale = 1.0
	phase = Phase.WAIT
	GameAudio.music.stream_paused = true
	_dash_armed = not Input.is_action_pressed("dash")
	get_tree().paused = true
	_update_prompt()


func _input(event: InputEvent) -> void:
	if phase != Phase.WAIT or _menu_active() or event.is_echo():
		return
	if event.is_action_released("dash"):
		_dash_armed = true
	if not _dash_armed or not event.is_action_pressed("dash"):
		return
	_dash_armed = false
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.is_zero_approx():
		return
	var angle := roundf(direction.angle() / (PI / 4.0)) * (PI / 4.0)
	if Vector2.RIGHT.rotated(angle).round() != Vector2(1, -1):
		return
	get_viewport().set_input_as_handled()
	phase = Phase.LANDING
	GameAudio.music.pitch_scale = 1.0
	GameAudio.music.stream_paused = false
	ninja.set_process(true)
	player.dash_enabled = true
	player._start_dash(false)
	get_tree().paused = false
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.CLEAR and _clear_accept_ready and not _menu_active() and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_select()


func _update_prompt() -> void:
	if not is_instance_valid(_bubble):
		return
	var wall := room_index == 1 and not _wall_guide_done and phase == Phase.RUN
	_bubble.visible = wall or phase == Phase.WAIT
	if not _bubble.visible:
		return
	var action := "wall_grab" if wall else "dash"
	var binding: String = InputSettings.binding_label(action)
	_prompt.text = ("壁登り\n%s ＋ ↑" if wall else "ダッシュ\n↗ ＋ %s") % binding
	_bubble.position = Vector2(260, 220) if wall else Vector2(560, 110)
	_settings_button.visible = binding == "未割り当て" or InputSettings.binding_label("move_up") == "未割り当て" or (not wall and InputSettings.binding_label("move_right") == "未割り当て")


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var origin: float = TutorialLandscape.ORIGINS[room_index]
	camera.position = Vector2(clampf(player.position.x, origin + 640, origin + TutorialLandscape.WIDTHS[room_index] - 640), clampf(player.position.y, 360, TutorialLandscape.HEIGHTS[room_index] - 360))
	camera.reset_smoothing()


func _complete() -> void:
	completed = true
	CollectionProgress.mark_cleared("tutorial")
	phase = Phase.FADE
	_phase_elapsed = 0.0
	player.velocity = Vector2.ZERO
	get_tree().paused = true


func _start_clear_intro() -> void:
	GameAudio.play_clear()
	phase = Phase.CLEAR_INTRO
	_phase_elapsed = 0.0
	_clear_art.modulate.a = 0.0
	_clear_art.show()


func _show_clear() -> void:
	GameAudio.play_clear()
	phase = Phase.CLEAR
	_phase_elapsed = 0.0
	_fade.color.a = 1.0
	_clear_art.modulate.a = 1.0
	_clear_art.show()
	_clear_accept_ready = false
	_return_button.disabled = true
	_return_button.show()


func can_skip_cinematic() -> bool:
	return phase in [Phase.SLOW, Phase.FADE, Phase.CLEAR_INTRO]


func skip_cinematic() -> void:
	get_viewport().set_input_as_handled()
	if phase == Phase.SLOW:
		_wait_for_dash()
	elif phase in [Phase.FADE, Phase.CLEAR_INTRO]:
		_show_clear()


func _return_to_select() -> void:
	if _leaving or not _clear_accept_ready:
		return
	_leaving = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if phase != Phase.RUN:
		get_tree().paused = false
