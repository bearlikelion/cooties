class_name Lobby
extends Control

const CHARACTER_SELECT = preload("res://Scenes/UI/character_select.tscn")

@onready var lobby_id: Label = %LobbyId
@onready var players: HBoxContainer = %Players

var upnp_thread: Thread


func _ready() -> void:
	add_to_group("lobby")

	if multiplayer.multiplayer_peer is SteamMultiplayerPeer and SteamInit.lobby_id > 0:
		lobby_id.text = "Lobby ID: %s" % SteamInit.lobby_id

	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if multiplayer.is_server():
			lobby_id.text = "Discovering external IP..."
			upnp_thread = Thread.new()
			upnp_thread.start(_discover_upnp)
		else:
			lobby_id.text = "Connected to: %s" % Global.ip_address

	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Create character select for you
	_add_character_select(multiplayer.get_unique_id())


# Creates a character select UI for a specific peer
func _add_character_select(peer_id: int) -> void:
	var character_select: CharacterSelect = CHARACTER_SELECT.instantiate()
	character_select.name = "CharacterSelect_%d" % peer_id

	# Get player name from Global
	character_select.player_name.text = Global.get_player_name(peer_id)

	character_select.set_multiplayer_authority(peer_id)
	players.add_child(character_select, true)


# Called when a new peer connects
func _on_peer_connected(peer_id: int) -> void:
	_add_character_select(peer_id)


# Called when a peer disconnects
func _on_peer_disconnected(peer_id: int) -> void:
	var character_select: Node = players.get_node_or_null("CharacterSelect_%d" % peer_id)
	if character_select:
		character_select.queue_free()


# Checks if all players are ready and starts the game
func check_all_ready() -> void:
	# Only server should check and start game
	if not multiplayer.is_server():
		return

	var all_ready: bool = true

	for character_select: Node in players.get_children():
		if character_select is CharacterSelect:
			if not character_select.is_ready:
				all_ready = false
				break

	if all_ready and players.get_child_count() > 0:
		print("All players ready! Starting game...")
		_start_game.rpc()


# Starts the game on all clients
@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	Global.change_level("res://Scenes/Game/game.tscn")


# Thread function to discover UPNP and get external IP
func _discover_upnp() -> void:
	var upnp: UPNP = UPNP.new()
	var discover_result: int = upnp.discover()

	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		var external_ip: String = upnp.query_external_address()
		if external_ip != "":
			call_deferred("_update_lobby_ip", external_ip)
		else:
			call_deferred("_update_lobby_ip_fallback")
	else:
		call_deferred("_update_lobby_ip_fallback")


# Updates lobby IP text (called from thread)
func _update_lobby_ip(external_ip: String) -> void:
	lobby_id.text = "External IP: %s" % external_ip


# Fallback to local IP if UPNP fails
func _update_lobby_ip_fallback() -> void:
	var local_addresses: Array = IP.get_local_addresses()
	if local_addresses.size() > 0:
		lobby_id.text = "Local IP: %s" % local_addresses[0]
	else:
		lobby_id.text = "IP: Unknown"


func _exit_tree() -> void:
	# Clean up thread if it exists
	if upnp_thread and upnp_thread.is_alive():
		upnp_thread.wait_to_finish()


func _on_disconnect_pressed() -> void:
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		Steam.leaveLobby(SteamInit.lobby_id)

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Global.change_level("res://Scenes/MainMenu/main_menu.tscn")
