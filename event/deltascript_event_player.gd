class_name DeltascriptEventPlayer
extends Node

signal initial_load_complete()
signal load_complete()
signal event_finished()

enum {
	ROOT_FRAGMENTS,
	ROOT_FRAGMENT_ORDER,
}

enum {
	LINE_STRING,
	LINE_TAG,
	LINE_CHOICE,
	LINE_JUMP,
	LINE_CONTROL,
}

enum {
	LINE_FIELD_TYPE,
	LINE_FIELD_VALUE,
	
	TAG_FIELD_TAG,
	TAG_FIELD_ARGS,
	TAG_FIELD_NAMEDARGS,
	
	CHOICE_FIELD_CHOICE,
	CHOICE_FIELD_RESULT,
	
	LABEL_FIELD_LABEL,
	LABEL_FIELD_CONTENTS,
	
	CONTROL_FIELD_INSTRUCTION,
	CONTROL_FIELD_EXPRESSION,
	CONTROL_FIELD_VARIABLE,
}

enum {
	CONTROL_IF,
	CONTROL_ELIF,
	CONTROL_ELSE,
	CONTROL_ENDIF,
	
	CONTROL_WHILE,
	CONTROL_ENDWHILE,
	
	CONTROL_GOTO,
	CONTROL_EXIT,
	
	CONTROL_SET,
}

var init_thread: Thread = null
var resource_thread: Thread = null
var node_thread: Thread = null
var tag_thread: Thread = null

var event_data := {}
var current_fragment := []
var current_root_fragment_index := 0
var fragment_order := []
var fragment_stack := []
var line_indices: Array[int] = [0]

var current_line_object: DeltascriptLine = null
var all_active_lines := {}

var cached_nodes := {}
var cached_sounds := {}
var cached_resources := {}
var metadata := {}

var dialogue_script: GDScript = null
var choice_script: GDScript = null
var tag_scripts := {}

var event_variables := {}
var event_variable_names := PackedStringArray()
var event_variable_values := []

var if_stack: Array[bool] = []
var if_level_internal := 0
var if_chains_complete: Array[bool] = []
var while_stack: Array[bool] = []
var while_index_stack: Array[int] = []
var while_level_internal := 0

var interpolation_regex := RegEx.new()
	
	
func _exit_tree() -> void:
	if init_thread != null and init_thread.is_started():
		init_thread.wait_to_finish()
		
	if node_thread != null and node_thread.is_started():
		node_thread.wait_to_finish()
	
	if resource_thread != null and resource_thread.is_started():
		resource_thread.wait_to_finish()
		
	if tag_thread != null and tag_thread.is_started():
		tag_thread.wait_to_finish()

			
func initial_load() -> void:
	var dialogue_script_path = ProjectSettings.get_setting(&"deltascript/scripts/dialogue_script", String())
	if not dialogue_script_path.is_empty():
		dialogue_script = load(dialogue_script_path) as GDScript
		
	var choice_script_path = ProjectSettings.get_setting(&"deltascript/scripts/choice_script", String())
	if not choice_script_path.is_empty():
		choice_script = load(choice_script_path) as GDScript
		
	tag_scripts = ProjectSettings.get_setting(&"deltascript/scripts/tag_scripts", {})
	tag_scripts.merge(DeltascriptGlobals.DEFAULT_TAGS)
	
	metadata = ProjectSettings.get_setting(&"deltascript/event_playback/default_event_metadata", {})
	
	interpolation_regex.compile("\\{(\\w+)}")

	play_event_post.call_deferred()


func play_event(event: DeltascriptEventCompiled, force_localization_off: bool = false) -> void:
	event_data = event.event_data
	set_message_translation(not force_localization_off)
	current_fragment = event_data[ROOT_FRAGMENTS][DeltascriptGlobals.STARTING_FRAGMENT]
	fragment_order = event_data[ROOT_FRAGMENT_ORDER]
	
	init_thread = Thread.new()
	init_thread.start(initial_load)
	
	
func play_event_post() -> void:
	print("TEST LOAD")
	init_thread.wait_to_finish()
	run_next_line()
	
	
func should_skip_line() -> bool:
	return (not if_stack.is_empty() and not if_stack[-1]) or (not while_stack.is_empty() and not while_stack[-1])
	
	
func eval_expression(expression_string: String) -> Variant:
	var expression := Expression.new()
	expression.parse(expression_string, event_variable_names)
	return expression.execute(event_variable_values, null, false, true)
	

