@tool
class_name DeltascriptEditorPanel
extends Panel

var target_file := String()
var target_dir := "res://"

var alpha_regex := RegEx.new()

const CONTROL_LINES := {
	&"if": DeltascriptEventPlayer.CONTROL_IF,
	&"elif": DeltascriptEventPlayer.CONTROL_ELIF,
	&"else": DeltascriptEventPlayer.CONTROL_ELSE,
	&"endif": DeltascriptEventPlayer.CONTROL_ENDIF,
	&"while": DeltascriptEventPlayer.CONTROL_WHILE,
	&"endwhile": DeltascriptEventPlayer.CONTROL_ENDWHILE,
	&"goto": DeltascriptEventPlayer.CONTROL_GOTO,
	&"exit": DeltascriptEventPlayer.CONTROL_EXIT,
	&"set": DeltascriptEventPlayer.CONTROL_SET,
}

@onready var file_edit := $VBoxContainer/HBoxContainer/LineEditFile as LineEdit
@onready var dir_edit := $VBoxContainer/HBoxContainer2/LineEditFolder as LineEdit

func _ready() -> void:
	alpha_regex.compile("\\w[A-Za-z_]+\\w")

func _on_line_edit_file_text_submitted(new_text: String) -> void:
	target_file = new_text


func _on_line_edit_folder_text_submitted(new_text: String) -> void:
	target_dir = new_text


func _on_button_pick_file_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.min_size = Vector2(768, 512)
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.tres ; Deltascript Events"])
	dialog.file_selected.connect(_on_file_dialog_file_selected, CONNECT_ONE_SHOT)
	dialog.close_requested.connect(queue_free, CONNECT_ONE_SHOT)
	
	add_child(dialog)
	dialog.popup_centered()
	
	
func _on_button_pick_folder_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.rect_min_size = Vector2(768, 512)
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.file_selected.connect(_on_file_dialog_dir_selected, CONNECT_ONE_SHOT)
	dialog.close_requested.connect(queue_free, CONNECT_ONE_SHOT)
	
	add_child(dialog)
	dialog.popup_centered()
	
	
func _on_file_dialog_file_selected(file: String) -> void:
	target_file = file
	file_edit.text = file
	

func _on_file_dialog_dir_selected(dir: String) -> void:
	target_dir = dir
	dir_edit.text = dir


#func _on_button_compile_one_pressed() -> void:
#	compile_file(target_file)


#func _on_button_compile_all_pressed() -> void:
#	var files := get_all_files(target_dir)
#	for file in files:
#		compile_file(file)
		
# ==================================================================================================

func get_all_files(path: String, files := []) -> Array[String]:
	var dir := DirAccess.open(target_dir)
	if dir != null:
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir():
				files = get_all_files(dir.get_current_dir().path_join(file_name), files)
			else:
				files.append(file_name)
			
			file_name = dir.get_next()
	else:
		push_error("Deltascript: Failed to open compile directory %s" % target_dir)
		
	return files
	
	
func parse_variant(what: String) -> Variant:
	if what.is_valid_int():
		return int(what)
		
	if what.is_valid_float():
		return float(what)
	
	if what == "true" or what == "yes":
		return true
		
	if what == "false" or what == "no":
		return false
		
	return what
	
# ==================================================================================================

