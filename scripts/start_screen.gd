extends Control

@onready var start_button: Button = %StartButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var how_to_play_overlay: ColorRect = %HowToPlayOverlay
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	how_to_play_button.pressed.connect(_show_how_to_play)
	close_button.pressed.connect(_hide_how_to_play)
	how_to_play_overlay.gui_input.connect(_on_how_to_play_overlay_input)


func _start_game() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/Main.tscn")
	if error != OK:
		push_error("Could not load the main game scene. Error: %s" % error)


func _show_how_to_play() -> void:
	how_to_play_overlay.show()


func _hide_how_to_play() -> void:
	how_to_play_overlay.hide()


func _on_how_to_play_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel := how_to_play_overlay.get_node("HowToPlayPanel") as Control
		if not panel.get_global_rect().has_point(event.global_position):
			_hide_how_to_play()
