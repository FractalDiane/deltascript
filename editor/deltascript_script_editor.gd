class_name DeltascriptScriptEditor
extends EditorProperty

const HIGHLIGHTER_PATH := "res://addons/deltascript/editor/deltascript_highlighter.gd"

var container := HBoxContainer.new()
var editor := CodeEdit.new()
var highlighter := preload(HIGHLIGHTER_PATH).new()
var fullscreen_button := Button.new()

var fullscreen_dialog: AcceptDialog = null
var fullscreen_editor: CodeEdit = null

var current_text := String()
var updating := false

func _init() -> void:
	container.add_theme_constant_override(&"separation", 0)
	container.custom_minimum_size.y = 300
	add_child(container)
	set_bottom_editor(container)
	
	editor.text_changed.connect(_text_changed)
	editor.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	add_focusable(editor)
	container.add_child(editor)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.gutters_draw_line_numbers = true
	editor.line_folding = true
	editor.gutters_draw_fold_gutter = true
	editor.highlight_current_line = true
	editor.add_theme_color_override(&"background_color", Color.SLATE_GRAY.darkened(0.7))
	
	highlighter.editor = editor
	editor.syntax_highlighter = highlighter
	
	fullscreen_button.flat = true
	fullscreen_button.icon = preload("res://addons/deltascript/editor/icons/full_screen.svg")
	fullscreen_button.pressed.connect(_fullscreen_pressed)
	container.add_child(fullscreen_button)
	
	refresh_text()
	
	
func fetch_editor_settings(editor_settings: EditorSettings) -> void:
	highlighter.editor_settings = editor_settings
	
	
func refresh_text() -> void:
	editor.text = current_text
	

func _text_changed() -> void:
	if updating:
		return
		
	current_text = editor.text
	#refresh_text()
	emit_changed(get_edited_property(), current_text)
	
	
func _fullscreen_text_changed() -> void:
	current_text = fullscreen_editor.text
	emit_changed(get_edited_property(), current_text)
	refresh_text()
	
	
func _update_property() -> void:
	var new_text: String = get_edited_object()[get_edited_property()]
	if new_text == current_text:
		return
		
	updating = true
	current_text = new_text
	refresh_text()
	updating = false


func _fullscreen_pressed() -> void:
	if fullscreen_dialog == null:
		fullscreen_editor = CodeEdit.new()
		var fullscreen_highlighter := preload(HIGHLIGHTER_PATH).new()
		fullscreen_highlighter.editor = fullscreen_editor
		fullscreen_highlighter.editor_settings = highlighter.editor_settings
		fullscreen_editor.syntax_highlighter = fullscreen_highlighter
		fullscreen_editor.text_changed.connect(_fullscreen_text_changed)
		fullscreen_editor.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
		fullscreen_editor.gutters_draw_line_numbers = true
		fullscreen_editor.highlight_current_line = true
		fullscreen_editor.minimap_draw = true
		fullscreen_editor.line_folding = true
		fullscreen_editor.gutters_draw_fold_gutter = true
		
		fullscreen_dialog = AcceptDialog.new()
		fullscreen_dialog.add_child(fullscreen_editor)
		fullscreen_dialog.title = "Event Script"
		add_child(fullscreen_dialog)
	
	fullscreen_dialog.popup_centered_clamped(Vector2i(1000, 900), 0.8)
	fullscreen_editor.text = editor.text
	fullscreen_editor.grab_focus()
