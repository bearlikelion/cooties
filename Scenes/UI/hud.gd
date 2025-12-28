class_name HUD
extends CanvasLayer

const PLAYER_SCORE = preload("res://Scenes/UI/player_score.tscn")

@onready var scores: HBoxContainer = %Scores

func _ready() -> void:
	for peer: int in Global.players.keys():
		_create_player_score(peer)


func _create_player_score(peer_id: int) -> void:
	var player_score: PlayerScore = PLAYER_SCORE.instantiate()
	player_score.set_player_sprite(Global.players[peer_id].character)
	player_score.player_name.text = Global.players[peer_id].name
	player_score.name = str(peer_id)

	scores.add_child(player_score)
