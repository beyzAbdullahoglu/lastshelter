extends Control

const PIN_BOB_HEIGHT := 6.0
const PIN_BOB_DURATION := 0.6
const FARM_GROWTH_TICK_DURATION := 1.0
const BASIC_IRRIGATION_WATER_COST := 18.0
const DRIP_IRRIGATION_WATER_COST := 8.0
const FARM_EMPTY_TEXTURE: Texture2D = preload("res://assets/agriculture/empty.png")
const FARM_GROWING_TEXTURE: Texture2D = preload("res://assets/agriculture/growing.png")
const FARM_WATERED_TEXTURE: Texture2D = preload("res://assets/agriculture/watered.png")
const REWARD_FLOWER_SIZE := Vector2(44, 44)
const REWARD_POP_DURATION := 0.35

const TOTAL_DAYS := 6
const DAY_DURATION := 90.0
const MAX_ACTIONS := 5
const MAX_HEARTS := 3
const FULL_HEART := "♥️"
const EMPTY_HEART := "🖤"
# A day fails if any resource ends below its baseline.
const RESOURCE_BASELINES := {"water": 35.0, "food": 30.0, "energy": 30.0, "nature": 40.0}
# Added at the start of every day after the first.
const DAILY_RENEWAL := {"water": 2.0, "food": 1.0, "energy": 1.0, "nature": 1.0}
# Seconds into the day at which each daily crisis appears (one human, one natural).
const CRISIS_TIMES := [20.0, 60.0]

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
@onready var day_modal = $DayModal
@onready var reward_flowers: HFlowContainer = $World/Decorations/RewardFlowers
@onready var energy_bar: ProgressBar = $HUD/TopPanel/Resources/EnergyBox/EnergyBar
@onready var nature_bar: ProgressBar = $HUD/TopPanel/Resources/NatureBox/NatureBar
@onready var day_label: Label = $HUD/BottomPanel/MarginContainer/MainRow/DayBox/VBox/DayLabel
@onready var action_label: Label = $HUD/BottomPanel/MarginContainer/MainRow/ActionBox/VBox/ActionLabel
@onready var day_timer_label: Label = $HUD/DayTimerLabel
@onready var health_label: Label = $HUD/BottomPanel/MarginContainer/MainRow/HealthBox/VBox/HealthLabel

var current_day := 1
var _farm_is_planted := false
var _farm_is_ready := false
var _farm_irrigated_today := false
var _farm_harvested_today := false
var _farm_growth_generation := 0
var actions_left := MAX_ACTIONS
var _day_elapsed := 0.0
var hearts := MAX_HEARTS
# Freezes the day clock from 00:00 until the next day starts.
var _day_over := false
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
	action_modal.confirmed.connect(_on_action_modal_confirmed)
	farm_action_modal.confirmed.connect(_on_farm_option_selected)
	_reset_farm()
	crisis_modal.choice_made.connect(_on_crisis_choice_made)
	crisis_modal.resolved.connect(_on_crisis_resolved)
	_todays_crises = _crisis_deck.draw_day()
	_start_pin_bob()
	_refresh_day_hud()
	_refresh_health()


func _process(delta: float) -> void:
	# The day clock is frozen while a crisis card is waiting for the player or the day is being evaluated.
	if crisis_modal.visible or _day_over:
		return
	_day_elapsed += delta
	var crisis_index := CRISIS_TIMES.size() - _todays_crises.size()
	if not _todays_crises.is_empty() and _day_elapsed >= CRISIS_TIMES[crisis_index]:
		_trigger_crisis()
		return
	if _day_elapsed >= DAY_DURATION:
		_end_day()
		return
	_refresh_day_timer()


# Counts down from DAY_DURATION (01:30); ceil keeps 01:30 visible for the first second.
func _refresh_day_timer() -> void:
	var remaining := ceili(maxf(DAY_DURATION - _day_elapsed, 0.0))
	day_timer_label.text = "%02d:%02d" % [floori(remaining / 60.0), remaining % 60]


