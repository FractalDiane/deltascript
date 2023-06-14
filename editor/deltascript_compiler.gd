@tool
class_name DeltascriptCompiler
extends RefCounted

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

# ==================================================================================================

func _ready() -> void:
	alpha_regex.compile("\\w[A-Za-z_]+\\w")

# ==================================================================================================
	
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
	
	var cached_resources := {}
	for entry in file.cached_resources:
		var this_entry := entry as CachedResource
		cached_resources[this_entry.identifier] = this_entry.path
		
	root_dict[DeltascriptEventPlayer.ROOT_CACHED_RESOURCES] = cached_resources
	
	var cached_nodes := {}
	for entry in file.cached_nodes:
		var this_entry := entry as CachedNode
		cached_nodes[this_entry.identifier] = this_entry.path
		
	root_dict[DeltascriptEventPlayer.ROOT_CACHED_NODES] = cached_nodes
	
	var out_res := DeltascriptEventCompiled.new()
	out_res.event_data = root_dict.duplicate(true)
	var out_path := file.get_path().replace(".tres", "_C.res")
	var err := ResourceSaver.save(out_res, out_path)
	if err == OK:
		print("Compiled Deltascript event %s" % out_path)
		print(root_dict)
	else:
		push_error("Failed to save compiled Deltascript event %s: %s" % [out_path, err])
