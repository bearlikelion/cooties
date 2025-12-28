class_name MainMenu
extends Control

enum  MultiplayerBackend { ENET, STEAM }

@onready var steam_warning: Label = %SteamWarning
@onready var host_game: Button = %HostGame
@onready var join_game: Button = %JoinGame
@onready var game_buttons: VBoxContainer = %GameButtons
@onready var game_lobbies: VBoxContainer = %GameLobbies
@onready var lobby_list: VBoxContainer = %LobbyList
@onready var backend: OptionButton = %Backend
@onready var enet: HBoxContainer = %Enet
@onready var steam: VBoxContainer = %Steam
@onready var ip_address: LineEdit = %IPAddress


func _ready() -> void:
	if not SteamInit.steam_running:
		# host_game.disabled = true
		# join_game.disabled = true
		backend.selected = 0
	else:
		steam_warning.hide()
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		Steam.lobby_created.connect(_on_lobby_created)


func _on_join_game_pressed() -> void:
	game_buttons.hide()
	game_lobbies.show()

	match backend.selected:
		MultiplayerBackend.ENET:
			enet.show()
			steam.hide()
		MultiplayerBackend.STEAM:
			enet.hide()
			steam.show()

	get_lobbies()


func _on_lobby_match_list(lobbies: Array) -> void:
	print("Lobbies Found: %s" % lobbies.size())

	for lobby_id: int in lobbies:
		var lobby_name: String = Steam.getLobbyData(lobby_id, "name")
		var lobby_players: int = Steam.getNumLobbyMembers(lobby_id)

		# Create join lobby button
		var lobby_button: Button = Button.new()
		lobby_button.text = "%s - %d players" % [lobby_name, lobby_players]
		lobby_button.name = "lobby_" + str(lobby_id)
		lobby_button.pressed.connect(join_lobby.bind(lobby_id))
		lobby_list.add_child(lobby_button)


func _on_lobby_created(connected: int, lobby_id: int) -> void:
	if connected == 1:
		print("Created lobby %s" % lobby_id)
		SteamInit.lobby_id = lobby_id
		SteamInit.peer.host_with_lobby(lobby_id) # Use Steam MultiplayerPeer
		multiplayer.multiplayer_peer = SteamInit.peer

		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s lobby")
		Steam.setLobbyData(lobby_id, "game", "GodotCootiesMPTutorial")

		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to relay backup: %s" % set_relay)

		var main: Main = get_tree().get_first_node_in_group('main')
		if main:
			main.change_level("res://Scenes/Lobby/lobby.tscn")


func join_lobby(lobby_id: int) -> void:
	print("Attempting to join lobby %s" % lobby_id)
	Steam.joinLobby(lobby_id)


func get_lobbies() -> void:
	print("Requesting lobby list")
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE) # Get ALL lobbies
	Steam.addRequestLobbyListStringFilter("game", "GodotCootiesMPTutorial", Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()


func _clear_lobby_list() -> void:
	# Clear any created lobby buttons
	for lobby_button: Button in lobby_list.get_children():
		lobby_button.queue_free()


func _on_back_pressed() -> void:
	print("Back to menu")
	_clear_lobby_list()
	game_lobbies.hide()
	game_buttons.show()


func _on_refresh_pressed() -> void:
	print("Refresh pressed")
	_clear_lobby_list()
	get_lobbies()


func _on_host_game_pressed() -> void:
	match backend.selected:
		MultiplayerBackend.ENET:
			print("Creating ENET Server")
			var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
			var error: Error = peer.create_server(7777, 4)
			if error:
				print("Server Error: %s" % error)
			else:
				multiplayer.multiplayer_peer = peer
				var main: Main = get_tree().get_first_node_in_group('main')
				if main:
					main.change_level("res://Scenes/Lobby/lobby.tscn")
		MultiplayerBackend.STEAM:
			print("Hosting Steam Lobby")
			Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 4)


func _on_connect_pressed() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip_address.text, 7777)
	if error:
		print("Client Error: %s" % error)
	else:
		multiplayer.multiplayer_peer = peer
		var main: Main = get_tree().get_first_node_in_group('main')
		if main:
			main.change_level("res://Scenes/Lobby/lobby.tscn")
