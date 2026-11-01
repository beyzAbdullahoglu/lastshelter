extends ModalBase

# Emitted when the player picks an option; the listener applies the effects.
signal choice_made(crisis: Dictionary, intervened: bool)
# Emitted when the player dismisses the result card.
signal resolved(crisis: Dictionary, intervened: bool)

const HUMAN_COLOR := Color(1, 0.706, 0.329)
const NATURE_COLOR := Color(0.373, 0.827, 0.604)
const CRISIS_IMAGE_HEIGHT := 150.0
const FLOOD_IMAGE_HEIGHT := 180.0
const CRISIS_IMAGES := {
	"factory_groundwater": preload("res://assets/crises/factory_groundwater.png"),
	"industrial_waste": preload("res://assets/crises/industrial_waste.png"),
	"plastic_waste": preload("res://assets/crises/plastic_waste.png"),
	"air_pollution": preload("res://assets/crises/air_pollution.png"),
	"deforestation": preload("res://assets/crises/deforestation.png"),
	"forest_fire": preload("res://assets/crises/forest_fire.png"),
	"flash_flood": preload("res://assets/crises/flood.png"),
	"heatwave": preload("res://assets/crises/heatwave.png"),
	"drought": preload("res://assets/crises/drought.png"),
	"biodiversity_loss": preload("res://assets/crises/loss_of_biodiversity.png"),
}

@onready var category_label: Label = %CategoryLabel
@onready var title_label: Label = %TitleLabel
@onready var crisis_image: TextureRect = %CrisisImage
@onready var story_label: Label = %StoryLabel
@onready var choice_view: Control = %ChoiceView
@onready var ignore_effects_label: Label = %IgnoreEffectsLabel
@onready var ignore_button: Button = %IgnoreButton
@onready var intervene_text_label: Label = %InterveneTextLabel
@onready var intervene_effects_label: Label = %InterveneEffectsLabel
@onready var intervene_button: Button = %InterveneButton
@onready var result_view: Control = %ResultView
@onready var outcome_label: Label = %OutcomeLabel
@onready var message_label: Label = %MessageLabel
@onready var ok_button: Button = %OkButton

var _crisis := {}
var _intervened := false


func _ready() -> void:
	super()
	ignore_button.pressed.connect(_choose.bind(false))
	intervene_button.pressed.connect(_choose.bind(true))
	ok_button.pressed.connect(close)


# The card cannot be dismissed (✕ / Esc) until a choice has been made.
func _unhandled_input(event: InputEvent) -> void:
	if result_view.visible:
		super(event)
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func open_crisis(crisis: Dictionary, can_intervene: bool) -> void:
	_crisis = crisis
	category_label.text = CrisisDeck.CATEGORY_NAMES[crisis.category].to_upper()
	category_label.add_theme_color_override("font_color", HUMAN_COLOR if crisis.category == CrisisDeck.HUMAN else NATURE_COLOR)
	title_label.text = crisis.title
	crisis_image.texture = CRISIS_IMAGES.get(crisis.id) as Texture2D
	crisis_image.custom_minimum_size.y = FLOOD_IMAGE_HEIGHT if crisis.id == "flash_flood" else CRISIS_IMAGE_HEIGHT
	crisis_image.visible = crisis_image.texture != null
	story_label.text = crisis.story
	ignore_effects_label.text = _format_outcome(crisis.ignore)
	intervene_text_label.text = crisis.intervene.text
	intervene_effects_label.text = _format_outcome(crisis.intervene)
	intervene_button.disabled = not can_intervene
	intervene_button.text = "Intervene (1 action)" if can_intervene else "No actions left"

	choice_view.show()
	result_view.hide()
	close_button.hide()
	open()


func close() -> void:
	super()
	if not _crisis.is_empty():
		var crisis := _crisis
		_crisis = {}
		resolved.emit(crisis, _intervened)


func _choose(intervened: bool) -> void:
	_intervened = intervened
	choice_made.emit(_crisis, intervened)

	var outcome: Dictionary = _crisis.intervene if intervened else _crisis.ignore
	outcome_label.text = "%s\n%s" % ["You intervened." if intervened else "You did not intervene.", _format_outcome(outcome)]
	message_label.text = _crisis.message
	choice_view.hide()
	result_view.show()
	close_button.show()


static func _format_outcome(outcome: Dictionary) -> String:
	var text := CrisisDeck.describe_effects(outcome.effects)
	if outcome.has("water_growth"):
		var days: int = outcome.water_growth.days
		text += "\nWell regenerates slower for %d day%s." % [days, "" if days == 1 else "s"]
	if outcome.has("reward_flower"):
		text += "\nReward: %s" % Rewards.find_flower(outcome.reward_flower).get("name", "a flower")
	return text
