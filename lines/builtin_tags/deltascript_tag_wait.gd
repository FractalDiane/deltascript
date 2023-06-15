extends DeltascriptTag

func _line_start() -> void:
	var timer := Timer.new()
	timer.wait_time = arguments[0]
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	timer.timeout.connect(timer.queue_free)
	tree_context.get_root().add_child(timer)
	timer.start()
	
func _on_timeout() -> void:
	goto_next_line()

func _get_tag_identifier() -> StringName:
	return &"wait"
