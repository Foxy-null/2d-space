extends Node2D

const PLAYER = preload("res://scenes/player.tscn")
const CHASER = preload("res://scripts/chaser.gd")
const ROOM = preload("res://scripts/stage_6_room.gd")
const BACKDROP = preload("res://scripts/stage_backdrop.gd")
const CLEAR = preload("res://scripts/stage_clear.gd")
const HELP = preload("res://scenes/stage_help.tscn")
const NEEDLE = preload("res://scripts/chaser_needle.gd")
const ASH_CLOUD = preload("res://scripts/ash_cloud.gd")

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
var _respawn_grace := 0.8
var _loading := false
var _generation := 0
var _previous_player := Vector2.ZERO
var _previous_enemy := Vector2.ZERO
var _player_arrived := false
var defeat_hits := 0
var escape_elapsed := 0.0
var _keep_enemy_on_respawn := false
var _enemy_indicator: Label
var _intro_left := 0.0
var _intro_seen := false
var _entry_left := 0.0
var _action: Label
var _intro_panel: PanelContainer
var _shake_left := 0.0
var shots_fired := 0
var clouds_cast := 0
var blocked_shots := 0
var _grab_frame: Line2D
var _grab_outline: Line2D
var _grab_hint: Label
var _grab_target: Grabbable
var _condition: Label
var _effects: Node2D
var _effect_left := 0.0
var _fade: ColorRect


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
	enemy.name = "Chaser"
	enemy.use_default_respawn_bounds = false
	_world.add_child(enemy)
	enemy.set("target", player)
	enemy.needle_attack.connect(_spawn_needles)
	enemy.ash_attack.connect(_spawn_ash_cloud)
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
	_grab_frame = Line2D.new()
	_grab_frame.name = "GrabTarget"
	_grab_frame.width = 7.0
	_grab_frame.default_color = Color("102034")
	_grab_frame.closed = true
	_grab_frame.z_index = 20
	_world.add_child(_grab_frame)
	_grab_outline = Line2D.new()
	_grab_outline.width = 3.0
	_grab_outline.default_color = Color("9cfff0")
	_grab_outline.closed = true
	_grab_frame.add_child(_grab_outline)
	_grab_hint = _text("", 20)
	_grab_hint.name = "GrabHint"
	_grab_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_grab_hint)
	_enemy_indicator = _text("", 18)
	_enemy_indicator.position = Vector2(25, 510)
	$HUD.add_child(_enemy_indicator)
	var action_panel := _panel(Rect2())
	action_panel.name = "EnemyAction"
	var action_style := action_panel.get_theme_stylebox("panel") as StyleBoxFlat
	action_style.content_margin_left = 8
	action_style.content_margin_right = 8
	action_style.content_margin_top = 4
	action_style.content_margin_bottom = 4
	$HUD.add_child(action_panel)
	_action = _text("", 18)
	action_panel.add_child(_action)
	_intro_panel = _panel(Rect2(240, 236, 800, 205))
	_intro_panel.name = "EnemyIntroduction"
	$HUD.add_child(_intro_panel)
	var intro := _text("UMA妖怪エイリアン\n星間山荒・大赤斑 が現れた！\n逃げろ！ 箱と傘を使って振り切ろう", 28)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_panel.add_child(intro)
	var breach_sound := AudioStreamPlayer.new()
	breach_sound.name = "BreachSound"
	breach_sound.stream = ArrivalSwitch._sound([90.0, 60.0, 120.0])
	breach_sound.volume_db = -9.0
	$HUD.add_child(breach_sound)
	_condition = _text("", 18)
	_condition.position = Vector2(28, 96)
	$HUD.add_child(_condition)
	_fade = ColorRect.new()
	_fade.size = get_viewport_rect().size
	_fade.color = Color(0.02, 0.03, 0.08, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_fade)
	_effects = Node2D.new()
	_effects.draw.connect(_draw_effects)
	$HUD.add_child(_effects)
	$HUD.move_child(_message, -1)
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
	enemy.set("course", room)
	enemy.set("preferred_item", room.preferred_item)
	enemy.call("reset_pursuit")
	enemy.set("active", false)
	_chase_delay = -1.0 if room.prepared else room.chase_delay
	_player_arrived = false
	defeat_hits = 0
	escape_elapsed = 0.0
	_immunity_left = 0.6
	_respawn_grace = 0.8
	_hit_grace = 0.0
	_capture_pending = false
	_message.hide()
	_intro_left = 0.0
	_intro_panel.hide()
	_intro_panel.modulate.a = 1.0
	_entry_left = 0.9 if index > 0 else 0.0
	room.set_entrance_intact(true)
	enemy.visuals.visible = index == 0
	if index > 0:
		_chase_delay = _entry_left
	if index == 0 and not _intro_seen:
		_intro_seen = true
		_intro_left = 2.8
		_intro_panel.show()
		_effect_left = 1.2
		$HUD/BreachSound.play()
	_loading = false
	transitioning = false
	player.controls_enabled = _intro_left <= 0.0
	enemy.controls_enabled = _intro_left <= 0.0
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	camera.reset_smoothing()
	_update_hud()


