class_name DeltascriptLine
extends RefCounted

signal line_completed(next_fragment_override: Array)
signal line_finalized(line: DeltascriptLine)

var event_player: DeltascriptEventPlayer = null
var tree_context: SceneTree = null

func _line_start() -> void:
	pass

	
func _line_end() -> void:
	line_finalized.emit(self)


func goto_next_line(fragment_override: Array = []) -> void:
	line_completed.emit(fragment_override)
