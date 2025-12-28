class_name Main
extends Node

@onready var level: Node = $Level

func _ready() -> void:
	Global.change_level_to.connect(_on_change_level)


func _on_change_level(new_level_path: String) -> void:
	for child_level: Node in level.get_children():
		child_level.queue_free()

	var new_level_resource: Resource = load(new_level_path)
	if new_level_resource:
		var new_level: Node = new_level_resource.instantiate()
		level.add_child(new_level)
