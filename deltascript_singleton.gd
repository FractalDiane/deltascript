extends Node

func play_event(event: DeltascriptEventCompiled, force_localization_off: bool = false) -> DeltascriptEventPlayer:
	var player := DeltascriptEventPlayer.new()
	get_tree().get_root().add_child(player)
	#player.play_event(event, force_localization_off)
	player.play_event.call_deferred(event, force_localization_off)
	return player
