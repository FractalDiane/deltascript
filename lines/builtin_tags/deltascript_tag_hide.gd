extends DeltascriptTag

func _line_begin() -> void:
	var node: Node = tree_context.current_scene.get_node(NodePath(arguments[0]))
	node.hide()
	goto_next_line()
