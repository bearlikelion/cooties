class_name Game
extends Node

enum GameState { WAITING, PLAYING, ROUND_END, GAME_OVER }

@export var max_rounds: int = 5
@export var round_delay: float = 3.0
@export var scoreboard_delay: float = 4.0
@export var score_tick_rate: float = 1.0

# how dampened the score scaling is against starter infection chance (low = strong, high = weak)
@export var infection_score_damping: float = 20

var current_state: GameState = GameState.WAITING
var current_round: int = 0

# Timers (created programmatically)
var round_delay_timer: Timer
var scoreboard_timer: Timer
var score_tick_timer: Timer

@onready var players_node: Node = $PlayerSpawner/Players
@onready var hud: HUD = $HUD
@onready var spawn_points_node: Node = $PlayerSpawner/SpawnPoints


func _ready() -> void:
	add_to_group("game")

	# Only server manages game logic
	if not multiplayer.is_server():
		return

	Steam.setLobbyJoinable(SteamInit.lobby_id, false)

	_setup_timers()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Wait for players to spawn
	await get_tree().create_timer(0.5).timeout
	_start_round()


# Create and configure all timers
func _setup_timers() -> void:
	# Round delay timer (countdown before round starts)
	round_delay_timer = Timer.new()
	round_delay_timer.one_shot = true
	round_delay_timer.timeout.connect(_on_round_delay_complete)
	add_child(round_delay_timer)

	# Scoreboard display timer (between rounds)
	scoreboard_timer = Timer.new()
	scoreboard_timer.one_shot = true
	scoreboard_timer.timeout.connect(_on_scoreboard_complete)
	add_child(scoreboard_timer)

	# Score tick timer (awards points every second)
	score_tick_timer = Timer.new()
	score_tick_timer.wait_time = score_tick_rate
	score_tick_timer.timeout.connect(_on_score_tick)
	add_child(score_tick_timer)


# Start a new round
func _start_round() -> void:
	if not multiplayer.is_server():
		return

	current_round += 1
	print("Starting Round %d of %d" % [current_round, max_rounds])

	# Respawn all players at randomized spawn points
	if current_round > 1:
		_respawn_players()

	# Update UI for all clients
	_update_round_state.rpc(current_round, GameState.WAITING)

	# Reset all players to non-infected state
	for player: Player in players_node.get_children():
		if player is Player:
			_set_player_infected.rpc(int(player.name), false)

	# Start countdown before round begins
	round_delay_timer.start(round_delay)


# Called when round delay completes
func _on_round_delay_complete() -> void:
	var all_players: Array[Node] = players_node.get_children()
	if all_players.is_empty():
		print("No players available, ending game")
		_end_game()
		return
	
	# Select random player to be infected
	var random_infected_peer_id: int = _determine_next_infected_player(all_players)
	_set_player_infected.rpc(random_infected_peer_id, true)

	print("Player %s is now infected!" % random_infected_peer_id)

	# Start active gameplay
	_update_round_state.rpc(current_round, GameState.PLAYING)
	score_tick_timer.start()



# returns the peer_id of the next infected player weighted exponentially (with damping term infection_score_damping)
func _determine_next_infected_player(all_players: Array[Node]) -> int:
	# use the Softmax staistical function to create probabilities based on the score. 
	# Eq. 1: P = e^Z / sum(e^Zj)) 
	# Where: 
	# 	 P = the player probability of infection
	# 	 Z = the player score
	# 	Zj = the j'th player score
	
	# gather all the scores.
	var scores: Array[int] = []
	for player: Node in all_players:
		scores.append(Global.get_player_score(int(player.name)))
	var max_score: int = scores.max()
	
	# calculate the shifted exponetial values for use in Eq. 1
	# essentially, exponentials are 'shift-invariant' so shifting scores keeps everything to scale while preventing float.inf
	# See https://gregorygundersen.com/blog/2020/02/09/log-sum-exp/ for more information
	var exp_sum: float = 0
	var exp_scores: Array[float] = []
	for score: int in scores:
		var exp_score: float = exp((score - max_score) / infection_score_damping)
		exp_sum += exp_score
		exp_scores.append(exp_score)
	
	# now actually calculate the probabilities
	var probabilities: Array[float] = []
	for exp_score: float in exp_scores:
		probabilities.append(exp_score / exp_sum)
	
	print("Infection probabilities: %s\nPlayer scores: %s" % [probabilities, scores])
	
	var random_number: float = randf()
	
	# now determine the player infected via cumulative distribution
	var infected_peer_id: int = 0
	var cumulative_prob: float = 0
	for i: int in all_players.size():
		cumulative_prob += probabilities[i]
		if random_number < cumulative_prob:
			infected_peer_id = int(all_players[i].name)
			break
	
	return infected_peer_id


