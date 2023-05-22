extends CodeHighlighter

const WHITESPACE_CHARS := " \t\n\r"
const NUMBERS := "0123456789"
const ALPHA_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

const KEYWORDS := {
	"false": &"text_editor/theme/highlighting/keyword_color",
	"true": &"text_editor/theme/highlighting/keyword_color",
	"not": &"text_editor/theme/highlighting/keyword_color",
	"or": &"text_editor/theme/highlighting/keyword_color",
	"and": &"text_editor/theme/highlighting/keyword_color",
}

var editor: CodeEdit = null
var editor_settings: EditorSettings = null


func try_add_keyword(keyword: String, column_from: int, column_to: int, dict: Dictionary) -> void:
	var color: StringName = KEYWORDS.get(keyword, StringName())
	if not color.is_empty():
		for i in range(column_from, column_to):
			dict[i] = {"color": editor_settings.get(color)}


func find_keywords(text: String) -> Dictionary:
	var result := {}
	var current_word := PackedStringArray()
	var current_word_start := -1
	var i := 0
	for chr in text:
		if not WHITESPACE_CHARS.contains(chr):
			if current_word_start == -1:
				current_word_start = i
				
			current_word.push_back(chr)
		else:
			if not current_word.is_empty():
				var keyword := "".join(current_word)
				try_add_keyword(keyword, current_word_start, i + 1, result)
				
			current_word.clear()
			current_word_start = -1
		
		i += 1
		
	if not current_word.is_empty():
		var keyword := "".join(current_word)
		try_add_keyword(keyword, current_word_start, i, result)
		
	return result


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text := editor.get_line(line)
	var result := {}
	
	var reserved_columns := find_keywords(text)
	var invalidate_keywords := false
	
	var past_first_nonwhitespace := false
	
	var in_control := false
	var in_tag := false
	var in_choice := false
	var in_label := false
	var in_interpolate := false
	var about_to_leave_interpolate := false
	var in_comment := false
	var line_is_nontext := false
	
	var current_word_start := -1
	
	for i in range(len(text)):
		if not reserved_columns.has(i):
			var whitespace := WHITESPACE_CHARS.contains(text[i])
			if not past_first_nonwhitespace:
				if text[i] == '#':
					in_tag = true
					line_is_nontext = true
				elif text[i] == '@':
					in_control = true
					line_is_nontext = true
				elif text[i] == '=':
					in_label = true
					line_is_nontext = true
				elif text[i] == '>' or text[i] == '-':
					in_choice = true
					
			if about_to_leave_interpolate:
				in_interpolate = false
				about_to_leave_interpolate = false
					
			if not in_comment and not line_is_nontext and text[i] == '{':
				in_interpolate = true
			
			if not in_comment and not line_is_nontext and text[i] == '}':
				about_to_leave_interpolate = true
					
			if current_word_start == -1 and ALPHA_CHARS.contains(text[i]):
				current_word_start = i
				
			if line_is_nontext and text[i] == '=' and current_word_start != -1:
				for j in range(current_word_start, i):
					result[j] = {"color": editor_settings.get(&"text_editor/theme/highlighting/symbol_color")}
				
				current_word_start = -1

			if not in_comment and text[i] == '`':
				in_comment = true
				in_choice = false
				in_tag = false
				in_label = false
				in_control = false
				invalidate_keywords = true

			if whitespace:
				in_tag = false
				in_control = false
				current_word_start = -1
					
			past_first_nonwhitespace = past_first_nonwhitespace or not whitespace
			
		# =========================================================================================
			
		var color := Color.WHITE
		if in_tag:
			color = editor_settings.get(&"text_editor/theme/highlighting/gdscript/function_definition_color")
		elif in_control:
			color = editor_settings.get(&"text_editor/theme/highlighting/control_flow_keyword_color")
		elif in_choice:
			color = editor_settings.get(&"text_editor/theme/highlighting/gdscript/string_name_color")
		elif in_label:
			color = editor_settings.get(&"text_editor/theme/highlighting/user_type_color")
		elif in_interpolate:
			color = editor_settings.get(&"text_editor/theme/highlighting/symbol_color")
		elif in_comment:
			color = editor_settings.get(&"text_editor/theme/highlighting/comment_color")
		elif line_is_nontext and current_word_start == -1 and NUMBERS.contains(text[i]):
			color = editor_settings.get(&"text_editor/theme/highlighting/number_color")
			
		result[i] = {"color": color}
		
	if not invalidate_keywords:
		result.merge(reserved_columns, true)
		
	return result
