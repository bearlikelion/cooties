extends Node

signal change_level_to
signal player_info_updated(peer_id: int)

enum Characters { VIRTUALGUY, PINKMAN, NINJAFROG, MASKDUDE }

var ip_address: String = "127.0.0.1"

# Dictionary storing player information by peer_id
# Structure: {peer_id: {character: int}}
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
func _on_peer_connected(id: int) -> void:
	print("GLOBAL PEER CONNECTED: %d" % id)
	if not players.has(id):
		players[id] = {
			"character": 0
		}

	# If we're the server, sync all player data to the newly connected peer
	if multiplayer.is_server():
		_sync_players_to_peer.rpc_id(id, players)


# Called when a peer disconnects
func _on_peer_disconnected(id: int) -> void:
	players.erase(id)


# Called when this client successfully connects to server
func _on_connected_to_server() -> void:
	print("GLOBAL CONNECTED TO SERVER")
	var local_id: int = multiplayer.get_unique_id()
	if not players.has(local_id):
		players[local_id] = {
			"character": 0
		}

	# Request player data sync from server
	_request_player_sync.rpc_id(1)


# Called when server disconnects
func _on_server_disconnected() -> void:
	clear_players()


# Set player character selection via RPC
@rpc("any_peer", "call_local", "reliable")
func set_player_character(peer_id: int, character_index: int) -> void:
	if not players.has(peer_id):
		players[peer_id] = {"character": character_index}
	else:
		players[peer_id]["character"] = character_index

	player_info_updated.emit(peer_id)


# Get player character index
func get_player_character(peer_id: int) -> int:
	if players.has(peer_id):
		return players[peer_id]["character"]
	return 0


# Clear all player data
func clear_players() -> void:
	players.clear()


# Add local player to the players dictionary (call this after creating server/client)
func add_local_player() -> void:
	var local_id: int = multiplayer.get_unique_id()
	print("GLOBAL ADD LOCAL PLAYER: %d" % local_id)
	if not players.has(local_id):
		players[local_id] = {
			"character": 0
		}


# Client requests player data sync from server
@rpc("any_peer", "call_remote", "reliable")
func _request_player_sync() -> void:
	if multiplayer.is_server():
		var sender_id: int = multiplayer.get_remote_sender_id()
		_sync_players_to_peer.rpc_id(sender_id, players)


# Server syncs all player data to a specific peer
@rpc("authority", "call_remote", "reliable")
func _sync_players_to_peer(player_data: Dictionary) -> void:
	players = player_data.duplicate(true)
