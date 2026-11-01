extends Control

@onready var menu_content: VBoxContainer = %MenuContent
@onready var rules_content: VBoxContainer = %RulesContent
@onready var start_button: Button = %StartButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	how_to_play_button.pressed.connect(_show_rules)
	back_button.pressed.connect(_show_menu)


func _start_game() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/Main.tscn")
	if error != OK:
		push_error("Could not open the main game scene: %s" % error_string(error))


func _show_rules() -> void:
	menu_content.hide()
	rules_content.show()


func _show_menu() -> void:
	rules_content.hide()
	menu_content.show()
