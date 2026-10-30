extends SceneTree

var audio
var checks := 0
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	audio = root.get_node("GameAudio")
	_check(audio.process_mode == Node.PROCESS_MODE_ALWAYS, "Audio runs while the tutorial pauses gameplay")
	_check(audio.jump.stream.get_length() < 0.25 and audio.dash.stream.get_length() < 0.12, "Movement SE contain no long trailing silence")
	_check(audio.CLEAR.get_length() > 5.2 and audio.CLEAR.get_length() < 5.3, "Clear SE preserves its decay and removes trailing silence")
	_check(audio.CLEAR.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Clear SE plays once")
	for family in ["a", "b", "c"]:
		for track in audio.TRACKS[family]:
			_check(track.loop and is_zero_approx(track.loop_offset), "Every normal and quiet BGM loops from the beginning")
	_check(audio.TITLE.loop, "Title BGM loops")

	await _scene("start_screen")
	_check(audio.music.stream == audio.TITLE and audio.music.playing, "Title starts its BGM")
	await _loop_end()
	var title_playback: AudioStreamPlayback = audio.music.get_stream_playback()
	audio.music.pitch_scale = 0.06
	audio.music.stream_paused = true
	await _scene("stage_select")
	_check(audio.music.get_stream_playback() == title_playback, "Selection keeps the title BGM playing without restarting")
	_check(audio.music.pitch_scale == 1.0 and not audio.music.stream_paused, "A scene change restores music speed and playback even when the track stays the same")

	var scenes := ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "stage_6"]
	var families := ["c", "a", "b", "c", "a", "b"]
	for index in scenes.size():
		await _scene(scenes[index])
		var normal: AudioStream = audio.TRACKS[families[index]][0]
		var quiet: AudioStream = audio.TRACKS[families[index]][1]
		_check(audio.music.stream == normal and audio.music.playing, "Stage %d starts its assigned normal BGM" % (index + 1))
		await _loop_end()
		var player: PlayerController = current_scene.find_child("Player", true, false)
		player.set_physics_process(false)
		# The existing movement signal is emitted only for successful actions.
		for action in ["jump", "wall_jump", "air_jump", "creature_jump", "superdash"]:
			audio.jump.stop()
			player.movement_action.emit(action)
			_check(audio.jump.playing, "Every successful jump variant plays jump SE")
		player.movement_action.emit("dash")
		_check(audio.dash.playing and audio.jump.playing, "Dash SE can overlap jump SE")
		audio.jump.stop()
		audio.dash.stop()
		for action in ["stunned", "mantle"]:
			player.movement_action.emit(action)
		_check(not audio.jump.playing and not audio.dash.playing, "Other movement events do not play jump or dash SE")
		if index == 5:
			current_scene.enemy.movement_action.emit("jump")
			_check(not audio.jump.playing, "The chaser does not trigger the player's SE")
		if index == 0:
			current_scene._complete()
			_check(audio.music.stream == normal, "The tutorial keeps its BGM until the clear art appears")
			current_scene._start_clear_intro()
		else:
			current_scene.get_node("HUD/Completion").show()
		_check(audio.music.stream == audio.CLEAR and audio.music.playing, "Showing stage %d clear UI replaces BGM with clear SE" % (index + 1))
		var clear_playback: AudioStreamPlayback = audio.music.get_stream_playback()
		if index == 0:
			current_scene._show_clear()
		else:
			current_scene.get_node("HUD/Completion").hide()
			current_scene.get_node("HUD/Completion").show()
		_check(audio.music.get_stream_playback() == clear_playback, "Repeated clear UI updates do not restart the jingle")
		_check(audio.music.stream != quiet, "Quiet BGM waits for clear SE to finish")
		audio.music.seek(audio.CLEAR.get_length() - 0.1)
		await _real_time(0.4)
		_check(audio.music.stream == quiet and audio.music.playing, "The actual finished signal starts the matching quiet BGM")
		await _loop_end()
		if index == 0:
			_check(paused, "Tutorial clear audio plays while gameplay is paused")
			current_scene.player.respawn()
			_check(not paused and audio.music.stream == normal, "Retrying the tutorial restores normal BGM")
			current_scene._complete()
			current_scene.skip_cinematic()
			_check(audio.music.stream == audio.CLEAR, "Skipping the clear intro still plays clear SE")
			audio.music.seek(audio.CLEAR.get_length() - 0.1)
			await _scene("stage_select")
			await _real_time(0.4)
			_check(audio.music.stream == audio.TITLE, "Leaving during clear SE cancels the pending quiet BGM")
			paused = false

	await _scene("stage_2")
	current_scene.get_node("HUD/Completion").show()
	audio.music.seek(audio.CLEAR.get_length() - 0.1)
	await _scene("tutorial")
	await _real_time(0.4)
	_check(audio.music.stream == audio.TRACKS.c[0], "Changing stages during clear SE cannot start the old quiet BGM")
	current_scene._start_slow()
	current_scene._process(0.2)
	current_scene._wait_for_dash()
	_check(audio.music.stream_paused, "The tutorial freezes music before a scene change")
	await _scene("stage_2")
	_check(audio.music.pitch_scale == 1.0 and not audio.music.stream_paused and audio.music.playing, "Leaving input wait starts the next stage's BGM at normal speed")
	current_scene.get_node("HUD/Completion").show()
	_check(audio.music.stream == audio.CLEAR, "Re-entering a stage resets its clear SE guard")
	await _scene("gallery")
	_check(not audio.music.playing and not audio.jump.playing and not audio.dash.playing, "Leaving for an unscored scene stops the previous audio")
	if not failed:
		print("GAME_AUDIO_TEST_OK (%d checks)" % checks)
	quit(1 if failed else 0)


func _scene(scene: String) -> void:
	_check(change_scene_to_file("res://scenes/%s.tscn" % scene) == OK, "Scene loads: " + scene)
	await scene_changed
	await process_frame


func _loop_end() -> void:
	for repeat in 2:
		audio.music.seek(audio.music.stream.get_length() - 0.1)
		await _real_time(0.4)
		_check(audio.music.playing and audio.music.get_playback_position() < 1.0, "BGM wraps at its end and continues playing")


func _real_time(seconds: float) -> void:
	# The dummy audio driver uses wall time even with the fixed-fps test runner.
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("GAME_AUDIO_TEST_FAILED: " + message)
