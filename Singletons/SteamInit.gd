extends Node

var steam_running: bool = true
var lobby_id: int = 0
var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
var steam_name: String

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var init_steam: Dictionary = Steam.steamInitEx(480)
	print("Steam Init: %s" % init_steam)

	if init_steam['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		steam_running = false
		steam_name = Steam.getPersonaName()


func _process(_delta: float) -> void:
	Steam.run_callbacks()
