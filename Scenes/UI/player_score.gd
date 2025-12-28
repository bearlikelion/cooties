class_name PlayerScore
extends VBoxContainer

@export var player_name: Label
@export var player_sprite: TextureRect

@onready var player_score: Label = %PlayerScore


func set_player_sprite(character_id: Global.Characters) -> void:
	var character_sprite: CompressedTexture2D

	match character_id:
		Global.Characters.VIRTUALGUY:
			character_sprite = load("res://Assets/Images/Characters/Virtual Guy/Jump (32x32).png")
		Global.Characters.PINKMAN:
			character_sprite = load("res://Assets/Images/Characters/Pink Man/Jump (32x32).png")
		Global.Characters.NINJAFROG:
			character_sprite = load("res://Assets/Images/Characters/Ninja Frog/Jump (32x32).png")
		Global.Characters.MASKDUDE:
			character_sprite = load("res://Assets/Images/Characters/Mask Dude/Jump (32x32).png")

	player_sprite.texture = character_sprite


# Update the score display
func update_score(new_score: int) -> void:
	player_score.text = str(new_score)


# Set infected visual state
func set_infected_display(infected: bool) -> void:
	if infected:
		# Fart Green
		player_name.modulate = Color(0.6, 0.8, 0.3)
		player_score.modulate = Color(0.6, 0.8, 0.3)
	else:
		player_name.modulate = Color.WHITE
		player_score.modulate = Color.WHITE
