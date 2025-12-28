extends Node

signal change_level_to
signal player_info_updated(peer_id: int)
signal players_synced

enum Characters { VIRTUALGUY, PINKMAN, NINJAFROG, MASKDUDE }

var ip_address: String = "127.0.0.1"

# Dictionary storing player information by peer_id
# Structure: {peer_id: {character: int, name: String, score: int}}
var players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func change_level(scene_path: String) -> void:
	change_level_to.emit(scene_path)


# Called when a peer connects
func _on_peer_connected(peer_id: int) -> void:
	print("GLOBAL PEER CONNECTED: %d" % peer_id)
	if not players.has(peer_id):
		players[peer_id] = {
			"character": -1,
			"name": str(peer_id),
			"score": 0
		}


@rpc("any_peer", "call_remote", "reliable")
func get_player_from_server(peer_id: int) -> void:
	if multiplayer.is_server():
		if Global.players.has(peer_id):
			send_player_to_peer.rpc_id(multiplayer.get_remote_sender_id(), peer_id, Global.players[peer_id])


@rpc("authority", "call_remote", "reliable")
func send_player_to_peer(peer_id: int, player_data: Dictionary) -> void:
	Global.players[peer_id] = player_data


# Called when a peer disconnects
func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)

	if peer_id == 1:
		change_level("res://Scenes/MainMenu/main_menu.tscn")


# Called when this client successfully connects to server
func _on_connected_to_server() -> void:
	print("GLOBAL CONNECTED TO SERVER")
	var local_id: int = multiplayer.get_unique_id()

	# Send our player name to the server
	# The server will sync back to us after receiving our name
	var player_name: String = str(local_id)
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		player_name = SteamInit.steam_name

	Global.players[local_id] = {
		"character": -1,
		"name": player_name,
		"score": 0
	}

	send_player_to_server.rpc_id(1, Global.players[local_id])


@rpc("any_peer", "call_remote", "reliable")
func send_player_to_server(player: Dictionary) -> void:
	if multiplayer.is_server():
		print("SERVER RECEIVED PLAYER DATA")
		var sender_id: int = multiplayer.get_remote_sender_id()
		players[sender_id] = player

		_sync_players_to_peer.rpc_id(sender_id, players)


# Called when server disconnects
func _on_server_disconnected() -> void:
	clear_players()


# Set player character selection via RPC
@rpc("any_peer", "call_local", "reliable")
func set_player_character(peer_id: int, character_index: int) -> void:
	# HACK: This is a hacky bugfix for an issue when returning to lobbby after a game ends
	# The character_select.gd runs set_player_character too early sending as peer_id 0
	if peer_id > 0:
		players[peer_id]["character"] = character_index
		player_info_updated.emit(peer_id)


# Set player name via RPC
@rpc("any_peer", "call_local", "reliable")
func set_player_name(peer_id: int, player_name: String) -> void:
	players[peer_id]["name"] = player_name

	# If we're the server and received a name from a client, sync back to them
	if multiplayer.is_server() and peer_id != 1:
		# Only sync to remote clients, never to ourselves
		_sync_players_to_peer.rpc_id(peer_id, players)

	player_info_updated.emit(peer_id)


# Get player character index
func get_player_character(peer_id: int) -> int:
	if players.has(peer_id):
		return players[peer_id]["character"]
	return -1


# Get player name
func get_player_name(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id]["name"]
	return str(peer_id)


# Get player score
func get_player_score(peer_id: int) -> int:
	if players.has(peer_id):
		return players[peer_id].get("score", 0)
	return 0


# Set player score via RPC
@rpc("any_peer", "call_local", "reliable")
func set_player_score(peer_id: int, new_score: int) -> void:
	players[peer_id]["score"] = new_score
	player_info_updated.emit(peer_id)


# Clear all player data
func clear_players() -> void:
	players.clear()


# Reset all player scores to 0
func reset_scores() -> void:
	for peer_id: int in players.keys():
		players[peer_id]["score"] = 0


# Add local player to the players dictionary (call this after creating server/client)
func add_local_player() -> void:
	var local_id: int = multiplayer.get_unique_id()
	print("GLOBAL ADD LOCAL PLAYER: %d" % local_id)

	# Get player name from Steam if available
	var player_name: String = str(local_id)
	if SteamInit.steam_running and multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		player_name = Steam.getPersonaName()

	if not players.has(local_id):
		players[local_id] = {
			"character": -1,
			"name": player_name,
			"score": 0
		}

	# Broadcast our name to all clients
	set_player_name.rpc(local_id, player_name)

	# Server doesn't need to wait for sync, emit immediately
	if multiplayer.is_server():
		players_synced.emit()


# Server syncs all player data to a specific peer
@rpc("authority", "call_remote", "reliable")
func _sync_players_to_peer(player_data: Dictionary) -> void:
	print("GLOBAL RECEIVED PLAYER SYNC: %s" % player_data)
	players = player_data.duplicate(true)
	players_synced.emit()