func _process(delta: float) -> void:
	_update_grab_hint()
	if not get_tree().paused or _game_over_pending or completed:
		_effect_left = maxf(0.0, _effect_left - delta)
	_effects.queue_redraw()


func _update_grab_hint() -> void:
	_grab_target = null
	if not get_tree().paused and not _loading and not transitioning and not completed and player.controls_enabled and player.stun_left <= 0.0:
		_grab_target = player.get_grab_candidate()
	_grab_frame.visible = _grab_target != null
	_grab_hint.visible = _grab_frame.visible
	if _grab_target == null:
		return
	var shape := _grab_target.collider.shape as RectangleShape2D
	var half := shape.size * 0.5 + Vector2(6, 6)
	var points := PackedVector2Array()
	var bounds := Rect2()
	var canvas := get_viewport().get_canvas_transform()
	for corner in [-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		var point: Vector2 = _grab_target.collider.global_transform * corner
		points.append(_grab_frame.to_local(point))
		var screen: Vector2 = canvas * point
		bounds = Rect2(screen, Vector2.ZERO) if points.size() == 1 else bounds.expand(screen)
	_grab_frame.points = points
	_grab_outline.points = points
	_grab_hint.text = "掴む：" + {"OBJECT": "箱", "HEAVY": "重い箱", "PARACHUTE": "傘", "JUMP": "相棒"}.get(_grab_target.carry_name, "物体")
	_grab_hint.reset_size()
	var bottom: float = ($HUD/Progress.position.y if $HUD/Progress.visible else _action.get_parent().position.y) - 8.0
	var y := bounds.position.y - _grab_hint.size.y - 8.0
	if y < 120.0:
		y = bounds.end.y + 8.0
	_grab_hint.position = Vector2(clampf(bounds.get_center().x - _grab_hint.size.x * 0.5, 16.0, get_viewport_rect().size.x - _grab_hint.size.x - 16.0), clampf(y, 120.0, bottom - _grab_hint.size.y))


func _physics_process(delta: float) -> void:
	if get_tree().paused or _loading or transitioning or help_visible or completed or _game_over_pending:
		return
	if _intro_left > 0.0:
		_intro_left = maxf(0.0, _intro_left - delta)
		if _intro_left <= 0.0:
			_intro_panel.hide()
			player.controls_enabled = true
			enemy.controls_enabled = true
		_intro_panel.modulate.a = clampf(_intro_left / 0.4, 0.0, 1.0)
		_update_camera()
		_update_hud()
		return
	if _entry_left > 0.0:
		_entry_left = maxf(0.0, _entry_left - delta)
		if _entry_left <= 0.0:
			room.set_entrance_intact(false)
			enemy.visuals.show()
			_shake_left = 0.25
			$HUD/BreachSound.play()
	_shake_left = maxf(0.0, _shake_left - delta)
	_immunity_left = maxf(0.0, _immunity_left - delta)
	_respawn_grace = maxf(0.0, _respawn_grace - delta)
	for actor in [player, enemy]:
		var held: Grabbable = actor.get_held_object()
		if held != null and held.carry_name == "PARACHUTE":
			held.shield_open = true
	_hit_grace = maxf(0.0, _hit_grace - delta)
	if _chase_delay < 0.0 and player.position.distance_to(room.spawn) > 155.0:
		_chase_delay = room.chase_delay
	elif _chase_delay >= 0.0:
		_chase_delay = maxf(0.0, _chase_delay - delta)
		if _chase_delay <= 0.0:
			enemy.set("active", true)
	_update_needles(delta)
	if _game_over_pending:
		return
	for cloud in room.get_node("AshClouds").get_children():
		cloud.advance(delta)
	_check_projectiles()
	if _game_over_pending:
		return
	if _touches_stuck_needle(player, _previous_player):
		_damage_player(player.wall_stamina_max * 0.15, Vector2.ZERO, true)
	if _game_over_pending:
		return
	if _out_of_course(player) or (_respawn_grace <= 0.0 and _touches_hazard(player, _previous_player)):
		_keep_enemy_on_respawn = true
		player.respawn(false, true)
		_keep_enemy_on_respawn = false
		return
	if _out_of_course(enemy) or _touches_hazard(enemy, _previous_enemy):
		enemy.call("reset_pursuit", true)
	_update_capture(delta)
	if _game_over_pending:
		return
	if room_index == ROOM.FINAL_ROOM:
		if enemy.get("active") and room.battle_arena.has_point(player.position) and room.battle_arena.has_point(enemy.position):
			escape_elapsed = minf(escape_seconds, escape_elapsed + delta)
		room.update_escape(escape_elapsed >= escape_seconds)
	if room_index == ROOM.FINAL_ROOM and room.seal_enemy(enemy, player):
		_complete("封じ込め成功")
	elif room.exit_open and (room.passage_rect.has_point(player.position) if room_index != ROOM.FINAL_ROOM else (_player_arrived or room.exit_rect.has_point(player.position))) and (room_index != ROOM.FINAL_ROOM or (room.all_weight_doors_open() and room.escape_unlocked)):
		if room_index == ROOM.FINAL_ROOM:
			_complete("逃走成功")
		else:
			transitioning = true
			_load_room.call_deferred(room_index + 1)
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	_update_hud()


func _on_player_respawned() -> void:
	if _loading or not is_instance_valid(room) or _game_over_pending:
		return
	_generation += 1
	_capture_pending = false
	_game_over_pending = false
	_intro_left = 0.0
	_intro_panel.hide()
	player.controls_enabled = not help_visible and not completed
	enemy.controls_enabled = not help_visible and not completed
	enemy.capture_windup = -1.0
	_hit_grace = 0.0
	_message.hide()
	_player_arrived = false
	if not _keep_enemy_on_respawn:
		_projectiles.clear()
		room.reset_state()
		enemy.call("reset_pursuit")
		enemy.set("active", false)
		_entry_left = 0.9 if room_index > 0 else 0.0
		room.set_entrance_intact(true)
		enemy.visuals.visible = room_index == 0
		_chase_delay = -1.0 if room.prepared else maxf(room.chase_delay, _entry_left)
		defeat_hits = 0
		escape_elapsed = 0.0
	_immunity_left = 0.6
	_respawn_grace = 0.8
	_previous_player = player.position
	_previous_enemy = enemy.position
	_update_camera()
	camera.reset_smoothing()


func _capture() -> void:
	if _capture_pending or enemy.get_held_object() != null:
		return
	_capture_pending = true
	escape_elapsed = 0.0
	if player.get_wall_stamina() <= 0.0:
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
	# Route points can be far overhead: a surviving grab must not launch into ceiling spikes.
	var tangent := player.get_walk_axis()
	var side := signf((back - player.position).dot(tangent))
	var direction: Vector2 = tangent * (side if side != 0.0 else -player.facing_direction)
	player.apply_stun(0.3, direction * 650.0 - player.get_gravity_vector() * 220.0)
	_immunity_left = 2.0
	_capture_pending = false
	await get_tree().create_timer(1.6, false).timeout
	if generation == _generation and not completed and not _game_over_pending:
		_message.hide()


func _update_capture(delta: float) -> void:
	if _capture_pending or _immunity_left > 0.0 or _hit_grace > 0.0 or player.stun_left > 0.0 or not enemy.can_capture():
		enemy.capture_windup = -1.0
		return
	var nearby := _actor_rect(enemy).grow(18).intersects(_actor_rect(player))
	if enemy.capture_windup < 0.0:
		if nearby:
			enemy.capture_windup = 0.25
		return
	enemy.capture_windup -= delta
	if not nearby or enemy.capture_windup <= 0.0:
		enemy.capture_windup = -1.0
		enemy.capture_recovery = 0.35
		if _actor_rect(enemy).grow(2).intersects(_actor_rect(player)):
			_capture()


func _game_over(reason := "捕獲されました") -> void:
	if _game_over_pending or completed:
		return
	var generation := _generation
	_game_over_pending = true
	_update_hud()
	player.controls_enabled = false
	enemy.controls_enabled = false
	$PauseMenu.set_process_input(false)
	$HUD/HelpButton.disabled = true
	$HUD/PauseButton.disabled = true
	get_tree().paused = true
	_message.text = reason + "\nこの部屋のチェックポイントからやり直します"
	_message.show()
	_effect_left = 1.2
	if DisplayServer.accessibility_should_reduce_animation() != 1:
		create_tween().tween_property(_fade, "color:a", 0.85, 1.0)
	await get_tree().create_timer(1.2, true).timeout
	if not is_inside_tree() or completed or generation != _generation:
		return
	_game_over_pending = false
	$PauseMenu.resume()
	$PauseMenu.set_process_input(true)
	$HUD/HelpButton.disabled = false
	$HUD/PauseButton.disabled = false
	_fade.color.a = 0.0
	player.respawn()
	_update_hud()


func _damage_player(amount: float, impulse := Vector2.ZERO, ground_needle := false) -> void:
	if completed or _game_over_pending or _hit_grace > 0.0 or _respawn_grace > 0.0:
		return
	if not ground_needle:
		player.apply_stun(0.2, impulse)
	player.apply_attack_damage(amount, ground_needle)
	_hit_grace = 0.75
	if player.get_wall_stamina() <= 0.0:
		_game_over("攻撃でスタミナが尽きました")


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
		var target_contact: float = NEEDLE._entry(from, object.position, rect)
		var candidates: Array[Dictionary] = []
		for needle in room.needles.get_children():
			if not needle.stuck or not needle.is_dangerous():
				continue
			var contact: float = NEEDLE._entry(entry.previous, object.position, Rect2(needle.tip_position() - extent, extent * 2.0))
			if contact < target_contact:
				candidates.append({"needle": needle, "at": contact})
		candidates.sort_custom(func(left, right): return left.at < right.at)
		var pinned := false
		for candidate in candidates:
			if candidate.needle.pin_box(object, player):
				pinned = true
				break
		if pinned:
			_projectiles.remove_at(index)
			continue
		if _segment_hits_rect(from, object.position, rect):
			if target == enemy:
				if room_index == ROOM.FINAL_ROOM and enemy.stun_left <= 0.0 and room.all_weight_doors_open() and room.battle_arena.has_point(enemy.position) and room.battle_arena.has_point(player.position):
					defeat_hits += 1
					if defeat_hits >= defeat_hits_required:
						_complete("決着成功")
				if enemy.stun_left <= 0.0:
					enemy.apply_stun(2.0)
			elif _hit_grace <= 0.0 and _respawn_grace <= 0.0:
				_damage_player(player.wall_stamina_max / 3.0, (object.position - entry.previous).normalized() * 140)
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
	if actor.is_in_group("spike_immune"):
		return false
	var half := _actor_rect(actor).size * 0.5
	for spike in room.spike_blocks:
		if SpikeBlock.segment_hits_box(previous - spike.previous_position, actor.position - spike.global_position, half + spike.hit_extent()):
			return true
	var rectangles: Array = room.hazards.duplicate()
	for entry in room.moving_hazards:
		rectangles.append(entry.current)
	for rect: Rect2 in rectangles:
		if _segment_hits_rect(previous, actor.position, Rect2(rect.position - half, rect.size + half * 2.0)):
			return true
	return false


func _touches_stuck_needle(actor: PlayerController, previous: Vector2) -> bool:
	if actor.is_in_group("spike_immune"):
		return false
	var half := _actor_rect(actor).size * 0.5
	for needle in room.needles.get_children():
		if needle.stuck and needle.is_dangerous() and _segment_hits_rect(previous, actor.position, Rect2(needle.tip_position() - half - Vector2(3, 3), half * 2.0 + Vector2(6, 6))):
			return true
	return false


func _complete(result: String) -> void:
	if completed or _game_over_pending:
		return
	completed = true
	ending = result
	player.controls_enabled = false
	enemy.controls_enabled = false
	enemy.set("defeated", result == "決着成功")
	enemy.set_physics_process(false)
	_message.hide()
	_completion.show()
	_hint.text = "%s！　ステージ6をクリアしました" % result
	_effect_left = 1.2
	if DisplayServer.accessibility_should_reduce_animation() != 1:
		var card: PanelContainer = _completion.get("card")
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 0.94
		card.modulate.a = 0.0
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale", Vector2.ONE, 0.4)
		tween.tween_property(card, "modulate:a", 1.0, 0.4)


func _update_camera() -> void:
	camera.offset = Vector2(sin(_shake_left * 120.0) * 8.0 * _shake_left / 0.25, 0) if _shake_left > 0.0 and DisplayServer.accessibility_should_reduce_animation() != 1 else Vector2.ZERO
	var target := player.position.clamp(Vector2(640, 360), room.size - Vector2(640, 360))
	if _intro_left > 0.0 and DisplayServer.accessibility_should_reduce_animation() != 1:
		var pullback := smoothstep(0.5, 2.8, 2.8 - _intro_left)
		camera.zoom = Vector2.ONE * lerpf(1.25, 1.0, pullback)
		camera.position = Vector2(350, target.y).lerp(target, pullback)
	else:
		camera.zoom = Vector2.ONE
		camera.position = target
	room.visible_area = Rect2(camera.position - Vector2(640, 360), Vector2(1280, 720))


func _update_hud() -> void:
	var capture_status := "捕獲注意（スタミナ0）" if player.get_wall_stamina() <= 0.0 else "捕獲をしのげる"
	var direction: String = {1: "↓", -1: "↑", 2: "→", -2: "←"}[player.gravity_direction]
	var pursuit: String = {"pursuit": "追跡中", "search": "探索中", "patrol": "見失った"}[enemy.get("awareness")] if enemy.get("active") else ("追跡まで %.1f秒" % _chase_delay if _chase_delay >= 0 else "準備中")
	_status.text = "部屋 %02d/%02d　重力 %s　 %s　 ダッシュ %s　 追加ジャンプ %d　｜　%s" % [room_index + 1, ROOM.ROOM_COUNT, direction, capture_status, "可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), pursuit]
	_stamina.max_value = player.wall_stamina_max
	_stamina.value = player.get_wall_stamina()
	_condition.text = "回復低下 %.1f秒" % player.recovery_slow_left if player.recovery_slow_left > 0.0 else ""
	if player.movement_slow_left > 0.0:
		_condition.text += "　減速 %.1f秒" % player.movement_slow_left
	_condition.modulate = Color("ffdc78")
	$HUD/Progress.visible = completed or room_index == ROOM.FINAL_ROOM
	if not completed and room_index == ROOM.FINAL_ROOM:
		_hint.text = "決着 %d/%d　 対峙あと%d秒　 鍵 %d/2　 封鎖 %s" % [defeat_hits, defeat_hits_required, ceili(maxf(0.0, escape_seconds - escape_elapsed)), room.keys_collected, "通電済→檻で敵を怯ませる→制御盤" if room.seal_button.is_pressed() else "奥の金の台へ重箱"]
	_enemy_indicator.visible = enemy.get("active") and not room.visible_area.grow(80).has_point(enemy.position) and not completed
	var offset := enemy.position - camera.position
	_enemy_indicator.text = "追跡者 %s　%s" % [("→" if offset.x > 0 else "←") if absf(offset.x) > absf(offset.y) else ("↓" if offset.y > 0 else "↑"), pursuit]

	var side := "→" if offset.x > 0.0 else "←"
	var action: String = enemy.action_description()
	if _entry_left > 0.0:
		action = "背後の壁が崩れそうだ！ 追跡者が突破してくる"
	elif room.exit_open and room_index != ROOM.FINAL_ROOM:
		action += "\n隔壁が開いた！ 緑の矢印の先へ走って次の部屋へ"
	_action.text = "%s 敵との距離 %dpx　%s" % [side, roundi(player.position.distance_to(enemy.position)), action]
	var action_panel := _action.get_parent() as PanelContainer
	action_panel.reset_size()
	action_panel.position = Vector2(16, 696 - action_panel.size.y)
	action_panel.visible = not completed and _intro_left <= 0.0
	$HUD/Progress.position.y = action_panel.position.y - $HUD/Progress.size.y - 12
	_enemy_indicator.position.y = ($HUD/Progress.position.y if $HUD/Progress.visible else action_panel.position.y) - 34
	if maxf(_respawn_grace, _hit_grace) > 0.0:
		player.modulate.a = 0.55 + 0.45 * absf(sin(maxf(_respawn_grace, _hit_grace) * 24.0))
	else:
		player.modulate.a = 1.0


func _help_text() -> String:
	var text := "追跡者の終域 — 全13部屋\nUMA妖怪エイリアン　星間山荒・大赤斑\n"
	text += "長針3連射、扇形5本、追尾トゲ6個、山なりの長針10本、短針18連射、灰の雨36本を状況に応じて使います。遠くへ逃げると灰雲で進路を先読みします。連射は見えている動きへゆっくり狙いを変えます。攻撃後の隙には掴まれません。\n屋根の下や傘は頭上の雨を防ぎ、箱は飛行針を受け止めます。ダッシュ中は傘が閉じます。地形に残った針の先端に触れるとスタミナ15%減と1秒間の減速です。回復低下中は着地しても徐々に回復します。\n敵は壁越しに忍者の位置を知りません。見失うと最後に見た場所を探し、やがて巡回します。画面外の行動もメッセージに表示します。\n地形に刺さった針の露出した後端へ箱を投げると固定足場になります。灰と連射の破片は数秒で崩れますが、箱で作った足場は残ります。全ての棘は敵に無効。箱の投擲は有効です。\n\n道中の到着スイッチは隔壁を開きます。開いた通路を走り抜けると次の部屋へ進み、敵は壁を破って追ってきます。\n\n"
	if room_index == ROOM.FINAL_ROOM:
		text += "どれか一つでクリア。\n決着：怯んでいない敵へ箱を%d回当てる。\n封鎖：逃走出口の下の区画へ進む。近くの重箱をくぼみの金の台へ置いて通電→右の檻へ敵を誘い箱を当てる→怯んでいる間に左の高台の制御盤を自分で踏む。箱を置くだけ・制御盤に先に乗って待つだけでは封鎖しません。\n逃走：同じ区画の敵と%d秒対峙し、左右の高所の鍵を2つ取って最も右上の到着台へ。見失わせても解除は進み、捕獲では時間を数え直します。\n\n" % [defeat_hits_required, ceili(escape_seconds)]
	text += "この部屋の進め方\n" + ROOM.HINTS[room_index]
	text += "\n\n物体と捕獲\n金の輪が供給場所です。スイッチに置いた箱と固定した箱を敵は取りません。敵が物を持つ間も掴まれません。投擲・飛行弾はスタミナを3分の1減らし、被弾後は4秒間回復が遅くなります。追加被弾で2秒ずつ、最大8秒まで延長します。通常時の着地は即時全回復です。こちらの箱は敵を2秒止めます。\n掴む予告から離れると避けられます。スタミナが少しでも残っていれば捕獲をしのぎ、投げ返されます。スタミナ0での捕獲か、攻撃によるスタミナ切れでは、演出後にこの部屋のチェックポイントから自動でやり直します。スタミナと状態異常を回復し、敵・針・部屋の仕掛けも初期状態へ戻します。"
	text += "\n\n復帰と操作\n落下・固定棘・移動棘では自分だけ入口へ戻り、敵・箱・残る針・雲・目標の進捗を維持します。スタート付近の地形に刺さった針は0.6秒で消え、箱を固定した足場は残ります。R / Startか下のやり直しでは部屋全体を初期化しますが、残っている回復低下と減速は維持します。横重力では↑↓で壁沿いを歩き、Space / A・×で重力に逆らって跳びます。荷物を置けばShiftで壁登りができます。"
	return text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _game_over_pending or $PauseMenu.overlay.visible:
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
	player.controls_enabled = not value
	enemy.controls_enabled = not value
	get_tree().paused = value
	if value:
		_help.call("show_hint", "ステージ6　%02d / %02d　%s" % [room_index + 1, ROOM.ROOM_COUNT, StageSixRoom.TITLES[room_index]], _help_text())
		_help.get_node("Rows/Actions/Resume").grab_focus()
	else:
		get_viewport().gui_release_focus()


func _return_to_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func retry_room() -> void:
	if not _game_over_pending:
		player.respawn(true, true)


func _draw_effects() -> void:
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		return
	var pulse := clampf(_effect_left / 1.2, 0.0, 1.0)
	if pulse <= 0.0:
		return
	var center := get_viewport_rect().size * 0.5
	for index in 16:
		var direction := Vector2.RIGHT.rotated(TAU * index / 16.0)
		var at := center + direction * (70.0 + (1.0 - pulse) * 330.0)
		_effects.draw_line(at, at + direction * (20.0 + (1.0 - pulse) * 90.0), Color(1.0, 0.84, 0.38, pulse * 0.7), 3.0, true)
		_effects.draw_circle(at, 3.0 * pulse, Color(1.0, 0.96, 0.77, pulse))


func _exit_tree() -> void:
	get_tree().paused = false


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	var info := _panel(Rect2(16, 12, 990, 80))
	hud.add_child(info)
	var rows := VBoxContainer.new()
	info.add_child(rows)
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
	help_button.position = Vector2(1018, 16)
	help_button.size = Vector2(244, 48)
	help_button.add_theme_font_size_override("font_size", 16)
	help_button.text = "お助けメニュー H / Y・△"
	help_button.name = "HelpButton"
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.pressed.connect(func(): set_help_visible(not help_visible))
	hud.add_child(help_button)
	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.position = Vector2(1018, 76)
	pause_button.size = Vector2(244, 36)
	pause_button.text = "ポーズ [Esc]"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect($PauseMenu.open)
	hud.add_child(pause_button)
	var footer := _panel(Rect2(16, 542, 1248, 58))
	footer.name = "Progress"
	hud.add_child(footer)
	_hint = _text("", 19)
	footer.add_child(_hint)
	_message = _text("", 27)
	_message.position = Vector2(120, 270)
	_message.size = Vector2(1040, 120)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.hide()
	hud.add_child(_message)
	_completion = Label.new()
	_completion.name = "Completion"
	_completion.process_mode = Node.PROCESS_MODE_PAUSABLE
	_completion.set_script(CLEAR)
	_completion.hide()
	hud.add_child(_completion)
	_help = HELP.instantiate()
	_help.name = "Help"
	hud.add_child(_help)
	_help.close_requested.connect(func(): set_help_visible(false))
	_help.get_node("Rows/Hints").hide()
	_help.get_node("Rows/Actions/Resume").pressed.connect(func(): set_help_visible(false))
	_help.get_node("Rows/Actions/Retry").text = "部屋全体をやり直す"
	_help.get_node("Rows/Actions/Retry").pressed.connect(func(): set_help_visible(false); retry_room())
	_help.get_node("Rows/Actions/Return").pressed.connect(_return_to_select)


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


func _spawn_needles(origin: Vector2, directions: Array[Vector2], variant: int) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = origin
	query.collision_mask = 1
	query.exclude = [player.get_rid(), enemy.get_rid()]
	if not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
		return
	var flying := 0
	for existing in room.needles.get_children():
		if not existing.stuck and not existing.is_queued_for_deletion():
			flying += 1
	for direction in directions:
		# shortcut: bounded retained geometry; merge identical impacts and preserve pinned footholds.
		if room.needles.get_child_count() >= ROOM.MAX_NEEDLES or flying >= ROOM.MAX_FLYING_NEEDLES:
			break
		var needle := NEEDLE.new()
		needle.position = origin
		needle.course = room
		needle.shooter = enemy
		needle.variant = 0 if variant == 4 else (1 if variant == 5 else variant)
		needle.velocity = direction if variant == 4 else direction.normalized() * [720.0, 650.0, 380.0, 660.0][needle.variant]
		if variant == 4:
			needle.acceleration = enemy.get_gravity_vector() * 1200.0
		if variant == 5:
			needle.stuck_left = 5.0
			needle.temporary = true
		room.needles.add_child(needle)
		shots_fired += 1
		flying += 1


func _spawn_ash_cloud(origin: Vector2, target_at: Vector2, down: Vector2) -> void:
	var clouds := room.get_node("AshClouds")
	if clouds.get_child_count() > 0:
		return
	var cloud := ASH_CLOUD.new()
	# Check every rain column so wide clouds never form beneath an adjacent roof.
	var at := target_at - down * 260.0
	var across := Vector2(down.y, -down.x)
	for slot in 9:
		var column := target_at + across * (slot - 4) * 80.0
		var query := PhysicsRayQueryParameters2D.create(column - down * 600.0, column - down * 30.0, 1, [player.get_rid(), enemy.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.position - down * 70.0).dot(down) < at.dot(down):
			at += down * ((hit.position - down * 70.0).dot(down) - at.dot(down))
	cloud.position = at
	cloud.smoke_origin = origin
	cloud.down = down
	cloud.rain.connect(func(point, direction):
		var directions: Array[Vector2] = [direction]
		_spawn_needles(point, directions, 3)
	)
	clouds.add_child(cloud)
	clouds_cast += 1


func _update_needles(delta: float) -> void:
	for needle in room.needles.get_children():
		var was_blocked: bool = needle.blocked
		needle.advance(delta, player)
		if not needle.flew:
			continue
		var from: Vector2 = needle.flight_start + player.position - _previous_player
		if _segment_hits_rect(from, needle.flight_end, _actor_rect(player).grow(3.0)):
			if _hit_grace <= 0.0 and _respawn_grace <= 0.0:
				_damage_player(player.wall_stamina_max / 3.0, (needle.flight_end - needle.flight_start).normalized() * 140.0)
			needle.queue_free()
		elif needle.blocked and not was_blocked:
			blocked_shots += 1