func run_next_line() -> void:
	var this_line: Dictionary = current_fragment[line_indices[-1]]
	var script: DeltascriptLine
	
	var line_skipped := false
	var wait_for_load := false
	match this_line[LINE_FIELD_TYPE]:
		LINE_STRING:
			if not should_skip_line():
				if dialogue_script != null:
					var script_dlg: DeltascriptTagDialogueBase = dialogue_script.new()
					script_dlg.line_text = interpolate_string(tr(this_line[LINE_FIELD_VALUE]))
					script = script_dlg
			else:
				line_skipped = true
		LINE_TAG:
			if not should_skip_line():
				var tag: Dictionary = this_line[LINE_FIELD_VALUE]
				var tag_ident: StringName = tag[TAG_FIELD_TAG]
				if tag_scripts.has(tag_ident):
					if tag_thread != null and tag_thread.is_started():
						tag_thread.wait_to_finish()
					
					tag_thread = Thread.new()
					tag_thread.start(load_tag.bind(tag, tag_ident))
					wait_for_load = true
			else:
				line_skipped = true
		LINE_CHOICE:
			if not should_skip_line():
				if choice_script != null:
					var choices: Array = this_line[LINE_FIELD_VALUE]
					var choice_texts: Array[String] = []
					var choice_results := []
					for choice in choices:
						choice_texts.push_back(interpolate_string(tr(choice[CHOICE_FIELD_CHOICE])))
						choice_results.push_back(choice[CHOICE_FIELD_RESULT])
					
					var script_choice: DeltascriptTagChoiceBase = choice_script.new()
					script_choice.line_choice_texts = choice_texts
					script_choice.line_choice_results = choice_results
					script = script_choice
			else:
				line_skipped = true
		LINE_CONTROL:
			var control: Dictionary = this_line[LINE_FIELD_VALUE]
			match control[CONTROL_FIELD_INSTRUCTION]:
				CONTROL_SET:
					if not should_skip_line():
						var result := eval_expression(control[CONTROL_FIELD_EXPRESSION])
						event_variables[control[CONTROL_FIELD_VARIABLE]] = result
						
						var index := event_variable_names.find(control[CONTROL_FIELD_VARIABLE])
						if index == -1:
							event_variable_names.push_back(control[CONTROL_FIELD_VARIABLE])
							event_variable_values.push_back(result)
						else:
							event_variable_values[index] = result
					else:
						line_skipped = true
				CONTROL_IF:
					if_level_internal += 1
					if_chains_complete.push_back(false)
					if not should_skip_line():
						var result := bool(eval_expression(control[CONTROL_FIELD_EXPRESSION]))
					
						if_stack.push_back(result)
						if_chains_complete[-1] = if_chains_complete[-1] or result
					else:
						line_skipped = true
				CONTROL_ELIF:
					if not should_skip_line() or (if_level_internal == len(if_stack) and not if_stack[-1] and not if_chains_complete[-1]):
						var result := bool(eval_expression(control[CONTROL_FIELD_EXPRESSION]))
					
						if_stack[-1] = result
						if_chains_complete[-1] = if_chains_complete[-1] or result
					else:
						line_skipped = true
				CONTROL_ELSE:
					if not should_skip_line() or (if_level_internal == len(if_stack) and not if_stack[-1] and not if_chains_complete[-1]):
						var current_if := if_stack[-1]
						if_stack[-1] = not current_if
					else:
						line_skipped = true
				CONTROL_ENDIF:
					if not should_skip_line() or if_level_internal == len(if_stack):
						if_stack.pop_back()
					else:
						line_skipped = true
						
					if_level_internal -= 1
					if_chains_complete.pop_back()
				CONTROL_GOTO:
					if not should_skip_line():
						var target: StringName = control[CONTROL_FIELD_EXPRESSION]
						current_fragment = event_data[ROOT_FRAGMENTS][target]
						line_indices[0] = 0
						line_indices.resize(1)
						
						run_next_line()	
						return
					else:
						line_skipped = true
				CONTROL_EXIT:
					if not should_skip_line():
						end_event()
						return
					else:
						line_skipped = true
				CONTROL_WHILE:
					while_level_internal += 1
					if not should_skip_line() or while_level_internal == len(while_stack):
						var result := bool(eval_expression(control[CONTROL_FIELD_EXPRESSION]))
						
						while_stack.push_back(result)
						while_index_stack.push_back(line_indices[-1] - 1)
					else:
						line_skipped = true
				CONTROL_ENDWHILE:
					if not should_skip_line() or while_level_internal == len(while_stack):
						if while_stack[-1]:
							line_indices[-1] = while_index_stack[-1]
							
						while_stack.pop_back()
						while_index_stack.pop_back()
					else:
						line_skipped = true
				
					while_level_internal -= 1
							
			if not line_skipped:
				skip_this_line.call_deferred()
				return
					
	if not line_skipped:
		if not wait_for_load:
			run_tag_post_load(script)
	else:
		skip_this_line.call_deferred()
		
		