func compile_file(file: DeltascriptEvent) -> void:
	var root_dict := {
		DeltascriptEventPlayer.ROOT_FRAGMENTS: {},
	}
	
	var list_stack := [[]]
	var current_fragment := DeltascriptGlobals.STARTING_FRAGMENT
	var fragment_order: Array[StringName] = [DeltascriptGlobals.STARTING_FRAGMENT]
	var choice_stack := []
	var choice_batch_stack := []
	
	var lines := file.event_script.split("\n")
	
	for line in lines:
		if line.is_empty():
			continue

		var line_trimmed := line.replace("\t", "") as String
		if line_trimmed.contains("`"):
			line_trimmed = line_trimmed.get_slice("`", 0)
		
		if line_trimmed.is_empty():
			continue
			
		match line_trimmed[0]:
			"#":
				var line_split := line_trimmed.substr(1).split(" ")
				var tag := StringName(line_split[0])
				
				var args := []
				var named_args := {}
				
				for arg in line_split.slice(1):
					if arg.contains("="):
						var split := arg.split("=")
						named_args[StringName(split[0])] = parse_variant(split[1])
					else:
						args.push_back(parse_variant(arg))
				
				var dict := {
					DeltascriptEventPlayer.TAG_FIELD_TAG: tag,
					DeltascriptEventPlayer.TAG_FIELD_ARGS: args,
					DeltascriptEventPlayer.TAG_FIELD_NAMEDARGS: named_args,
				}
				
				list_stack[-1].append({DeltascriptEventPlayer.LINE_FIELD_TYPE: DeltascriptEventPlayer.LINE_TAG, DeltascriptEventPlayer.LINE_FIELD_VALUE: dict})
			"@":
				var control := StringName(line_trimmed.substr(1).get_slice(" ", 0))
				var control_enum: int = CONTROL_LINES[control]
				
				var dict := {
					DeltascriptEventPlayer.CONTROL_FIELD_INSTRUCTION: control_enum,
				}
				
				var rest_of_line := " ".join(line_trimmed.split(" ").slice(1))
				
				match control_enum:
					DeltascriptEventPlayer.CONTROL_IF, DeltascriptEventPlayer.CONTROL_ELIF, DeltascriptEventPlayer.CONTROL_WHILE, DeltascriptEventPlayer.CONTROL_GOTO:
						dict[DeltascriptEventPlayer.CONTROL_FIELD_EXPRESSION] = rest_of_line
					DeltascriptEventPlayer.CONTROL_SET:
						dict[DeltascriptEventPlayer.CONTROL_FIELD_VARIABLE] = StringName(rest_of_line.get_slice(" ", 0))
						dict[DeltascriptEventPlayer.CONTROL_FIELD_EXPRESSION] = " ".join(rest_of_line.split(" ").slice(1))
				
				if dict.has(DeltascriptEventPlayer.CONTROL_FIELD_EXPRESSION):
					var final_expression := dict[DeltascriptEventPlayer.CONTROL_FIELD_EXPRESSION] as String
					if not final_expression.is_empty():
						var expression := Expression.new()
						var final_expression_trimmed := final_expression
						alpha_regex.sub(final_expression_trimmed, "0", true)
						
						if expression.parse(final_expression_trimmed) != OK:
							push_error("Failed to parse expression: %s" % final_expression)
							return
				
				list_stack[-1].push_back({DeltascriptEventPlayer.LINE_FIELD_TYPE: DeltascriptEventPlayer.LINE_CONTROL, DeltascriptEventPlayer.LINE_FIELD_VALUE: dict})
			">":
				var level := len(line_trimmed.get_slice(" ", 0))
				if level > len(choice_stack):
					var trimmed := Array(line_trimmed.split(" "))
					choice_stack.push_back(" ".join(PackedStringArray(trimmed.slice(1, len(trimmed) - 1))))
					list_stack.push_back([])
					choice_batch_stack.push_back([])
				else:
					var choice_dict := {}
					choice_dict[DeltascriptEventPlayer.CHOICE_FIELD_CHOICE] = choice_stack[-1]
					choice_stack.pop_back()
					choice_dict[DeltascriptEventPlayer.CHOICE_FIELD_RESULT] = list_stack[-1].duplicate(true)
					list_stack.pop_back()
					choice_batch_stack[-1].push_back(choice_dict)
					var trimmed := Array(line_trimmed.split(" "))
					choice_stack.push_back(" ".join(PackedStringArray(trimmed.slice(1, len(trimmed) - 1))))
					list_stack.push_back([])
			"-":
				#if len(line_trimmed) > 1 and line_trimmed[1] == '>':
				#	list_stack[-1].push_back({DeltascriptEventPlayer.LINE_FIELD_TYPE: DeltascriptEventPlayer.LINE_JUMP, DeltascriptEventPlayer.LINE_FIELD_VALUE: StringName(line_trimmed.get_slice(" ", 1))})
				#else:
				var choice_dict := {}
				choice_dict[DeltascriptEventPlayer.CHOICE_FIELD_CHOICE] = choice_stack[-1]
				choice_stack.pop_back()
				choice_dict[DeltascriptEventPlayer.CHOICE_FIELD_RESULT] = list_stack[-1].duplicate(true)
				list_stack.pop_back()
				choice_batch_stack[-1].push_back(choice_dict)
				list_stack[-1].push_back({DeltascriptEventPlayer.LINE_FIELD_TYPE: DeltascriptEventPlayer.LINE_CHOICE, DeltascriptEventPlayer.LINE_FIELD_VALUE: choice_batch_stack.pop_back()})
			"=":
				var label := StringName(line_trimmed.get_slice(" ", 1))
				var new_fragment := {}
				new_fragment[DeltascriptEventPlayer.LABEL_FIELD_CONTENTS] = list_stack[-1].duplicate(true)
				new_fragment[DeltascriptEventPlayer.LABEL_FIELD_LABEL] = label
				root_dict[DeltascriptEventPlayer.ROOT_FRAGMENTS][current_fragment] = list_stack[0].duplicate(true)
				fragment_order.push_back(label)
				list_stack = [[]]
				current_fragment = label
			"`":
				pass
			_:
				list_stack[-1].push_back({DeltascriptEventPlayer.LINE_FIELD_TYPE: DeltascriptEventPlayer.LINE_STRING, DeltascriptEventPlayer.LINE_FIELD_VALUE: line_trimmed})

	root_dict[DeltascriptEventPlayer.ROOT_FRAGMENTS][current_fragment] = list_stack[0]
	root_dict[DeltascriptEventPlayer.ROOT_FRAGMENT_ORDER] = fragment_order.duplicate()
	
	var out_res := DeltascriptEventCompiled.new()
	out_res.event_data = root_dict.duplicate(true)
	var out_path := file.get_path().replace(".tres", "_C.res")
	var err := ResourceSaver.save(out_res, out_path)
	if err == OK:
		print("Compiled Deltascript event %s" % out_path)
		print(root_dict)
	else:
		push_error("Failed to save compiled Deltascript event %s: %s" % [out_path, err])
		
# ==================================================================================================

#func _on_resource_saved(resource: Resource) -> void:
#	if resource is DeltascriptEvent:
#		compile_file(resource.get_path())
