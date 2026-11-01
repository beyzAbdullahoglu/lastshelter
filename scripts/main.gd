extends Control

const PIN_BOB_HEIGHT := 6.0
const PIN_BOB_DURATION := 0.6
const FARM_GROWTH_TICK_DURATION := 1.0
const BASIC_IRRIGATION_WATER_COST := 14.0
const DRIP_IRRIGATION_WATER_COST := 8.0
const FARM_EMPTY_TEXTURE: Texture2D = preload("res://assets/agriculture/empty.png")
const FARM_GROWING_TEXTURE: Texture2D = preload("res://assets/agriculture/growing.png")
const FARM_WATERED_TEXTURE: Texture2D = preload("res://assets/agriculture/watered.png")
const POND_HEALTHY_TEXTURE: Texture2D = preload("res://assets/water/pond_healthy.png")
const POND_HALF_DRIED_TEXTURE: Texture2D = preload("res://assets/water/pond_half_dried.png")
const TREE_GROWING_TEXTURE: Texture2D = preload("res://assets/nature/tree_sapling.png")
const TREE_HEALTHY_TEXTURE: Texture2D = preload("res://assets/nature/tree_healthy.png")
const CRISIS_SOUND: AudioStream = preload("res://audio/crises_audio.wav")
const RESOURCE_GAIN_SOUND: AudioStream = preload("res://audio/resource_gain.wav")
const NEW_TREASURE_SOUND: AudioStream = preload("res://audio/new_treasure.wav")
const DAY_START_SOUND: AudioStream = preload("res://audio/day_start.wav")
const FLOWER_GAIN_SOUND: AudioStream = preload("res://audio/flower_gain.wav")
const REWARD_FLOWER_SIZE := Vector2(56, 56)
# Flowers line up parallel to the house's front (door) wall (2:1 isometric, running up-right);
# a full row continues in a new row one step further out from the wall (down-right).
const REWARD_FLOWERS_PER_ROW := 5
const REWARD_FLOWER_STEP := Vector2(34, -17)
const REWARD_ROW_STEP := Vector2(34, 17)
const REWARD_POP_DURATION := 0.35
const TREE_WATER_COST := 5.0
const TREE_NATURE_GAIN := 6.0
const MATURE_TREE_NATURE_GAIN := 4.0
const TREE_MATURITY_SECONDS := 10.0
const TREE_TILE_SCALE := 1.25
const TREE_GROWING_SCALE := 0.9
const TREE_VERTICAL_OFFSET := -12.0
const WATER_TANK_WATER := 6.0
const WELL_WATER_GAIN := 12.0
const WELL_NATURE_COST := 5.0
const FISH_FOOD_GAIN := 8.0
const FISH_NATURE_COST := 1.0
const POND_CLEAN_NATURE_GAIN := 7.0
const COMPOST_FOOD := 5.0
const COMPOST_NATURE := 6.0
const RECYCLING_NATURE_GAIN := 5.0
# Locked buildings are drawn faded with a lock badge; self_modulate keeps the badge opaque.
const LOCKED_TINT := Color(1, 1, 1, 0.4)
const SOLAR_PANEL_TEXTURE: Texture2D = preload("res://assets/energy/solar_panel_array.png")
const FOG_SPRITE_SHEET: Texture2D = preload("res://assets/effects/fog_sprite_sheet.png")
const POWER_PLANT_ENERGY_AMOUNT := 12.0
const SOLAR_PANEL_ENERGY_AMOUNT := 10.0
const POWER_PLANT_UPGRADE_ACTION_COST := 2
const POWER_PLANT_NATURE_COST := 5.0

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

