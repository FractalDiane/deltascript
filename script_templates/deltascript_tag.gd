# meta-name: Deltascript Tag
# meta-description: User-created Tag to be used within a Deltascript event.

extends _BASE_

# Called when the line containing the tag is reached.
func _line_start() -> void:
_TS_pass


# Called when the line containing the tag completes.
func _line_end() -> void:
_TS_pass
