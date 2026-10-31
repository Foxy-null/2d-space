extends Node2D

enum Phase { RUN, WALK, BOARD, FADE, CLEAR_INTRO, CLEAR }
const CLEAR_IMAGES := [preload("res://assets/ui/stage_1_clear/background.png"), preload("res://assets/ui/stage_1_clear/rocket.png"), preload("res://assets/ui/stage_1_clear/text.png")]
const HINTS := ["壁を登り、トゲを越えて右上へ。", "右のバネから壁キックとダッシュで上へ。", "中央のトゲを越えて右へ。左には寄り道。", "青い板は乗ると崩れます。足場をつないで上へ。", "壁つかみ＋ジャンプで柱を越え、ダッシュで次の柱へ。", "バネの上昇から柱を越えて、右上へ。", "ロケットへ近づこう。", "空中でダッシュを回復して、巻物を持ち帰ろう。", "崩れる板を渡り、右上の巻物へ。", "赤いバンパーで跳ね、右上の巻物へ。"]

var room_index := 0
var connections := TowerLandscape.connections()
var phase := Phase.RUN
var completed := false
var hints_visible := false
var rooms: Node2D
var camera: Camera2D
var _phase_elapsed := 0.0
var _clear_motion_time := 0.0
var _clear_accept_ready := false
var _death_pending := false
var _leaving := false
var _info: Label
var _hint: Label
var _fade: ColorRect
var _clear_art: Control
var _clear_layers: Array[TextureRect] = []
var _return_button: Button

@onready var player: PlayerController = $Player


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	rooms = Node2D.new()
	rooms.name = "Rooms"
	rooms.z_index = -10
	rooms.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rooms)
	for index in 10:
		_build_room(index)
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(camera)
	camera.make_current()
	var sky := CanvasLayer.new()
	sky.name = "Sky"
	sky.layer = -20
	sky.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sky)
	var backdrop := preload("res://scripts/ascent_backdrop.gd").new()
	backdrop.name = "Backdrop"
	sky.add_child(backdrop)
	_build_ui()
	_enter_room(0, TowerLandscape.start())
	StageIntro.play(self, player, camera)


func _build_room(index: int) -> void:
	var room := Node2D.new()
	room.name = "Room%d" % (index + 1)
	room.position = TowerLandscape.origin(index)
	rooms.add_child(room)
	var landscape := TowerLandscape.new()
	landscape.room_index = index
	room.add_child(landscape)
	for polygon in TowerLandscape.landforms(index):
		var body := StaticBody2D.new()
		var collision := CollisionPolygon2D.new()
		collision.polygon = polygon
		body.add_child(collision)
		room.add_child(body)
	var spikes := Area2D.new()
	spikes.name = "Spikes"
	spikes.collision_layer = 0
	for triangle in TowerLandscape.spike_triangles(index):
		var collision := CollisionPolygon2D.new()
		collision.polygon = triangle
		spikes.add_child(collision)
	room.add_child(spikes)
	spikes.body_entered.connect(func(body):
		if body == player and room_index == index and phase == Phase.RUN:
			_queue_death()
	)
	for rect in TowerLandscape.planks(index):
		var plank := CrumblingPlatform.new()
		plank.position = rect.position
		plank.size = rect.size
		plank.player = player
		room.add_child(plank)
	for spring in TowerLandscape.springs(index):
		var object := preload("res://scenes/spring.tscn").instantiate()
		object.position = Vector2(spring.x, spring.y)
		object.spring_speed = spring.z
		room.add_child(object)
	for location in TowerLandscape.crystals(index):
		var crystal := preload("res://scenes/refill_crystal.tscn").instantiate()
		crystal.set_script(preload("res://scripts/tower_refill_crystal.gd"))
		crystal.position = location
		room.add_child(crystal)
	if TowerLandscape.SCROLLS.has(index):
		var scroll := preload("res://scenes/scroll_collectible.tscn").instantiate() as ScrollCollectible
		scroll.name = "Scroll"
		scroll.position = TowerLandscape.SCROLLS[index] * TowerLandscape.room_scale(index)
		scroll.stage_id = "tower"
		scroll.scroll_id = TowerLandscape.SCROLL_IDS[index]
		room.add_child(scroll)
	if index == 9:
		var bumper := preload("res://scenes/pinball_spring.tscn").instantiate()
		bumper.name = "Bumper"
		bumper.position = TowerLandscape.BUMPER * TowerLandscape.room_scale(index)
		bumper.minimum_bounce_speed = 1450
		bumper.maximum_bounce_speed = 1800
		room.add_child(bumper)