@onready var character = $World/Character
@onready var interactive_objects: Control = $World/InteractiveObjects
@onready var world: Control = $World
@onready var ground: Node2D = $World/Ground
@onready var tree_plot_layer: TileMapLayer = $World/Ground/dirt
@onready var dirt_grass_layer: TileMapLayer = $World/Ground/dirtGrass
@onready var house_task_pin: Button = $World/InteractiveObjects/House/HouseTaskPin
@onready var house_tasks_modal = $HouseTasksModal
@onready var action_modal = $ActionModal
@onready var farm_action_modal = $FarmActionModal
@onready var tree_action_modal = $TreeActionModal
@onready var farm_button: TextureButton = $World/InteractiveObjects/Farm
@onready var farm_timer_label: Label = $World/InteractiveObjects/Farm/FarmTimer
@onready var pond_button: TextureButton = $World/InteractiveObjects/Pond
@onready var water_tank_button: TextureButton = $World/InteractiveObjects/WaterTank
@onready var water_tank_lock: Label = $World/InteractiveObjects/WaterTank/LockIcon
@onready var power_plant_button: TextureButton = $World/InteractiveObjects/PowerPlant
@onready var water_bar: ProgressBar = $HUD/TopPanel/Resources/WaterBox/WaterBar
@onready var food_bar: ProgressBar = $HUD/TopPanel/Resources/FoodBox/FoodBar
@onready var reward_modal = $RewardModal
@onready var crisis_modal = $CrisisModal
@onready var day_modal = $DayModal
@onready var reward_flowers: Control = $World/Decorations/RewardFlowers
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
var _water_tank_unlocked := false
var _well_used_today := false
var _composted_today := false
var _recycled_today := false
var _fished_today := false
var _pond_cleaned_today := false
var _power_plant_upgraded := false
var _energy_collected_today := false
var actions_left := MAX_ACTIONS
var _day_elapsed := 0.0
var hearts := MAX_HEARTS
# Freezes the day clock from 00:00 until the next day starts.
var _day_over := false
var _crisis_deck := CrisisDeck.new()
var _todays_crises: Array = []
# Day -> multiplier on that day's water growth (set by drought crises).
var _water_growth_factors := {}
var _tree_plot_markers: Dictionary = {}
var _tree_sprites: Dictionary = {}
var _planted_trees: Dictionary = {}
var _pending_tree_cell := Vector2i(-1, -1)
var _tree_planted_today := false
var _crisis_sound_player := AudioStreamPlayer.new()
var _resource_gain_sound_player := AudioStreamPlayer.new()
var _new_treasure_sound_player := AudioStreamPlayer.new()
var _day_start_sound_player := AudioStreamPlayer.new()
var _flower_gain_sound_player := AudioStreamPlayer.new()


func _ready() -> void:
	pond_button.texture_normal = POND_HEALTHY_TEXTURE
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
	tree_action_modal.confirmed.connect(_on_tree_action_confirmed)
	_create_tree_plot_markers()
	_reset_farm()
	_refresh_water_tank()
	crisis_modal.choice_made.connect(_on_crisis_choice_made)
	crisis_modal.resolved.connect(_on_crisis_resolved)
	_crisis_sound_player.stream = CRISIS_SOUND
	add_child(_crisis_sound_player)
	_resource_gain_sound_player.stream = RESOURCE_GAIN_SOUND
	add_child(_resource_gain_sound_player)
	_new_treasure_sound_player.stream = NEW_TREASURE_SOUND
	add_child(_new_treasure_sound_player)
	_day_start_sound_player.stream = DAY_START_SOUND
	add_child(_day_start_sound_player)
	_flower_gain_sound_player.stream = FLOWER_GAIN_SOUND
	add_child(_flower_gain_sound_player)
	_day_start_sound_player.play()
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
	if not _power_plant_upgraded:
		parts.append("Power plant: Nature -5")
	day_modal.open_message(
		"Day %d is starting" % current_day,
		"Resources are being renewed:\n%s" % "   ".join(parts),
		"Start day"
	)
	await day_modal.continued
	_day_over = false
	_day_start_sound_player.play()


# Applies the daily renewal for current_day; drought crises scale the water part.
func _renew_resources() -> Dictionary:
	var renewal := DAILY_RENEWAL.duplicate()
	if _water_tank_unlocked:
		renewal.water = WATER_TANK_WATER
	renewal.water *= _water_growth_factors.get(current_day, 1.0)
	_water_growth_factors.erase(current_day)
	var bars := _resource_bars()
	for key in renewal:
		bars[key].value += renewal[key]
	_apply_power_plant_nature_cost()
	return renewal


# The clock stays frozen (_day_over) until the scene reloads; all game state lives in this scene.
func _finish_game(title: String, body: String) -> void:
	day_modal.open_message(title, body, "Play again")
	await day_modal.continued
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# Health (hearts) is intentionally carried over between days.
func _start_next_day() -> void:
	_day_elapsed = 0.0
	current_day += 1
	pond_button.texture_normal = POND_HEALTHY_TEXTURE
	actions_left = MAX_ACTIONS
	_farm_irrigated_today = false
	_farm_harvested_today = false
	_well_used_today = false
	_composted_today = false
	_recycled_today = false
	_fished_today = false
	_pond_cleaned_today = false
	_tree_planted_today = false
	_energy_collected_today = false
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


