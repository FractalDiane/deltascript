class_name DeltascriptEventCompiled
extends Resource

var event_data := {}

func _get_property_list() -> Array:
	return [
		{
			"name": "event_data",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE,
		}
	]
