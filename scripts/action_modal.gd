extends ModalBase

signal confirmed(action_id: String)

@onready var message_label: RichTextLabel = %MessageLabel
@onready var action_button: Button = %ActionButton
@onready var secondary_action_button: Button = %SecondaryActionButton

var _first_action_id := ""
var _second_action_id := ""


func _ready() -> void:
	super()
	action_button.pressed.connect(_on_first_action_pressed)
	secondary_action_button.pressed.connect(_on_second_action_pressed)


# Shows the modal for one action. An empty button_text shows the message only.
func open_action(action_id: String, message: String, button_text := "") -> void:
	_first_action_id = action_id
	message_label.text = _format_message(message)
	action_button.text = button_text
	action_button.visible = not button_text.is_empty()
	secondary_action_button.hide()
	open()


func open_choices(message: String, first_action_id: String, first_button_text: String, second_action_id: String, second_button_text: String) -> void:
	_first_action_id = first_action_id
	_second_action_id = second_action_id
	message_label.text = _format_message(message)
	action_button.text = first_button_text
	action_button.show()
	secondary_action_button.text = second_button_text
	secondary_action_button.show()
	open()


func _on_first_action_pressed() -> void:
	_confirm(_first_action_id)


func _on_second_action_pressed() -> void:
	_confirm(_second_action_id)


func _format_message(message: String) -> String:
	var formatted := message
	formatted = formatted.replace("{water}", "[img=18x18]res://assets/ui_icons/water_icon.png[/img]")
	formatted = formatted.replace("{food}", "[img=18x18]res://assets/ui_icons/wheat_icon.png[/img]")
	formatted = formatted.replace("{energy}", "[img=18x18]res://assets/ui_icons/energy_icon.png[/img]")
	formatted = formatted.replace("{nature}", "[img=18x18]res://assets/ui_icons/leafy_vegetable_icon.png[/img]")
	return formatted


func _confirm(action_id: String) -> void:
	close()
	confirmed.emit(action_id)