func _end_day() -> void:
	_day_over = true
	_day_elapsed = DAY_DURATION
	_refresh_day_timer()
	house_tasks_modal.close()
	action_modal.close()
	farm_action_modal.close()
	reward_modal.close()

	day_modal.open_message("End of day!", "Resources and tasks are being checked...", "See results")
	await day_modal.continued

	var tasks_ok := _all_main_tasks_completed()
	var low_resources := _resources_below_baseline()
	var failed := not tasks_ok or not low_resources.is_empty()
	# At most one heart is lost per day, no matter how many criteria fail.
	if failed:
		hearts -= 1
		_refresh_health()
	day_modal.open_message("Day %d results" % current_day, _format_day_report(failed), "Continue")
	await day_modal.continued

	if hearts <= 0:
		_finish_game("Game over", "You ran out of hearts.")
	elif current_day >= TOTAL_DAYS:
		_finish_game("You survived!", "You made it through all %d days." % TOTAL_DAYS)
	else:
		_begin_next_day()


func _all_main_tasks_completed() -> bool:
	for task in DayTasks.MAIN_TASKS:
		if not house_tasks_modal.is_completed(task.id):
			return false
	return true


func _resources_below_baseline() -> Array[String]:
	var low: Array[String] = []
	var bars := _resource_bars()
	for key in RESOURCE_BASELINES:
		if bars[key].value < RESOURCE_BASELINES[key]:
			low.append(key)
	return low


func _format_day_report(failed: bool) -> String:
	var lines := PackedStringArray(["Tasks:"])
	for task in DayTasks.MAIN_TASKS:
		lines.append("%s %s" % [_check_mark(house_tasks_modal.is_completed(task.id)), task.id.capitalize()])
	lines.append("")
	lines.append("Resources:")
	var bars := _resource_bars()
	for key in RESOURCE_BASELINES:
		var value: float = bars[key].value
		lines.append("%s %s %d / %d" % [_check_mark(value >= RESOURCE_BASELINES[key]), key.capitalize(), value, RESOURCE_BASELINES[key]])
	lines.append("")
	if failed:
		lines.append("You lost a heart (%d left)." % hearts)
	else:
		lines.append("The day was a success!")
	return "\n".join(lines)


static func _check_mark(ok: bool) -> String:
	return "✓" if ok else "✗"


func _begin_next_day() -> void:
	_start_next_day()
	var renewal := _renew_resources()
	var parts := PackedStringArray()
	for key in renewal:
		parts.append("%s +%s" % [key.capitalize(), String.num(renewal[key])])
	day_modal.open_message(
		"Day %d is starting" % current_day,
		"Resources are being renewed:\n%s" % "   ".join(parts),
		"Start day"
	)
	await day_modal.continued
	_day_over = false


# Applies the daily renewal for current_day; drought crises scale the water part.
func _renew_resources() -> Dictionary:
	var renewal := DAILY_RENEWAL.duplicate()
	renewal.water *= _water_growth_factors.get(current_day, 1.0)
	_water_growth_factors.erase(current_day)
	var bars := _resource_bars()
	for key in renewal:
		bars[key].value += renewal[key]
	return renewal


# The clock stays frozen (_day_over) until the scene reloads; all game state lives in this scene.
func _finish_game(title: String, body: String) -> void:
	day_modal.open_message(title, body, "Play again")
	await day_modal.continued
	get_tree().reload_current_scene()


# Health (hearts) is intentionally carried over between days.
func _start_next_day() -> void:
	_day_elapsed = 0.0
	current_day += 1
	actions_left = MAX_ACTIONS
	_farm_irrigated_today = false
	_farm_harvested_today = false
	_todays_crises = _crisis_deck.draw_day()
	house_tasks_modal.set_day(current_day)
	house_task_pin.show()
	_refresh_day_hud()


func _refresh_day_hud() -> void:
	day_label.text = "DAY %02d / %02d" % [current_day, TOTAL_DAYS]
	action_label.text = "%d / %d" % [actions_left, MAX_ACTIONS]