func load_tag(tag: Dictionary, tag_ident: StringName) -> void:
	var script_tag: DeltascriptTag = load(tag_scripts[tag_ident]).new()
	script_tag.arguments = tag[TAG_FIELD_ARGS]
	script_tag.named_arguments = tag[TAG_FIELD_NAMEDARGS]
	
	print("TAG LOADED")
	run_tag_post_load.call_deferred(script_tag)
		
		
func run_tag_post_load(script: DeltascriptLine) -> void:
	current_line_object = script
	all_active_lines[current_line_object] = true
	script.event_player = self
	script.tree_context = get_tree()
	script.line_completed.connect(_on_line_completed_defer)
	script.line_finalized.connect(_on_line_finalized)
	script._line_start()
	
	
func get_event_metadata(key: StringName) -> Variant:
	return metadata[key]
	
	
func set_event_metadata(key: StringName, value: Variant) -> void:
	metadata[key] = value
	
	
func cache_node(key: StringName, path: NodePath) -> void:
	if node_thread != null and node_thread.is_started():
		node_thread.wait_to_finish()
		
	node_thread = Thread.new()
	node_thread.start(cache_node_thread.bind(key, path))
	
	
func cache_node_thread(key: StringName, path: NodePath) -> void:
	cached_nodes[key] = get_tree().current_scene.get_node(path)
	print("NODE CACHED")
	cache_node_finished.call_deferred()
	
	
func cache_node_finished() -> void:
	load_complete.emit()
	
	
func get_cached_node(key: StringName) -> Node:
	return cached_nodes.get(key)
	
	
func load_resource(key: StringName, path: String) -> void:
	if resource_thread != null and resource_thread.is_started():
		resource_thread.wait_to_finish()
		
	resource_thread = Thread.new()
	resource_thread.start(load_resource_thread.bind(key, path))
	
	
func load_resource_thread(key: StringName, path: String) -> void:
	var resource := load(path) as Resource
	if resource is AudioStream:
		cached_sounds[key] = resource
	else:
		cached_resources[key] = resource
		
	print("RESOURCE LOADED")
	load_resource_finished.call_deferred()


func load_resource_finished() -> void:
	load_complete.emit()

	
func get_cached_resource(key: StringName) -> Resource:
	return cached_resources.get(key)
	

func get_cached_sound_resource(key: StringName) -> AudioStream:
	return cached_sounds.get(key)
	
	
func interpolate_string(what: String) -> String:
	var matches := interpolation_regex.search_all(what)
	
	var new_string := what
	for mat in matches:
		var replacement := str(event_variables[StringName(mat.get_string(1))])
		new_string = interpolation_regex.sub(new_string, replacement)
	
	return new_string
	
	
func skip_this_line() -> void:
	_on_line_completed([])
	
	
func _on_line_completed_defer(next_fragment_override: Array) -> void:
	_on_line_completed.call_deferred(next_fragment_override)
	
	
func _on_line_completed(next_fragment_override: Array) -> void:
	if current_line_object != null:
		current_line_object._line_end()
		current_line_object = null
	
	line_indices[-1] += 1
	if next_fragment_override.is_empty():
		if line_indices[-1] < len(current_fragment):
			run_next_line()
		else:
			if len(line_indices) > 1:
				line_indices.pop_back()
				current_fragment = fragment_stack.pop_back()
				while line_indices[-1] >= len(current_fragment):
					line_indices.pop_back()
					current_fragment = fragment_stack.pop_back()
					
				run_next_line()
			else:
				if current_root_fragment_index < len(fragment_order) - 1:
					current_root_fragment_index += 1
					current_fragment = event_data[ROOT_FRAGMENTS][event_data[ROOT_FRAGMENT_ORDER][current_root_fragment_index]]
					line_indices = [0]
					if not current_fragment.is_empty():
						run_next_line()
					else:
						end_event()
				else:
					end_event()
	else:
		line_indices.push_back(0)
		fragment_stack.push_back(current_fragment)
		current_fragment = next_fragment_override
		run_next_line()
		
		
func _on_line_finalized(line: DeltascriptLine) -> void:
	all_active_lines.erase(line)

	
func end_event() -> void:
	event_finished.emit()
	queue_free()
