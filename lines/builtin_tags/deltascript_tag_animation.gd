extends DeltascriptTag

func _line_start() -> void:
	var target := NodePath(arguments[0])
	(tree_context.current_scene.get_node(target).get_node(^"AnimationPlayer") as AnimationPlayer).play(arguments[1])
	goto_next_line()

func _get_tag_identifier() -> StringName:
	return &"animation"
