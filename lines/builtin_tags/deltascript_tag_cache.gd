extends DeltascriptTag

func _line_start() -> void:
	#var node := tree_context.current_scene.get_node(NodePath(arguments[1]))
	#event_player.cache_node(StringName(arguments[0]), node)
	
	var key := StringName(arguments[0])
	var path := NodePath(arguments[1])
	event_player.load_complete.connect(load_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	event_player.cache_node(key, path)
	
func load_finished() -> void:
	goto_next_line()
