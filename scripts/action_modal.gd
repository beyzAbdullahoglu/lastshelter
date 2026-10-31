extends ModalBase

signal confirmed(action_id: String)

@onready var message_label: Label = %MessageLabel
@onready var action_button: Button = %ActionButton

var _action_id := ""


func _ready() -> void:
	super()
	action_button.pressed.connect(_on_action_pressed)


# Shows the modal for one action. An empty button_text shows the message only.
func open_action(action_id: String, message: String, button_text := "") -> void:
	_action_id = action_id
	message_label.text = message
	action_button.text = button_text
	action_button.visible = not button_text.is_empty()
	open()


func _on_action_pressed() -> void:
	close()
	confirmed.emit(_action_id)
