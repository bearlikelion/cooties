class_name CharacterSelect
extends PanelContainer

enum Characters { VIRTUALGUY, PINKMAN, NINJAFROG, MASKDUDE }

@export var player_name: Label

@onready var character_sprite: TextureRect = %CharacterSprite
@onready var character_option: OptionButton = %CharacterOption
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var ready_button: Button = %ReadyButton

var is_ready: bool = false


func _ready() -> void:
	#var color_picker: ColorPicker = color_picker_button.get_picker()
	#color_picker.can_add_swatches = false
	#color_picker.color_modes_visible = false
	#color_picker.edit_alpha = false
	#color_picker.edit_intensity = false
	#color_picker.hex_visible = false
	#color_picker.presets_visible = false
	#color_picker.sampler_visible = false
	#color_picker.sliders_visible = false

	if not is_multiplayer_authority():
		character_option.disabled = true
		ready_button.disabled = true
	else:
		player_name.modulate = Color("#6fb365")

	character_option.item_selected.connect(_on_character_changed)
	ready_button.toggled.connect(_on_ready_button_toggled)


func _on_character_changed(index: int) -> void:
	_update_character_sprite.rpc(index)


# Updates the character sprite texture across all clients
@rpc("any_peer", "call_local", "reliable")
func _update_character_sprite(index: int) -> void:
	var character_texture: Resource

	match index:
		Characters.VIRTUALGUY:
			character_texture = load("res://Assets/Characters/Virtual Guy/Jump (32x32).png")
		Characters.PINKMAN:
			character_texture = load("res://Assets/Characters/Pink Man/Jump (32x32).png")
		Characters.NINJAFROG:
			character_texture = load("res://Assets/Characters/Ninja Frog/Jump (32x32).png")
		Characters.MASKDUDE:
			character_texture = load("res://Assets/Characters/Mask Dude/Jump (32x32).png")

	character_sprite.texture = character_texture


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