func _refresh_health() -> void:
	var icons := PackedStringArray()
	for i in MAX_HEARTS:
		icons.append(FULL_HEART if i < hearts else EMPTY_HEART)
	health_label.text = " ".join(icons)


func _resource_bars() -> Dictionary:
	return {"water": water_bar, "food": food_bar, "energy": energy_bar, "nature": nature_bar}


func _try_spend_action() -> bool:
	if actions_left <= 0:
		return false
	actions_left -= 1
	_refresh_day_hud()
	return true


func _on_action_modal_confirmed(task_id: String) -> void:
	if house_tasks_modal.is_completed(task_id) or not _try_spend_action():
		return
	house_tasks_modal.complete_task(task_id)


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
	elif actions_left <= 0:
		action_modal.open_action(action.task, "No actions left today.")
	else:
		action_modal.open_action(action.task, action.message.format({"units": DayTasks.MAIN_TASK_REQUIRED}), action.button)


func _open_farm_options() -> void:
	if actions_left <= 0:
		farm_action_modal.open_action("", "No actions left today.")
		return
	if _farm_is_planted:
		if not _farm_is_ready:
			return
		if _farm_harvested_today:
			farm_action_modal.open_action("", "You have already harvested today.")
			return
		farm_action_modal.open_choices(
			"Choose a harvest method",
			"harvest_standard",
			"Basic harvest",
			"harvest_careful",
			"Eco harvest"
		)
	else:
		if _farm_irrigated_today:
			farm_action_modal.open_action("", "You have already irrigated today.")
			return
		if water_bar.value < DRIP_IRRIGATION_WATER_COST:
			_show_insufficient_farm_water(DRIP_IRRIGATION_WATER_COST)
			return
		if water_bar.value < BASIC_IRRIGATION_WATER_COST:
			farm_action_modal.open_action(
				"plant_drip",
				"Not enough water for basic irrigation. Drip irrigation needs 8 units.",
				"Drip irrigation"
			)
			return
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
			if _farm_is_planted or _farm_irrigated_today:
				return
			if water_bar.value < BASIC_IRRIGATION_WATER_COST:
				_show_insufficient_farm_water(BASIC_IRRIGATION_WATER_COST)
				return
			if not _try_spend_action():
				return
			_apply_resource_changes(-18, 0, -3, -5)
			_start_farm_growth(8)
		"plant_drip":
			if _farm_is_planted or _farm_irrigated_today:
				return
			if water_bar.value < DRIP_IRRIGATION_WATER_COST:
				_show_insufficient_farm_water(DRIP_IRRIGATION_WATER_COST)
				return
			if not _try_spend_action():
				return
			_apply_resource_changes(-8, 0, -2, -1)
			_start_farm_growth(15)
		"harvest_standard":
			if not _farm_is_ready or _farm_harvested_today or not _try_spend_action():
				return
			_apply_resource_changes(0, 20, -5, -7)
			_farm_harvested_today = true
			_reset_farm()
			house_tasks_modal.complete_task("food")
		"harvest_careful":
			if not _farm_is_ready or _farm_harvested_today or not _try_spend_action():
				return
			_apply_resource_changes(0, 17, -2, 3)
			_farm_harvested_today = true
			_reset_farm()
			house_tasks_modal.complete_task("food")


func _apply_resource_changes(water: float, food: float, energy: float, nature: float) -> void:
	water_bar.value += water
	food_bar.value += food
	energy_bar.value += energy
	nature_bar.value += nature


func _show_insufficient_farm_water(required_water: float) -> void:
	farm_action_modal.open_action(
		"",
		"Not enough water. This irrigation method needs %d units." % int(required_water)
	)


func _start_farm_growth(duration_seconds: int) -> void:
	_farm_growth_generation += 1
	_farm_is_planted = true
	_farm_is_ready = false
	_farm_irrigated_today = true
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
		if not _try_spend_action():
			return

	var bars := _resource_bars()
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
