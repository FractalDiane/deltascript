class_name DeltascriptInspectorPlugin
extends EditorInspectorPlugin

signal compile_requested(event: DeltascriptEvent)

var script_editor := preload("res://addons/deltascript/editor/deltascript_script_editor.gd")

var editor_settings: EditorSettings = null

func _can_handle(object: Object) -> bool:
	return object is DeltascriptEvent


func _parse_category(object: Object, category: String) -> void:
	if category == "deltascript_event.gd":
		var button := Button.new()
		button.text = "Compile Event"
		button.pressed.connect(_on_button_clicked.bind(object as DeltascriptEvent))
		add_custom_control(button)


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: PropertyUsageFlags, wide: bool) -> bool:
	if name == "event_script":
		var editor := script_editor.new() as DeltascriptScriptEditor
		editor.fetch_editor_settings(editor_settings)
		add_property_editor(name, editor)
		return true
	else:
		return false


func _on_button_clicked(event: DeltascriptEvent) -> void:
	compile_requested.emit(event)
