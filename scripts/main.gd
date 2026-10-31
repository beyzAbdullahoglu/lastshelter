extends Control

@onready var character = $World/Character
@onready var interactive_objects: Control = $World/InteractiveObjects


func _ready() -> void:
	for child in interactive_objects.get_children():
		if child is BaseButton:
			child.pressed.connect(_on_object_pressed.bind(child))
	character.arrived.connect(_on_character_arrived)


func _on_object_pressed(button: Control) -> void:
	# Stand at the bottom-center of the object ("in front" of it).
	var rect := button.get_global_rect()
	var target := Vector2(rect.get_center().x, rect.end.y)
	if button.has_meta("approach_offset"):
		target += button.get_meta("approach_offset")
	character.move_to(target, button)


func _on_character_arrived(target: Node) -> void:
	if target:
		print(target.name)
