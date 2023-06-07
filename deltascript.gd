@tool
extends EditorPlugin

var compile_event_hash := "Compile Event".hash()

var editor: DeltascriptEditorPanel = null
var inspector_plugin: DeltascriptInspectorPlugin = null

func add_custom_project_setting(name_: String, default_value: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string := String()) -> void:
	if ProjectSettings.has_setting(name_):
		return
		
	var setting_info := {
		"name": name_,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	}
	
	ProjectSettings.set_setting(name_, default_value)
	ProjectSettings.add_property_info(setting_info)
	ProjectSettings.set_initial_value(name_, default_value)


func _enter_tree() -> void:
	add_custom_project_setting("deltascript/scripts/dialogue_script", String(), TYPE_STRING, PROPERTY_HINT_FILE, "*.gd")
	add_custom_project_setting("deltascript/scripts/choice_script", String(), TYPE_STRING, PROPERTY_HINT_FILE, "*.gd")
	add_custom_project_setting("deltascript/scripts/tag_scripts", {}, TYPE_DICTIONARY)
	add_custom_project_setting("deltascript/event_playback/default_event_metadata", {}, TYPE_DICTIONARY)
	
	editor = preload("res://addons/deltascript/editor/deltascript_editor_panel.tscn").instantiate() as Panel
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, editor)
	
	inspector_plugin = preload("res://addons/deltascript/editor/deltascript_inspector_plugin.gd").new()
	inspector_plugin.editor_settings = get_editor_interface().get_editor_settings()
	inspector_plugin.compile_requested.connect(_on_compile_requested)
	add_inspector_plugin(inspector_plugin)
	
	add_autoload_singleton("Deltascript", "res://addons/deltascript/deltascript_singleton.gd")
	
	var file_system := get_editor_interface().get_file_system_dock()
	var context_menu: PopupMenu
	for child in file_system.get_children():
		if child is PopupMenu:
			context_menu = child
			break

	context_menu.about_to_popup.connect(_on_context_menu_popup.bind(context_menu))
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _on_context_menu_popup(context_menu: PopupMenu) -> void:
	var path := get_editor_interface().get_current_path()
	if path.get_extension() == "tres" and load(path) is DeltascriptEvent:
		context_menu.add_separator()
		context_menu.add_item("Compile Event", compile_event_hash)


func _on_context_menu_id_pressed(id: int) -> void:
	if id == compile_event_hash:
		editor.compile_file(load(get_editor_interface().get_current_path()) as DeltascriptEvent)


func _on_compile_requested(event: DeltascriptEvent) -> void:
	editor.compile_file(event)


func _exit_tree() -> void:
	remove_autoload_singleton("Deltascript")
	remove_inspector_plugin(inspector_plugin)
	remove_control_from_docks(editor)
	editor.free()
	
	
func _get_plugin_name() -> String:
	return "Deltascript"
