extends DeltascriptTag

func _line_start() -> void:
	#var resource := load(arguments[1])
	#if resource is AudioStream:
	#	event_player.cache_sound_resource(StringName(arguments[0]), resource)
	#else:
	#	event_player.cache_resource(StringName(arguments[0]), resource)
	
	var key := StringName(arguments[0])
	var path: String = arguments[1]
	event_player.load_complete.connect(load_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	event_player.load_resource(key, path)
	#await event_player.load_complete
		
		
func load_finished() -> void:
	goto_next_line()