func _on_tree_plot_marker_pressed(cell: Vector2i) -> void:
	var target := tree_plot_layer.to_global(tree_plot_layer.map_to_local(cell)) + Vector2(0, 40)
	character.move_to(target, _tree_plot_markers[cell])


func _create_tree_plot_markers() -> void:
	for cell in tree_plot_layer.get_used_cells():
		var marker := Button.new()
		marker.custom_minimum_size = Vector2(44, 44)
		marker.size = marker.custom_minimum_size
		marker.text = "＋"
		marker.add_theme_font_size_override("font_size", 22)
		marker.add_theme_stylebox_override("normal", _make_tree_marker_style())
		marker.add_theme_stylebox_override("hover", _make_tree_marker_style())
		marker.add_theme_stylebox_override("pressed", _make_tree_marker_style())
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.tooltip_text = "Tree planting plot"
		marker.set_meta("tree_plot_cell", cell)
		marker.pressed.connect(_on_tree_plot_marker_pressed.bind(cell))

		var world_position: Vector2 = world.get_global_transform().affine_inverse() * tree_plot_layer.to_global(tree_plot_layer.map_to_local(cell))
		marker.position = world_position - marker.size / 2.0
		world.add_child(marker)
		_tree_plot_markers[cell] = marker

		var tree_sprite := Sprite2D.new()
		tree_sprite.name = "Tree_%d_%d" % [cell.x, cell.y]
		tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree_sprite.centered = true
		tree_sprite.position = ground.to_local(tree_plot_layer.to_global(tree_plot_layer.map_to_local(cell))) + Vector2(0, TREE_VERTICAL_OFFSET)
		tree_sprite.visible = false
		ground.add_child(tree_sprite)
		_tree_sprites[cell] = tree_sprite


