class_name ModalBase
extends Control

@onready var panel: PanelContainer = %Panel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)
	panel.resized.connect(_place_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	show()


func close() -> void:
	hide()


# Centers the close button on the panel's top-right corner so it overflows it.
func _place_close_button() -> void:
	close_button.position = panel.position + Vector2(panel.size.x, 0) - close_button.size / 2
