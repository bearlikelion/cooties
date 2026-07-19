class_name PauseMenu
extends CanvasLayer

@onready var resume_button: Button = %ResumeButton
@onready var disconnect_button: Button = %DisconnectButton


func _ready() -> void:
	visible = false


# Toggle with pause (Escape/Start), close with ui_cancel (Escape/B)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


# Show the menu and stop the local player from moving
# The game is not actually paused, other players keep playing
func open_menu() -> void:
	visible = true
	Global.menu_open = true
	resume_button.grab_focus()


# Hide the menu and give control back to the local player
func close_menu() -> void:
	visible = false
	Global.menu_open = false


func _on_resume_pressed() -> void:
	close_menu()


func _on_disconnect_pressed() -> void:
	Global.disconnect_from_game()
