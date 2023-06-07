extends Node

func play_event(event: DeltascriptEventCompiled, force_localization_off: bool = false) -> DeltascriptEventPlayer:
	var player := DeltascriptEventPlayer.new()
	get_tree().get_root().add_child(player)
	player.play_event.call_deferred(event, force_localization_off)
	#player.initial_load_complete.connect(_play_event_post.bind(event, force_localization_off, player), CONNECT_ONE_SHOT)
	return player

#func _play_event_post(event: DeltascriptEventCompiled, force_localization_off: bool, event_player: DeltascriptEventPlayer) -> void:
#	event_player.play_event.call_deferred(event, force_localization_off)