# Award points every second to non-infected players
func _on_score_tick() -> void:
	for player: Player in players_node.get_children():
		if player is Player and not player.is_infected:
			var peer_id: int = int(player.name)
			var current_score: int = Global.get_player_score(peer_id)
			_update_player_score.rpc(peer_id, current_score + 1)


# Check if the round should end (all players infected)
func _check_round_end() -> void:
	if current_state != GameState.PLAYING:
		return

	var infected_count: int = 0
	var total_count: int = 0

	for player: Player in players_node.get_children():
		if player is Player:
			total_count += 1
			if player.is_infected:
				infected_count += 1

	# Edge case: No players left
	if total_count == 0:
		print("No players remaining, ending game")
		_end_game()
		return

	# Edge case: Only one player left
	if total_count == 1:
		print("Only one player remaining, ending round")
		_end_round()
		return

	# All players infected - round is over
	if infected_count == total_count:
		print("All players infected! Round over.")
		_end_round()
		return

	# Edge case: No infected players (all disconnected)
	if infected_count == 0:
		print("No infected players remaining, restarting round")
		current_round -= 1  # Don't count this round
		_start_round()


# End the current round
func _end_round() -> void:
	score_tick_timer.stop()

	if current_round >= max_rounds:
		_end_game()
	else:
		_update_round_state.rpc(current_round, GameState.ROUND_END)
		scoreboard_timer.start(scoreboard_delay)


# Called when scoreboard timer completes
func _on_scoreboard_complete() -> void:
	_start_round()


# End the game and determine winner
func _end_game() -> void:
	score_tick_timer.stop()
	_update_round_state.rpc(current_round, GameState.GAME_OVER)

	# Find winner (highest score)
	var winner_peer_id: int = -1
	var highest_score: int = -1

	for peer_id: int in Global.players.keys():
		var score: int = Global.get_player_score(peer_id)
		if score > highest_score:
			highest_score = score
			winner_peer_id = peer_id

	if winner_peer_id != -1:
		var winner_name: String = Global.get_player_name(winner_peer_id)
		_announce_winner.rpc(winner_name, highest_score)


# Called by player when collision detected
func infect_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("Infecting player %d" % peer_id)
	_set_player_infected.rpc(peer_id, true)
	_check_round_end()


# Respawn all players at randomized unique spawn points
func _respawn_players() -> void:
	if not multiplayer.is_server():
		return

	# Get all spawn points and shuffle them
	var available_spawns: Array[Node] = spawn_points_node.get_children().duplicate()
	available_spawns.shuffle()

	# Teleport each player to a unique spawn point
	for player: Player in players_node.get_children():
		if player is Player and not available_spawns.is_empty():
			var spawn: Marker2D = available_spawns.pop_back()
			_teleport_player.rpc(int(player.name), spawn.global_position)


# Handle player disconnection mid-game
func _on_peer_disconnected(peer_id: int) -> void:
	print("Player %d disconnected during game" % peer_id)

	# Wait for player to be removed from scene tree
	await get_tree().process_frame
	_check_round_end()


# RPC: Set player infection state
@rpc("authority", "call_local", "reliable")
func _set_player_infected(peer_id: int, infected: bool) -> void:
	var player: Player = players_node.get_node_or_null(str(peer_id))
	if player:
		player.set_infected(infected)

	if hud:
		hud.update_infection_display(peer_id, infected)


# RPC: Update round state on all clients
@rpc("authority", "call_local", "reliable")
func _update_round_state(this_round: int, state: GameState) -> void:
	current_round = this_round
	current_state = state

	if hud:
		hud.update_round_display(current_round, max_rounds)

	print("Round state updated: Round %d, State: %s" % [this_round, GameState.keys()[state]])


# RPC: Update player score on all clients
@rpc("authority", "call_local", "reliable")
func _update_player_score(peer_id: int, new_score: int) -> void:
	Global.set_player_score(peer_id, new_score)

	if hud:
		hud.update_score_display(peer_id, new_score)


# RPC: Announce game winner
@rpc("authority", "call_local", "reliable")
func _announce_winner(winner_name: String, final_score: int) -> void:
	# TODO: Show winner screen/overlay in UI
	print("=== GAME OVER ===")
	print("Winner: %s with %d points!" % [winner_name, final_score])

	await get_tree().create_timer(5.0).timeout
	Global.change_level("res://Scenes/Lobby/lobby.tscn")


# RPC: Teleport player to spawn position
@rpc("authority", "call_local", "reliable")
func _teleport_player(peer_id: int, position: Vector2) -> void:
	var player: Player = players_node.get_node_or_null(str(peer_id))
	if player:
		player.global_position = position
