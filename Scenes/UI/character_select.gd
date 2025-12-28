class_name CharacterSelect
extends PanelContainer

@export var player_name: Label

var is_ready: bool = false

@onready var character_sprite: TextureRect = %CharacterSprite
@onready var character_option: OptionButton = %CharacterOption
@onready var ready_button: Button = %ReadyButton


func _ready() -> void:
	if not is_multiplayer_authority():
		# Disable character select for other players
		character_option.disabled = true
		ready_button.disabled = true

		if Global.players[int(name)].character != 0:
			character_option.select(Global.players[int(name)].character)
			_update_character_sprite(Global.players[int(name)].character)

	else:
		character_option.item_selected.connect(_on_character_changed)
		ready_button.toggled.connect(_on_ready_button_toggled)

		# Color yourself green
		player_name.modulate = Color("#6fb365")

		# Select random character
		# HACK Godot doesn't emit the item_selected signal when using the select(index: int) function
		var random_character_index: int = randi_range(0, 3)
		character_option.select(random_character_index)
		character_option.item_selected.emit(random_character_index)


func _on_character_changed(index: int) -> void:
	_update_character_sprite.rpc(index)


# Updates the character sprite texture across all clients
@rpc("any_peer", "call_local", "reliable")
func _update_character_sprite(index: int) -> void:
	var character_texture: Resource

	match index:
		Global.Characters.VIRTUALGUY:
			character_texture = load("res://Assets/Images/Characters/Virtual Guy/Jump (32x32).png")
		Global.Characters.PINKMAN:
			character_texture = load("res://Assets/Images/Characters/Pink Man/Jump (32x32).png")
		Global.Characters.NINJAFROG:
			character_texture = load("res://Assets/Images/Characters/Ninja Frog/Jump (32x32).png")
		Global.Characters.MASKDUDE:
			character_texture = load("res://Assets/Images/Characters/Mask Dude/Jump (32x32).png")

	character_sprite.texture = character_texture

	# Update Global via RPC to sync across all clients
	var peer_id: int = multiplayer.get_remote_sender_id()
	Global.set_player_character.rpc(peer_id, index)


# Called when ready button is toggled
func _on_ready_button_toggled(toggled_on: bool) -> void:
	_set_ready.rpc(toggled_on)


# Updates ready state across all clients
@rpc("any_peer", "call_local", "reliable")
func _set_ready(player_ready: bool) -> void:
	is_ready = player_ready

	if ready:
		ready_button.modulate = Color("#6fb365")  # Green
	else:
		ready_button.modulate = Color.WHITE

	# Notify lobby to check if all players are ready
	var lobby: Lobby = get_tree().get_first_node_in_group("lobby")
	if lobby:
		lobby.check_all_ready()
