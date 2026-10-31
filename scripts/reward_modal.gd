extends ModalBase

@onready var flower_image: TextureRect = %FlowerImage
@onready var flower_name_label: Label = %FlowerNameLabel
@onready var message_label: Label = %MessageLabel
@onready var ok_button: Button = %OkButton


func _ready() -> void:
	super()
	ok_button.pressed.connect(close)


func open_reward(flower: Dictionary, reason: String) -> void:
	flower_image.texture = flower.texture
	flower_name_label.text = flower.name
	message_label.text = "You have earned %s because %s." % [flower.name, reason]
	open()
