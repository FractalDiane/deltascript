extends DeltascriptTag

func _line_start() -> void:
	var key := StringName(arguments[0])
	var path: String = arguments[1]
	event_player.load_complete.connect(load_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	event_player.load_resource(key, path)
		
		
func load_finished() -> void:
	goto_next_line()
