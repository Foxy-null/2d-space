extends PanelContainer

signal close_requested


func _ready() -> void:
	visibility_changed.connect(_sync_completion_card)


func _sync_completion_card() -> void:
	var completion := get_parent().get_node_or_null("Completion")
	if completion != null and completion.has_method("_sync_visibility"):
		var card: Control = completion.get("card")
		if is_instance_valid(card):
			card.visible = completion.is_visible_in_tree() and not visible


func show_hint(title: String, hint: String) -> void:
	$Rows/Title.text = title
	$Rows/Columns/HintScroll/Hint.text = hint
	$Rows/Columns/HintScroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_echo() and (event.is_action_pressed("toggle_stage_hints") or event.is_action_pressed("return_to_stage_select")):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible or not $Rows/Columns/HintScroll.has_focus():
		return
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		$Rows/Columns/HintScroll.scroll_vertical += -56 if event.is_action_pressed("ui_up", true) else 56
		get_viewport().set_input_as_handled()
