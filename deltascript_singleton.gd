extends Node

var user_tags := {}

func _ready() -> void:
	var user_tag_scripts: Array = ProjectSettings.get_setting(&"deltascript/scripts/tag_scripts", [])
	for tag in user_tag_scripts:
		var script: Script = load(tag)
		if script != null:
			var script_inst := script.new() as DeltascriptTag
			user_tags[script_inst._get_tag_identifier()] = tag
		else:
			push_error("Deltascript: Tag script specified in project settings %s is invalid" % tag)


func play_event(event: DeltascriptEventCompiled, force_localization_off: bool = false) -> DeltascriptEventPlayer:
	var player := DeltascriptEventPlayer.new()
	get_tree().get_root().add_child.call_deferred(player)
	player.play_event.call_deferred(event, force_localization_off)
	return player
