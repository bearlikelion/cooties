class_name HUD
extends CanvasLayer

const PLAYER_SCORE = preload("res://Scenes/UI/player_score.tscn")

# Incremented to cancel any in-flight announcement countdown
var announcement_id: int = 0
var announcement_tween: Tween

@onready var scores: HBoxContainer = %Scores
@onready var current_round_label: Label = %CurrentRound
@onready var max_round_label: Label = %MaxRound
@onready var announcement: Label = %Announcement
@onready var game_over_panel: CenterContainer = %GameOverPanel
@onready var winner_label: Label = %WinnerLabel
@onready var final_scores: HBoxContainer = %FinalScores
@onready var return_label: Label = %ReturnLabel


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


# Show feedback for the current round state
func show_state(state: Game.GameState, this_round: int, countdown: float) -> void:
	match state:
		Game.GameState.WAITING:
			_show_countdown(this_round, countdown)
		Game.GameState.PLAYING:
			show_announcement("GO!", 1.0)
		Game.GameState.ROUND_END:
			show_announcement("Round over!", 3.0)
		Game.GameState.GAME_OVER:
			announcement.hide()


# Show a brief self-hiding announcement message
func show_announcement(message: String, duration: float = 2.0) -> void:
	announcement_id += 1

	if announcement_tween:
		announcement_tween.kill()

	announcement.text = message
	announcement.modulate.a = 1.0
	announcement.show()

	announcement_tween = create_tween()
	announcement_tween.tween_interval(duration)
	announcement_tween.tween_property(announcement, "modulate:a", 0.0, 0.5)
	announcement_tween.tween_callback(announcement.hide)


# Count down to the round start on the announcement label
func _show_countdown(this_round: int, countdown: float) -> void:
	announcement_id += 1
	var this_announcement: int = announcement_id

	if announcement_tween:
		announcement_tween.kill()

	announcement.modulate.a = 1.0
	announcement.show()

	var seconds_left: int = int(ceil(countdown))
	while seconds_left > 0 and announcement_id == this_announcement:
		announcement.text = "Round %d starting in %d..." % [this_round, seconds_left]
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1


# Display the end of game screen with final rankings and a return countdown
func show_game_over(rankings: Array[Dictionary], return_delay: float) -> void:
	announcement_id += 1
	announcement.hide()

	# Build the winner text, handling ties
	if rankings.is_empty():
		winner_label.text = "Everyone left!"
	else:
		var top_score: int = rankings[0].score
		var winners: Array[String] = []
		for entry: Dictionary in rankings:
			if entry.score == top_score:
				winners.append(entry.name)

		if winners.size() == 1:
			winner_label.text = "Winner: %s with %d points!" % [winners[0], top_score]
		else:
			winner_label.text = "It's a draw: %s with %d points!" % [" & ".join(winners), top_score]

	# Populate the ranked score cards
	for child: Node in final_scores.get_children():
		child.queue_free()

	for entry: Dictionary in rankings:
		var player_score: PlayerScore = PLAYER_SCORE.instantiate()
		final_scores.add_child(player_score)
		player_score.set_player_sprite(entry.character)
		player_score.player_name.text = entry.name
		player_score.update_score(entry.score)

	game_over_panel.show()

	# Count down until the game returns to the lobby
	var seconds_left: int = int(ceil(return_delay))
	while seconds_left > 0:
		return_label.text = "Returning to lobby in %d..." % seconds_left
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1
