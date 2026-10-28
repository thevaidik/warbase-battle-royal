class_name WarAudioManager
extends Node
## Game audio is disabled until replacement sound assets are approved.
const AUDIO_ENABLED := false
var muted := true
var master_volume := 0.0
var sfx_volume := 0.0

func _ready() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0: AudioServer.set_bus_mute(master, true)

func shoot(_kind: String, _gain_db: float = 0.0) -> void:
	pass

func dry() -> void:
	pass

func reload() -> void:
	pass

func hitmarker(_kill: bool = false) -> void:
	pass

func explosion() -> void:
	pass

func grenade_bounce() -> void:
	pass

func grenade_pin() -> void:
	pass

func step() -> void:
	pass

func hurt() -> void:
	pass

func casing() -> void:
	pass

func ui_btn_click() -> void:
	pass

func click() -> void:
	pass

func ui_btn_hover() -> void:
	pass

func stop_all() -> void:
	pass