func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	_info = Label.new()
	_info.position = Vector2(24, 18)
	_info.add_theme_font_size_override("font_size", 19)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	hud.add_child(_info)
	_hint = Label.new()
	_hint.position = Vector2(24, 50)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	hud.add_child(_hint)
	var pause := Button.new()
	pause.name = "PauseButton"
	pause.focus_mode = Control.FOCUS_NONE
	pause.text = "ポーズ [Esc]"
	pause.position = Vector2(1060, 18)
	pause.size = Vector2(196, 44)
	pause.pressed.connect($PauseMenu.open)
	hud.add_child(pause)
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
	set_hints_visible(false)


func _enter_room(index: int, spawn: Vector2) -> void:
	room_index = index
	for room in rooms.get_children():
		room.visible = room.get_index() == index
		room.process_mode = Node.PROCESS_MODE_PAUSABLE if room.visible else Node.PROCESS_MODE_DISABLED
	player.set_respawn_position(TowerLandscape.origin(index) + spawn)
	player.respawn(true)
	_update_camera()


func _on_respawned() -> void:
	if completed:
		GameAudio.reset_scene()
	completed = false
	phase = Phase.RUN
	_phase_elapsed = 0.0
	_clear_motion_time = 0.0
	_death_pending = false
	_clear_accept_ready = false
	player.controls_enabled = true
	player.visuals.modulate.a = 1.0
	get_tree().paused = false
	for object in rooms.get_child(room_index).get_children():
		if object.has_method("reset_for_respawn"):
			object.reset_for_respawn()
	GameAudio.set_quiet(room_index >= 7)
	if is_instance_valid(_fade):
		_fade.color.a = 0.0
		_clear_art.hide()
		_return_button.hide()
	_update_camera()


func _menu_active() -> bool:
	return $PauseMenu.overlay.visible or InputSettings.panel.visible


func _physics_process(delta: float) -> void:
	if _menu_active():
		return
	if phase == Phase.WALK:
		var target := TowerLandscape.origin(6).x + TowerLandscape.ROCKET_DOOR * TowerLandscape.room_scale(6)
		player.velocity.x = minf(150, maxf(0, target - player.position.x) / delta)
		player.velocity.y += player.gravity_acceleration * delta
		player._move_player()
		if absf(player.position.x - target) < 2:
			phase = Phase.BOARD
			_phase_elapsed = 0
	elif phase == Phase.RUN:
		var local := player.position - TowerLandscape.origin(room_index)
		for connection in connections:
			for side in [0, 3]:
				if connection[side] == room_index and connection[side + 1].has_point(local):
					var destination: int = 3 - side
					_enter_room(connection[destination], connection[destination + 2])
					return
		if local.y > TowerLandscape.size(room_index).y + 60 or local.y < -100 or local.x < -80 or local.x > TowerLandscape.size(room_index).x + 80:
			_queue_death()
		elif room_index == 6 and local.x >= TowerLandscape.ROCKET_APPROACH * TowerLandscape.room_scale(6) and player.is_on_floor():
			phase = Phase.WALK
			_phase_elapsed = 0
			player.controls_enabled = false
			player.velocity = Vector2.ZERO
	_update_camera()


