extends Control

const PIN_BOB_HEIGHT := 6.0
const PIN_BOB_DURATION := 0.6

@onready var character = $World/Character
@onready var interactive_objects: Control = $World/InteractiveObjects
@onready var house_task_pin: Button = $World/InteractiveObjects/House/HouseTaskPin
@onready var house_tasks_modal = $HouseTasksModal

var current_day := 1


func _ready() -> void:
	for child in interactive_objects.get_children():
		if child is BaseButton:
			child.pressed.connect(_on_object_pressed.bind(child))
	character.arrived.connect(_on_character_arrived)

	house_task_pin.pressed.connect(func(): house_tasks_modal.open(current_day))
	house_tasks_modal.task_completed.connect(_on_house_task_completed)
	house_tasks_modal.all_tasks_completed.connect(house_task_pin.hide)
	_start_pin_bob()


func _on_object_pressed(button: Control) -> void:
	# Stand at the bottom-center of the object ("in front" of it).
	var rect := button.get_global_rect()
	var target := Vector2(rect.get_center().x, rect.end.y)
	if button.has_meta("approach_offset"):
		target += button.get_meta("approach_offset")
	character.move_to(target, button)


func _on_character_arrived(target: Node) -> void:
	if target:
		print(target.name)


func _start_pin_bob() -> void:
	var base_y := house_task_pin.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(house_task_pin, "position:y", base_y - PIN_BOB_HEIGHT, PIN_BOB_DURATION)
	tween.tween_property(house_task_pin, "position:y", base_y, PIN_BOB_DURATION)


func _on_house_task_completed(task_id: String, is_special: bool) -> void:
	# TODO: per-task effects to be specified.
	match task_id:
		"water", "food", "energy":
			pass
		"plant_tree", "recycling", "water_leak":
			pass
	print("Task completed: %s (special: %s)" % [task_id, is_special])