func _make_tree_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.28, 0.17, 0.9)
	style.border_color = Color(0.72, 0.84, 0.48, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	return style


func _open_tree_plot(cell: Vector2i) -> void:
	if _planted_trees.has(cell):
		tree_action_modal.open_action("", "A tree is already planted here.")
	elif _tree_planted_today:
		tree_action_modal.open_action("", "You can only plant one tree per day.")
	elif actions_left <= 0:
		tree_action_modal.open_action("", "No actions left today.")
	elif water_bar.value < TREE_WATER_COST:
		tree_action_modal.open_action(
			"",
			"Not enough water. Planting needs {water} %d." % int(TREE_WATER_COST)
		)
	else:
		_pending_tree_cell = cell
		tree_action_modal.open_action(
			"plant_tree",
			"Plant a tree?\n💰 Cost: 1 action + {water} %d\n{nature} +%d\n\n🌼 A little flower surprise!" % [
				int(TREE_WATER_COST),
				int(TREE_NATURE_GAIN),
			],
			"Plant a tree"
		)


func _on_tree_action_confirmed(action_id: String) -> void:
	if action_id != "plant_tree":
		return
	var cell := _pending_tree_cell
	_pending_tree_cell = Vector2i(-1, -1)
	if not _tree_plot_markers.has(cell) or _planted_trees.has(cell):
		return
	if _tree_planted_today:
		_open_tree_plot(cell)
		return
	if water_bar.value < TREE_WATER_COST or actions_left <= 0:
		_open_tree_plot(cell)
		return
	if not _try_spend_action():
		return

	_apply_resource_changes(-TREE_WATER_COST, 0, 0, TREE_NATURE_GAIN)
	_planted_trees[cell] = {"planted_day": current_day, "matured": false}
	_tree_planted_today = true
	_refresh_tree_plot_marker(cell)
	_grant_flower("plant_tree")
	_mature_tree_after_delay(cell)


func _mature_tree_after_delay(cell: Vector2i) -> void:
	await get_tree().create_timer(TREE_MATURITY_SECONDS).timeout
	if not is_inside_tree() or not _planted_trees.has(cell):
		return

	var tree: Dictionary = _planted_trees[cell]
	if tree.matured:
		return
	tree.matured = true
	_planted_trees[cell] = tree
	nature_bar.value += MATURE_TREE_NATURE_GAIN
	_refresh_tree_plot_marker(cell)


func _refresh_tree_plot_marker(cell: Vector2i) -> void:
	var marker: Button = _tree_plot_markers[cell]
	var tree_sprite: Sprite2D = _tree_sprites[cell]
	var tree: Dictionary = _planted_trees.get(cell, {})
	if tree.is_empty():
		marker.text = "＋"
		marker.add_theme_stylebox_override("normal", _make_tree_marker_style())
		marker.add_theme_stylebox_override("hover", _make_tree_marker_style())
		marker.add_theme_stylebox_override("pressed", _make_tree_marker_style())
		tree_sprite.texture = null
		tree_sprite.hide()
		marker.tooltip_text = "Tree planting plot"
	elif tree.matured:
		marker.text = ""
		_set_tree_sprite_texture(tree_sprite, TREE_HEALTHY_TEXTURE)
		_hide_tree_plot_marker_style(marker)
		marker.tooltip_text = "Mature tree"
	else:
		marker.text = ""
		_set_tree_sprite_texture(tree_sprite, TREE_GROWING_TEXTURE)
		tree_sprite.scale *= TREE_GROWING_SCALE
		_hide_tree_plot_marker_style(marker)
		marker.tooltip_text = "Growing tree"


func _set_tree_sprite_texture(tree_sprite: Sprite2D, texture: Texture2D) -> void:
	tree_sprite.texture = texture
	var tile_size := Vector2(tree_plot_layer.tile_set.tile_size)
	var texture_size := Vector2(texture.get_size())
	var fit_scale := minf(tile_size.x / texture_size.x, tile_size.y / texture_size.y)
	tree_sprite.scale = Vector2.ONE * fit_scale * TREE_TILE_SCALE
	tree_sprite.offset = Vector2.ZERO
	tree_sprite.show()


func _hide_tree_plot_marker_style(marker: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	marker.add_theme_stylebox_override("normal", empty_style)
	marker.add_theme_stylebox_override("hover", empty_style)
	marker.add_theme_stylebox_override("pressed", empty_style)


func _on_action_modal_confirmed(task_id: String) -> void:
	match task_id:
		"unlock_water_tank":
			_unlock_water_tank()
		"collect_water":
			_collect_water_from_well()
		"make_compost":
			_make_compost()
		"recycle":
			_recycle()
		"fish":
			_fish()
		"clean_pond":
			_clean_pond()
		"power_collect_energy":
			_collect_power_energy()
		"power_improve":
			_confirm_power_plant_upgrade()
		"power_confirm_upgrade":
			_improve_power_plant()
		_:
			if not house_tasks_modal.is_completed(task_id) and _try_spend_action():
				house_tasks_modal.complete_task(task_id)


func _on_object_pressed(button: Control) -> void:
	# Stand at the bottom-center of the object ("in front" of it).
	var rect := button.get_global_rect()
	var target := Vector2(rect.get_center().x, rect.end.y)
	if button.has_meta("approach_offset"):
		target += button.get_meta("approach_offset")
	character.move_to(target, button)


func _on_character_arrived(target: Node) -> void:
	if target != null and target.has_meta("tree_plot_cell"):
		_open_tree_plot(target.get_meta("tree_plot_cell"))
		return
	if target != null and target.name == "Farm":
		_open_farm_options()
		return
	if target != null and target.name == "WaterTank":
		_open_water_tank()
		return
	if target != null and target.name == "WaterWell":
		_open_water_well()
		return
	if target != null and target.name == "Compost":
		_open_compost()
		return
	if target == power_plant_button:
		_open_power_plant_options()
		return
	if target != null and target.name == "RecyclingBin":
		_open_recycling()
		return
	if target != null and target.name == "Pond":
		_open_pond_options()


# Unlocking costs one action and raises daily water renewal from +2 to +6 on later days.
func _open_water_tank() -> void:
	house_tasks_modal.close()
	if not _water_tank_unlocked:
		if actions_left <= 0:
			action_modal.open_action("", "Blue Water Tank\nUnlock requires 1 action.\nNo actions left today.")
		else:
			action_modal.open_action(
				"unlock_water_tank",
				"Blue Water Tank\nActivate rainwater collection.\nDaily {water} renewal increases from +%d to +%d starting next day.\n💰 Cost: 1 action." % [
					int(DAILY_RENEWAL.water),
					int(WATER_TANK_WATER),
				],
				"Unlock"
			)
	else:
		action_modal.open_action(
			"",
			"Blue Water Tank\nRainwater collection is active.\nDaily {water} renewal: +%d." % int(WATER_TANK_WATER)
		)


func _unlock_water_tank() -> void:
	if _water_tank_unlocked or not _try_spend_action():
		return
	_water_tank_unlocked = true
	_refresh_water_tank()
	_new_treasure_sound_player.play()


func _open_water_well() -> void:
	house_tasks_modal.close()
	if _well_used_today:
		action_modal.open_action("", "You have already collected water from the well today.")
		return
	if actions_left <= 0:
		action_modal.open_action("", "No actions left today.")
		return
	var tank_tip := (
		"\n\n💡 Unlock the water tank to increase daily {water} renewal from +%d to +%d."
		% [int(DAILY_RENEWAL.water), int(WATER_TANK_WATER)]
		if not _water_tank_unlocked
		else "\n\nYour water tank increases daily {water} renewal from +%d to +%d."
			% [int(DAILY_RENEWAL.water), int(WATER_TANK_WATER)]
	)
	action_modal.open_action(
		"collect_water",
		"Collect water from the well.\n{water} +%d\n{nature} -%d\n💰 Cost: 1 action.%s" % [
			int(WELL_WATER_GAIN),
			int(WELL_NATURE_COST),
			tank_tip,
		],
		"Collect"
	)


func _collect_water_from_well() -> void:
	if _well_used_today or not _try_spend_action():
		return
	_well_used_today = true
	_apply_resource_changes(WELL_WATER_GAIN, 0, 0, -WELL_NATURE_COST)
	_resource_gain_sound_player.play()
	if not house_tasks_modal.is_completed("water"):
		house_tasks_modal.complete_task("water")


func _refresh_water_tank() -> void:
	water_tank_button.self_modulate = Color.WHITE if _water_tank_unlocked else LOCKED_TINT
	water_tank_lock.visible = not _water_tank_unlocked


func _open_compost() -> void:
	house_tasks_modal.close()
	if _composted_today:
		action_modal.open_action("", "Compost\nYou have already made compost today.")
	elif actions_left <= 0:
		action_modal.open_action("", "Compost\nNo actions left today.")
	else:
		action_modal.open_action(
			"make_compost",
			"Compost\nSeparate the waste and turn it into compost.\n\n💰 Cost: 1 action\nGain: {food} +%d, {nature} +%d and a flower" % [COMPOST_FOOD, COMPOST_NATURE],
			"Make compost"
		)


func _make_compost() -> void:
	if _composted_today or not _try_spend_action():
		return
	_composted_today = true
	_apply_resource_changes(0, COMPOST_FOOD, 0, COMPOST_NATURE)
	var flower := Rewards.random_flower()
	_plant_reward_flower(flower)
	reward_modal.open_reward(flower, "you turned your waste into compost")


func _open_recycling() -> void:
	house_tasks_modal.close()
	if _recycled_today:
		action_modal.open_action("", "You have already recycled today.")
	elif actions_left <= 0:
		action_modal.open_action("", "No actions left today.")
	else:
		action_modal.open_action(
			"recycle",
			"Recycle your garbage.\n\n💰 Cost: 1 action\n{nature} +%d\n\n🌼 A little flower surprise!" % int(RECYCLING_NATURE_GAIN),
			"Recycle"
		)


func _recycle() -> void:
	if _recycled_today or not _try_spend_action():
		return
	_recycled_today = true
	_apply_resource_changes(0, 0, 0, RECYCLING_NATURE_GAIN)
	_grant_flower("recycling")


func _open_pond_options() -> void:
	house_tasks_modal.close()
	if _fished_today and _pond_cleaned_today:
		action_modal.open_action("", "You have already fished and cleaned the pond today.")
		return
	if actions_left <= 0:
		action_modal.open_action("", "No actions left today.")
		return

	var fish_description := "Fish: {food} +%d, {nature} -%d." % [
		int(FISH_FOOD_GAIN),
		int(FISH_NATURE_COST),
	]
	var clean_description := "Clean the pond: {nature} +%d, earn 1 flower." % int(POND_CLEAN_NATURE_GAIN)
	if _fished_today:
		action_modal.open_action(
			"clean_pond",
			"%s\n💰 Cost: 1 action." % clean_description,
			"Clean pond"
		)
	elif _pond_cleaned_today:
		action_modal.open_action(
			"fish",
			"%s\n💰 Cost: 1 action." % fish_description,
			"Fish"
		)
	else:
		action_modal.open_choices(
			"Choose a pond action.\n%s\n%s\n💰 Each costs 1 action and can be done once per day." % [
				fish_description,
				clean_description,
			],
			"fish",
			"Fish",
			"clean_pond",
			"Clean pond"
		)


func _fish() -> void:
	if _fished_today or not _try_spend_action():
		return
	_fished_today = true
	_apply_resource_changes(0, FISH_FOOD_GAIN, 0, -FISH_NATURE_COST)
	_resource_gain_sound_player.play()
	house_tasks_modal.complete_task("food")


func _clean_pond() -> void:
	if _pond_cleaned_today or not _try_spend_action():
		return
	_pond_cleaned_today = true
	_apply_resource_changes(0, 0, 0, POND_CLEAN_NATURE_GAIN)
	var flower := Rewards.random_flower()
	_plant_reward_flower(flower)
	reward_modal.open_reward(flower, "you cleaned the pond")


func _open_power_plant_options() -> void:
	var energy_amount := SOLAR_PANEL_ENERGY_AMOUNT if _power_plant_upgraded else POWER_PLANT_ENERGY_AMOUNT
	if _energy_collected_today:
		if not _power_plant_upgraded and actions_left >= POWER_PLANT_UPGRADE_ACTION_COST:
			action_modal.open_action("power_improve", "Energy is already collected today.", "🍃 Improve")
		elif not _power_plant_upgraded:
			action_modal.open_action("", "Energy is already collected today. Switching to solar requires 2 actions 💪.")
		else:
			action_modal.open_action("", "Energy is already collected today.")
		return
	if actions_left <= 0:
		action_modal.open_action("", "No actions left today.")
		return
	if _power_plant_upgraded:
		action_modal.open_action("power_collect_energy", "Collect energy (%d units)" % int(energy_amount), "Collect")
	elif actions_left < POWER_PLANT_UPGRADE_ACTION_COST:
		action_modal.open_action("power_collect_energy", "Collect energy (%d units)" % int(energy_amount), "Collect")
	else:
		action_modal.open_choices(
			"Choose an action",
			"power_collect_energy",
			"Collect energy (%d units)" % int(energy_amount),
			"power_improve",
			"🍃 Improve"
		)


func _power_plant_upgrade_prompt() -> String:
	return "Switch to solar power?\n💰 Cost: 2 actions 💪\n{energy}: 10 units"


func _confirm_power_plant_upgrade() -> void:
	if _power_plant_upgraded:
		return
	if actions_left < POWER_PLANT_UPGRADE_ACTION_COST:
		action_modal.open_action("", "Switching to solar power requires 2 actions 💪.")
		return
	action_modal.open_action("power_confirm_upgrade", _power_plant_upgrade_prompt(), "OK")


func _collect_power_energy() -> void:
	if _energy_collected_today or not _try_spend_action():
		return
	_energy_collected_today = true
	energy_bar.value += SOLAR_PANEL_ENERGY_AMOUNT if _power_plant_upgraded else POWER_PLANT_ENERGY_AMOUNT
	_resource_gain_sound_player.play()
	if not house_tasks_modal.is_completed("energy"):
		house_tasks_modal.complete_task("energy")


func _improve_power_plant() -> void:
	if _power_plant_upgraded or actions_left < POWER_PLANT_UPGRADE_ACTION_COST:
		return
	actions_left -= POWER_PLANT_UPGRADE_ACTION_COST
	_refresh_day_hud()
	_power_plant_upgraded = true
	power_plant_button.texture_normal = SOLAR_PANEL_TEXTURE
	power_plant_button.texture_hover = SOLAR_PANEL_TEXTURE
	power_plant_button.texture_pressed = SOLAR_PANEL_TEXTURE
	_play_power_plant_construction_effect()
	_new_treasure_sound_player.play()
	action_modal.open_action(
		"",
		"Congratulations! Your shelter now runs on renewable solar power, helping protect the natural world."
	)


func _play_power_plant_construction_effect() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("construction")
	sprite_frames.set_animation_speed("construction", 8.0)
	sprite_frames.set_animation_loop("construction", false)
	var sheet_size := FOG_SPRITE_SHEET.get_size()
	var frame_width := sheet_size.x / 2.0
	for playback_index in 4:
		var frame_index := playback_index % 2
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = FOG_SPRITE_SHEET
		frame_texture.region = Rect2(frame_index * frame_width, 0.0, frame_width, sheet_size.y)
		sprite_frames.add_frame("construction", frame_texture)

	var smoke := AnimatedSprite2D.new()
	smoke.sprite_frames = sprite_frames
	smoke.animation = "construction"
	smoke.scale = Vector2(power_plant_button.size.x / frame_width, power_plant_button.size.y / sheet_size.y) * 2.0
	smoke.position = power_plant_button.position + power_plant_button.size / 2.0
	smoke.animation_finished.connect(smoke.queue_free)
	var plant_index := power_plant_button.get_index()
	interactive_objects.add_child(smoke)
	interactive_objects.move_child(smoke, plant_index + 1)
	smoke.play()


func _apply_power_plant_nature_cost() -> void:
	if not _power_plant_upgraded:
		nature_bar.value -= POWER_PLANT_NATURE_COST


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
			"Choose a harvest method.\nBasic: {food} +19, {energy} -4, {nature} -3.\nEco: {food} +14, {energy} -3, {nature} +2.",
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
				"Not enough {water} for basic irrigation. Drip irrigation needs 8 units.",
				"Drip irrigation"
			)
			return
		farm_action_modal.open_choices(
			"Choose a planting and watering method.\nBasic: {water} -%d, {energy} -3, {nature} -3; ready in 8 sec.\nDrip: {water} -%d, {energy} -2, {nature} -1; ready in 15 sec." % [
				int(BASIC_IRRIGATION_WATER_COST),
				int(DRIP_IRRIGATION_WATER_COST),
			],
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
			_apply_resource_changes(-BASIC_IRRIGATION_WATER_COST, 0, -3, -3)
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
			_apply_resource_changes(0, 19, -4, -3)
			_resource_gain_sound_player.play()
			_farm_harvested_today = true
			_reset_farm()
			house_tasks_modal.complete_task("food")
		"harvest_careful":
			if not _farm_is_ready or _farm_harvested_today or not _try_spend_action():
				return
			_apply_resource_changes(0, 14, -3, 2)
			_resource_gain_sound_player.play()
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
		"Not enough {water}. This irrigation method needs %d units." % int(required_water)
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
	if is_special:
		_grant_flower(task_id)
	print("Task completed: %s (special: %s)" % [task_id, is_special])


func _grant_flower(task_id: String) -> void:
	var task := DayTasks.find_special_task(current_day, task_id)
	var flower := Rewards.random_flower()
	_plant_reward_flower(flower)
	var reason: String = task.get("reward_reason", "")
	if reason.is_empty():
		match task_id:
			"plant_tree":
				reason = "you planted a tree"
			"recycling":
				reason = "you recycled your waste"
			_:
				reason = "you completed a special task"
	reward_modal.open_reward(flower, reason)


# Adds the flower to the patch in front of the house with a small pop-in.
func _plant_reward_flower(flower: Dictionary) -> void:
	var sprite := TextureRect.new()
	sprite.texture = flower.texture
	sprite.custom_minimum_size = REWARD_FLOWER_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = REWARD_FLOWER_SIZE
	var index := reward_flowers.get_child_count()
	sprite.position = REWARD_FLOWER_STEP * (index % REWARD_FLOWERS_PER_ROW) \
		+ REWARD_ROW_STEP * floori(float(index) / REWARD_FLOWERS_PER_ROW)
	sprite.pivot_offset = REWARD_FLOWER_SIZE / 2
	sprite.scale = Vector2.ZERO
	reward_flowers.add_child(sprite)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(sprite, "scale", Vector2.ONE, REWARD_POP_DURATION)
	_flower_gain_sound_player.play()


func _trigger_crisis() -> void:
	house_tasks_modal.close()
	action_modal.close()
	crisis_modal.open_crisis(_todays_crises.pop_front(), actions_left > 0)
	_crisis_sound_player.play()


func _on_crisis_choice_made(crisis: Dictionary, intervened: bool) -> void:
	if crisis.id == "drought":
		pond_button.texture_normal = POND_HALF_DRIED_TEXTURE

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
