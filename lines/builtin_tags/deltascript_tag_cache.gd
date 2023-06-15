extends DeltascriptTag

func _line_start() -> void:
	var key := StringName(arguments[0])
	var path := NodePath(arguments[1])
	event_player.load_complete.connect(load_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	event_player.cache_node(key, path)
	
func load_finished() -> void:
	goto_next_line()

func _get_tag_identifier() -> StringName:
	return &"cache"
