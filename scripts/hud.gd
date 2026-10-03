extends CanvasLayer

@export var player_path: NodePath
@export var tutorial_mode := false
var _tutorial_index := 0
var _last_extra_count := -1


func _ready() -> void:
	var player := get_node(player_path) as PlayerController
	player.carry_changed.connect(_on_carry_changed)
	_on_carry_changed("NONE")
	player.gravity_changed.connect(_on_gravity_changed)
	player.resources_changed.connect(_on_resources_changed)
	_on_gravity_changed(player.gravity_direction < 0)
	_on_resources_changed(player.get_wall_stamina(), player.wall_stamina_max, player.is_dash_ready(), player.is_air_jump_ready())
	if tutorial_mode:
		$Margin.add_theme_constant_override("margin_top", 8)
		$Margin/Panel/Rows/Carry.hide()


func _on_gravity_changed(is_inverted: bool) -> void:
	if tutorial_mode:
		$Margin/Panel/Rows/Gravity.text = "重力：天井へ ↑" if is_inverted else "重力：床へ ↓"
		return
	$Margin/Panel/Rows/Gravity.text = "GRAVITY: UP" if is_inverted else "GRAVITY: DOWN"


func _on_resources_changed(stamina: float, stamina_max: float, dash_ready: bool, air_jump_ready: bool) -> void:
	$Margin/Panel/Rows/Stamina.max_value = stamina_max
	$Margin/Panel/Rows/Stamina.value = stamina
	if tutorial_mode:
		$Margin/Panel/Rows/Resources.text = "ダッシュ：使用可能" if dash_ready else "ダッシュ：着地で回復"
		if _tutorial_index >= 5:
			var player := get_node(player_path) as PlayerController
			$Margin/Panel/Rows/Resources.text += "　追加ジャンプ：%d" % player.get_available_extra_jump_count()
		return
	$Margin/Panel/Rows/Resources.text = "DASH: %s   AIR JUMP: %s" % ["READY" if dash_ready else "USED", "READY" if air_jump_ready else "NONE"]


func _on_carry_changed(label: String) -> void:
	$Margin/Panel/Rows/Carry.text = "CARRY: " + label
	if tutorial_mode:
		$Margin/Panel/Rows/Carry.text = "保持：" + {"NONE": "なし", "OBJECT": "小さな箱", "HEAVY": "重い箱", "JUMP": "ジャンプ生物", "PARACHUTE": "傘の生物"}.get(label, label)


func show_tutorial_room(index: int, title: String, controls: String, wall_enabled: bool, dash_available: bool, room_count: int = 16) -> void:
	_tutorial_index = index
	$Margin/Panel/Rows/Title.text = "%02d / %02d　%s" % [index + 1, room_count, title] if index < room_count else "任意の練習　" + title
	$Margin/Panel/Rows/Controls.text = controls
	$Margin/Panel/Rows/WallControls.text = "やり直し：R / Start　　出口を越えると次の部屋へ"
	$Margin/Panel/Rows/Gravity.visible = index >= 3
	$Margin/Panel/Rows/StaminaLabel.text = "壁スタミナ（着地で回復）"
	$Margin/Panel/Rows/StaminaLabel.visible = wall_enabled and index in [1, 8]
	$Margin/Panel/Rows/Stamina.visible = wall_enabled and index in [1, 8]
	$Margin/Panel/Rows/Resources.visible = dash_available
	$Margin/Panel/Rows/Carry.visible = index >= 10
	var player := get_node(player_path) as PlayerController
	_on_resources_changed(player.get_wall_stamina(), player.wall_stamina_max, player.is_dash_ready(), player.is_air_jump_ready())
	_on_carry_changed(player.get_held_object().carry_name if player.get_held_object() != null else "NONE")


func show_lesson_progress(text: String, done: bool) -> void:
	$Margin/Panel/Rows/Objective.visible = true
	$Margin/Panel/Rows/Objective.text = text
	$Margin/Panel/Rows/Objective.modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.85, 0.55)


func _process(_delta: float) -> void:
	if not tutorial_mode or _tutorial_index < 5:
		return
	var player := get_node(player_path) as PlayerController
	var count := player.get_available_extra_jump_count()
	if count != _last_extra_count:
		_last_extra_count = count
		_on_resources_changed(player.get_wall_stamina(), player.wall_stamina_max, player.is_dash_ready(), player.is_air_jump_ready())
