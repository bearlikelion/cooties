class_name PlayerSpawner
extends MultiplayerSpawner

const PLAYER_SCENE = preload("res://Scenes/Player/player.tscn")

@onready var spawn_points: Array[Node] = $SpawnPoints.get_children()
@onready var players: Node = $Players


func _ready() -> void:
	spawn_function = spawn_player

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Only the server should spawn players
	if multiplayer.is_server():
		spawn_points.shuffle()

		# Spawn all players (including server)
		for peer_id: int in Global.players.keys():
			call_deferred("spawn", peer_id)


func spawn_player(peer_id: int) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	var spawn_point: Marker2D = spawn_points.pop_back()

	player.set_multiplayer_authority(peer_id)
	player.name = str(peer_id)
	player.global_position = spawn_point.position

	var character_sprite: SpriteFrames

	match Global.players[peer_id].character:
		Global.Characters.VIRTUALGUY:
			character_sprite = load("res://Scenes/Player/CharacterSprites/virtual_guy.tres")
		Global.Characters.PINKMAN:
			character_sprite = load("res://Scenes/Player/CharacterSprites/pink_man.tres")
		Global.Characters.NINJAFROG:
			character_sprite = load("res://Scenes/Player/CharacterSprites/ninja_frog.tres")
		Global.Characters.MASKDUDE:
			character_sprite = load("res://Scenes/Player/CharacterSprites/mask_dude.tres")

	player.animated_sprite_2d.sprite_frames = character_sprite
	return player


func _on_peer_disconnected(peer_id: int) -> void:
	var disconnected_player: Player = players.get_node_or_null(str(peer_id))
	if disconnected_player:
		disconnected_player.queue_free()
