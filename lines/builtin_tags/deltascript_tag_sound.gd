extends DeltascriptTag

func _line_start() -> void:
	var sound: AudioStream = event_player.get_cached_sound_resource(StringName(arguments[0]))
	
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.volume_db = named_arguments.get(&"volume", 0)
	player.pitch_scale = named_arguments.get(&"pitch", 1.0)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	
	tree_context.get_root().add_child(player)
	player.play()
	
	goto_next_line()
