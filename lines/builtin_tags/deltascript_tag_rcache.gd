extends DeltascriptTag

func _line_start() -> void:
	var resource := load(arguments[1])
	if resource is AudioStream:
		event_player.cache_sound_resource(StringName(arguments[0]), resource)
	else:
		event_player.cache_resource(StringName(arguments[0]), resource)
		
	goto_next_line()
