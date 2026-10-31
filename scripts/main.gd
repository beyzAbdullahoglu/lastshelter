extends Control

const PIN_BOB_HEIGHT := 6.0
const PIN_BOB_DURATION := 0.6
const FARM_GROWTH_TICK_DURATION := 1.0
const FARM_EMPTY_TEXTURE: Texture2D = preload("res://assets/agriculture/empty.png")
const FARM_GROWING_TEXTURE: Texture2D = preload("res://assets/agriculture/growing.png")
const FARM_WATERED_TEXTURE: Texture2D = preload("res://assets/agriculture/watered.png")
const REWARD_FLOWER_SIZE := Vector2(44, 44)
const REWARD_POP_DURATION := 0.35

const TOTAL_DAYS := 6
const DAY_DURATION := 180.0
# Daily resource growth happens once, after this much of the day has passed.
const RESOURCE_GROWTH_TIME := 90.0
const MAX_ACTIONS := 3
const NATURE_THRESHOLD := 50.0
const HEALTHY_NATURE_GROWTH := 5.0
const POOR_NATURE_GROWTH := 2.0
# Seconds into the day at which each daily crisis appears (one human, one natural).
const CRISIS_TIMES := [40.0, 120.0]

# Object name -> house task it fulfils when the character reaches it.
const OBJECT_ACTIONS := {
	"SolarPanel": {"task": "energy", "message": "Collect energy ({units} units)", "button": "Collect", "done": "Energy is already collected for today."},
	"WaterWell": {"task": "water", "message": "Collect water ({units} units)", "button": "Collect", "done": "Water is already collected for today."},
	"RecyclingBin": {"task": "recycling", "message": "Recycle your garbage", "button": "Recycle", "done": "You have already recycled today."},
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
@onready var reward_modal = $RewardModal
@onready var crisis_modal = $CrisisModal
@onready var reward_flowers: HFlowContainer = $World/Decorations/RewardFlowers
@onready var energy_bar: ProgressBar = $HUD/TopPanel/Resources/EnergyBox/EnergyBar
@onready var nature_bar: ProgressBar = $HUD/TopPanel/Resources/NatureBox/NatureBar
@onready var day_label: Label = $HUD/BottomPanel/MarginContainer/MainRow/DayBox/VBox/DayLabel
@onready var action_label: Label = $HUD/BottomPanel/MarginContainer/MainRow/ActionBox/VBox/ActionLabel
@onready var day_timer_label: Label = $HUD/DayTimerLabel

var current_day := 1
var _farm_is_planted := false
var _farm_is_ready := false
var _farm_growth_generation := 0
var actions_left := MAX_ACTIONS
var _day_elapsed := 0.0
var _resources_grown_today := false
var _crisis_deck := CrisisDeck.new()
var _todays_crises: Array = []
# Day -> multiplier on that day's water growth (set by drought crises).
var _water_growth_factors := {}


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
	crisis_modal.choice_made.connect(_on_crisis_choice_made)
	crisis_modal.resolved.connect(_on_crisis_resolved)
	_todays_crises = _crisis_deck.draw_day()
	_start_pin_bob()
	_refresh_day_hud()


func _process(delta: float) -> void:
	# The day clock is frozen while a crisis card is waiting for the player.
	if crisis_modal.visible:
		return
	_day_elapsed += delta
	var crisis_index := CRISIS_TIMES.size() - _todays_crises.size()
	if not _todays_crises.is_empty() and _day_elapsed >= CRISIS_TIMES[crisis_index]:
		_trigger_crisis()
		return
	if not _resources_grown_today and _day_elapsed >= RESOURCE_GROWTH_TIME:
		_grow_resources()
	if _day_elapsed >= DAY_DURATION:
		_start_next_day()
	_refresh_day_timer()


# Counts down from 03:00; ceil keeps 03:00 visible for the first second.
func _refresh_day_timer() -> void:
	var remaining := ceili(maxf(DAY_DURATION - _day_elapsed, 0.0))
	day_timer_label.text = "%02d:%02d" % [floori(remaining / 60.0), remaining % 60]


# Water, food and energy grow once per day; a healthy nature grows them faster.
func _grow_resources() -> void:
	_resources_grown_today = true
	var amount := HEALTHY_NATURE_GROWTH if nature_bar.value > NATURE_THRESHOLD else POOR_NATURE_GROWTH
	food_bar.value += amount
	energy_bar.value += amount
	water_bar.value += amount * _water_growth_factors.get(current_day, 1.0)
	_water_growth_factors.erase(current_day)


# Health (hearts) is intentionally carried over between days.
func _start_next_day() -> void:
	_day_elapsed = 0.0
	_resources_grown_today = false
	current_day += 1
	actions_left = MAX_ACTIONS
	_todays_crises = _crisis_deck.draw_day()
	house_tasks_modal.set_day(current_day)
	house_task_pin.show()
	_refresh_day_hud()


func _refresh_day_hud() -> void:
	day_label.text = "DAY %02d / %02d" % [current_day, TOTAL_DAYS]
	action_label.text = "%d / %d" % [actions_left, MAX_ACTIONS]


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
		action_modal.open_action(action.task, action.message.format({"units": DayTasks.MAIN_TASK_REQUIRED}), action.button)


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
		"water":
			# Collected water is spent from the global water resource.
			water_bar.value -= DayTasks.MAIN_TASK_REQUIRED
		"food":
			pass
	if is_special:
		_grant_flower(task_id)
	print("Task completed: %s (special: %s)" % [task_id, is_special])


func _grant_flower(task_id: String) -> void:
	var task := DayTasks.find_special_task(current_day, task_id)
	var flower := Rewards.random_flower()
	_plant_reward_flower(flower)
	reward_modal.open_reward(flower, task.get("reward_reason", "you completed a special task"))


# Adds the flower to the patch left of the house with a small pop-in.
func _plant_reward_flower(flower: Dictionary) -> void:
	var sprite := TextureRect.new()
	sprite.texture = flower.texture
	sprite.custom_minimum_size = REWARD_FLOWER_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.pivot_offset = REWARD_FLOWER_SIZE / 2
	sprite.scale = Vector2.ZERO
	reward_flowers.add_child(sprite)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(sprite, "scale", Vector2.ONE, REWARD_POP_DURATION)


func _trigger_crisis() -> void:
	house_tasks_modal.close()
	action_modal.close()
	crisis_modal.open_crisis(_todays_crises.pop_front(), actions_left > 0)


func _on_crisis_choice_made(crisis: Dictionary, intervened: bool) -> void:
	var outcome: Dictionary = crisis.intervene if intervened else crisis.ignore
	if intervened:
		actions_left -= 1
		_refresh_day_hud()

	var bars := {"water": water_bar, "food": food_bar, "energy": energy_bar, "nature": nature_bar}
	for key in outcome.effects:
		bars[key].value += outcome.effects[key]

	# Slowed water growth starts the day after the crisis; overlapping droughts keep the harsher factor.
	if outcome.has("water_growth"):
		for i in range(1, outcome.water_growth.days + 1):
			var day: int = current_day + i
			_water_growth_factors[day] = minf(_water_growth_factors.get(day, 1.0), outcome.water_growth.factor)


# Rewards wait until the crisis card is dismissed so the two modals don't stack.
func _on_crisis_resolved(crisis: Dictionary, intervened: bool) -> void:
	if intervened and crisis.intervene.has("reward_flower"):
		var flower := Rewards.find_flower(crisis.intervene.reward_flower)
		_plant_reward_flower(flower)
		reward_modal.open_reward(flower, crisis.intervene.reward_reason)
