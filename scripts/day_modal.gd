extends ModalBase

# Emitted when the player presses the button; the modal is already closed by then.
signal continued

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	super()
	continue_button.pressed.connect(_on_continue_pressed)


# Day transitions cannot be skipped with Esc; only the button moves the flow on.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func open_message(title: String, body: String, button_text: String) -> void:
	title_label.text = title
	body_label.text = body
	continue_button.text = button_text
	close_button.hide()
	open()


func _on_continue_pressed() -> void:
	close()
	continued.emit()
