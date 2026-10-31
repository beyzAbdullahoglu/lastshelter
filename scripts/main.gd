extends Control

const PIN_BOB_HEIGHT := 6.0
const PIN_BOB_DURATION := 0.6
const FARM_GROWTH_TICK_DURATION := 1.0
const FARM_EMPTY_TEXTURE: Texture2D = preload("res://assets/agriculture/empty.png")
const FARM_GROWING_TEXTURE: Texture2D = preload("res://assets/agriculture/growing.png")
const FARM_WATERED_TEXTURE: Texture2D = preload("res://assets/agriculture/watered.png")

# Object name -> house task it fulfils when the character reaches it.
const OBJECT_ACTIONS := {
	"SolarPanel": {"task": "energy", "message": "Collect energy (%d units)", "button": "Collect", "done": "Energy is already collected for today."},
}

@onready var character = $World/Character
@onready var interactive_objects: Control = $World/InteractiveObjects
@onready var house_task_pin: Button = $World/InteractiveObjects/House/HouseTaskPin
@onready var house_tasks_modal = $HouseTasksModal
@onready var action_modal = $ActionModal
@onready var farm_action_modal = $FarmActionModal
@onready var farm_button: TextureButton = $World/InteractiveObjects/Farm
@onready var farm_timer_label: Label = $World/InteractiveObjects/Farm/FarmTimer
@onready var water_bar: ProgressBar = $HUD/TopPanel/Resources/WaterBox/WaterBar
@onready var food_bar: ProgressBar = $HUD/TopPanel/Resources/FoodBox/FoodBar
@onready var energy_bar: ProgressBar = $HUD/TopPanel/Resources/EnergyBox/EnergyBar
@onready var nature_bar: ProgressBar = $HUD/TopPanel/Resources/NatureBox/NatureBar

var current_day := 1
var _farm_is_planted := false
var _farm_is_ready := false
var _farm_growth_generation := 0


func _ready() -> void:
	for child in interactive_objects.get_children():
		if child is BaseButton:
			child.pressed.connect(_on_object_pressed.bind(child))
	character.arrived.connect(_on_character_arrived)

	house_tasks_modal.set_day(current_day)
	house_task_pin.pressed.connect(house_tasks_modal.open)
	house_tasks_modal.task_completed.connect(_on_house_task_completed)
	house_tasks_modal.all_tasks_completed.connect(house_task_pin.hide)
	action_modal.confirmed.connect(house_tasks_modal.complete_task)
	farm_action_modal.confirmed.connect(_on_farm_option_selected)
	_reset_farm()
	_start_pin_bob()


func _on_object_pressed(button: Control) -> void:
	# Stand at the bottom-center of the object ("in front" of it).
	var rect := button.get_global_rect()
	var target := Vector2(rect.get_center().x, rect.end.y)
	if button.has_meta("approach_offset"):
		target += button.get_meta("approach_offset")
	character.move_to(target, button)


func _on_character_arrived(target: Node) -> void:
	if target != null and target.name == "Farm":
		_open_farm_options()
		return
	if target == null or not OBJECT_ACTIONS.has(target.name):
		return

	var action: Dictionary = OBJECT_ACTIONS[target.name]
	house_tasks_modal.close()
	if house_tasks_modal.is_completed(action.task):
		action_modal.open_action(action.task, action.done)
	else:
		action_modal.open_action(action.task, action.message % DayTasks.MAIN_TASK_REQUIRED, action.button)


func _open_farm_options() -> void:
	if _farm_is_planted:
		if not _farm_is_ready:
			return
		farm_action_modal.open_choices(
			"Choose a harvest method",
			"harvest_standard",
			"Basic harvest",
			"harvest_careful",
			"Eco harvest"
		)
	else:
		farm_action_modal.open_choices(
			"Choose a planting and watering method",
			"plant_basic",
			"Basic irrigation",
			"plant_drip",
			"Drip irrigation"
		)


func _on_farm_option_selected(option_id: String) -> void:
	match option_id:
		"plant_basic":
			_apply_resource_changes(-18, 0, -3, -5)
			_start_farm_growth(15)
		"plant_drip":
			_apply_resource_changes(-8, 0, -2, -1)
			_start_farm_growth(30)
		"harvest_standard":
			_apply_resource_changes(0, 20, -5, -7)
			_reset_farm()
		"harvest_careful":
			_apply_resource_changes(0, 17, -2, 3)
			_reset_farm()


func _apply_resource_changes(water: float, food: float, energy: float, nature: float) -> void:
	water_bar.value += water
	food_bar.value += food
	energy_bar.value += energy
	nature_bar.value += nature


func _start_farm_growth(duration_seconds: int) -> void:
	_farm_growth_generation += 1
	_farm_is_planted = true
	_farm_is_ready = false
	_set_farm_texture(FARM_WATERED_TEXTURE)
	farm_timer_label.show()
	_run_farm_growth_timer(duration_seconds, _farm_growth_generation)


func _run_farm_growth_timer(duration_seconds: int, generation: int) -> void:
	var seconds_remaining := duration_seconds
	while seconds_remaining > 0:
		if generation != _farm_growth_generation or not _farm_is_planted:
			return
		var minutes := int(seconds_remaining / 60)
		farm_timer_label.text = "%02d:%02d" % [minutes, seconds_remaining % 60]
		await get_tree().create_timer(FARM_GROWTH_TICK_DURATION).timeout
		seconds_remaining -= 1

	if generation == _farm_growth_generation and _farm_is_planted:
		_farm_is_ready = true
		farm_timer_label.hide()
		_set_farm_texture(FARM_GROWING_TEXTURE)


func _reset_farm() -> void:
	_farm_growth_generation += 1
	_farm_is_planted = false
	_farm_is_ready = false
	farm_timer_label.hide()
	_set_farm_texture(FARM_EMPTY_TEXTURE)


func _set_farm_texture(texture: Texture2D) -> void:
	farm_button.texture_normal = texture
	farm_button.texture_hover = texture
	farm_button.texture_pressed = texture


func _start_pin_bob() -> void:
	var base_y := house_task_pin.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(house_task_pin, "position:y", base_y - PIN_BOB_HEIGHT, PIN_BOB_DURATION)
	tween.tween_property(house_task_pin, "position:y", base_y, PIN_BOB_DURATION)


func _on_house_task_completed(task_id: String, is_special: bool) -> void:
	# TODO: remaining per-task effects to be specified.
	match task_id:
		"energy":
			# Collected energy is spent from the global energy resource.
			energy_bar.value -= DayTasks.MAIN_TASK_REQUIRED
		"water", "food":
			pass
		"plant_tree", "recycling", "water_leak":
			pass
	print("Task completed: %s (special: %s)" % [task_id, is_special])
