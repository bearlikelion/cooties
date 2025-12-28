class_name HUD
extends CanvasLayer

const PLAYER_SCORE = preload("res://Scenes/UI/player_score.tscn")

@onready var scores: HBoxContainer = %Scores
@onready var current_round_label: Label = %CurrentRound
@onready var max_round_label: Label = %MaxRound

func _ready() -> void:
	for peer: int in Global.players.keys():
		_create_player_score(peer)


func _create_player_score(peer_id: int) -> void:
	var player_score: PlayerScore = PLAYER_SCORE.instantiate()
	player_score.set_player_sprite(Global.players[peer_id].character)
	player_score.player_name.text = Global.players[peer_id].name
	player_score.name = str(peer_id)

	scores.add_child(player_score)


# Update the round display
func update_round_display(current_round: int, max_rounds: int) -> void:
	current_round_label.text = str(current_round)
	max_round_label.text = str(max_rounds)


# Update a specific player's score display
func update_score_display(peer_id: int, new_score: int) -> void:
	var player_score_ui: PlayerScore = scores.get_node_or_null(str(peer_id))
	if player_score_ui:
		player_score_ui.update_score(new_score)


# Update a specific player's infection display
func update_infection_display(peer_id: int, infected: bool) -> void:
	var player_score_ui: PlayerScore = scores.get_node_or_null(str(peer_id))
	if player_score_ui:
		player_score_ui.set_infected_display(infected)