func _queue_death() -> void:
	if _death_pending:
		return
	_death_pending = true
	_finish_death.call_deferred()


func _finish_death() -> void:
	if _death_pending and phase == Phase.RUN:
		player.die()


func _process(delta: float) -> void:
	if _menu_active():
		return
	_phase_elapsed += delta
	match phase:
		Phase.BOARD:
			player.visuals.modulate.a = maxf(0, 1 - _phase_elapsed / 0.35)
			if _phase_elapsed >= 0.35:
				_complete()
		Phase.FADE:
			_fade.color.a = minf(1, _phase_elapsed / 0.45)
			if _phase_elapsed >= 0.45:
				_start_clear_intro()
		Phase.CLEAR_INTRO:
			_clear_art.modulate.a = minf(1, _phase_elapsed / 0.65)
			if _phase_elapsed >= 0.65:
				_show_clear()
		Phase.CLEAR:
			if not Input.is_action_pressed("ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_clear_accept_ready = true
				_return_button.disabled = false
				if get_viewport().gui_get_focus_owner() == null:
					_return_button.grab_focus()
	if phase in [Phase.CLEAR_INTRO, Phase.CLEAR] and DisplayServer.accessibility_should_reduce_animation() != 1:
		_clear_motion_time += delta
		_clear_layers[0].position.x = sin(_clear_motion_time * 0.35) * 2
		_clear_layers[1].position.y = sin(_clear_motion_time * 1.3) * 6
		_clear_layers[2].position.y = sin(_clear_motion_time * 0.55) * 2
	_info.text = "星のぼりの塔　%s　　巻物 %d / 4　　ダッシュ %s　壁 %.1f" % [TowerLandscape.TITLES[room_index], CollectionProgress.get_count("tower"), "●" if player.is_dash_ready() else "○", player.get_wall_stamina()]


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	if is_instance_valid(_hint):
		_hint.text = HINTS[room_index]
		_hint.visible = value


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var origin := TowerLandscape.origin(room_index)
	var size := TowerLandscape.size(room_index)
	var half_view := get_viewport_rect().size * 0.5 / camera.zoom
	camera.position = origin + size * 0.5
	if size.x > half_view.x * 2:
		camera.position.x = clampf(player.position.x, origin.x + half_view.x, origin.x + size.x - half_view.x)
	if size.y > half_view.y * 2:
		camera.position.y = clampf(player.position.y, origin.y + half_view.y, origin.y + size.y - half_view.y)
	camera.reset_smoothing()
	set_hints_visible(hints_visible)


func _complete() -> void:
	completed = true
	CollectionProgress.mark_cleared("tower")
	phase = Phase.FADE
	_phase_elapsed = 0
	player.velocity = Vector2.ZERO
	player.controls_enabled = false
	get_tree().paused = true


func _start_clear_intro() -> void:
	GameAudio.play_clear()
	phase = Phase.CLEAR_INTRO
	_phase_elapsed = 0
	_clear_art.modulate.a = 0
	_clear_art.show()


func _show_clear() -> void:
	if not completed:
		_complete()
	GameAudio.play_clear()
	phase = Phase.CLEAR
	_phase_elapsed = 0
	_fade.color.a = 1
	_clear_art.modulate.a = 1
	_clear_art.show()
	_clear_accept_ready = false
	_return_button.disabled = true
	_return_button.show()


func can_skip_cinematic() -> bool:
	return phase in [Phase.WALK, Phase.BOARD, Phase.FADE, Phase.CLEAR_INTRO]


func skip_cinematic() -> void:
	if can_skip_cinematic():
		_show_clear()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.CLEAR and _clear_accept_ready and not _menu_active() and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_select()


func _return_to_select() -> void:
	if _leaving or not _clear_accept_ready:
		return
	_leaving = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _exit_tree() -> void:
	if phase != Phase.RUN:
		get_tree().paused = false
