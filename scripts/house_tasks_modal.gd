extends Control

signal task_completed(task_id: String, is_special: bool)
signal all_tasks_completed

const TICK_COLOR := Color(0.18, 0.6, 0.25)
const ACTION_SLOT_WIDTH := 110.0

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var main_task_list: VBoxContainer = %MainTaskList
@onready var special_task_list: VBoxContainer = %SpecialTaskList

var _day := -1
var _completed := {}
var _labels := {}


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)
	panel.resized.connect(_place_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(day: int) -> void:
	if day != _day:
		_day = day
		_completed.clear()
		_rebuild()
	title_label.text = "House Needs — Day %d" % day
	show()


func close() -> void:
	hide()


# Centers the close button on the panel's top-right corner so it overflows it.
func _place_close_button() -> void:
	close_button.position = panel.position + Vector2(panel.size.x, 0) - close_button.size / 2


func _rebuild() -> void:
	_labels.clear()
	for list in [main_task_list, special_task_list]:
		for child in list.get_children():
			child.queue_free()

	for i in DayTasks.MAIN_TASKS.size():
		main_task_list.add_child(_build_row(DayTasks.MAIN_TASKS[i], false, i + 1))
	for task in DayTasks.get_special_tasks(_day):
		special_task_list.add_child(_build_row(task, true))


func _build_row(task: Dictionary, is_special: bool, number := 0) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	_labels[task.id] = {"label": label, "task": task, "special": is_special, "number": number}
	_refresh_label(task.id)

	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(ACTION_SLOT_WIDTH, 0)
	row.add_child(slot)

	if _completed.has(task.id):
		slot.add_child(_make_tick())
	else:
		var button := Button.new()
		button.text = "Complete"
		button.pressed.connect(_on_complete_pressed.bind(task.id, is_special, button))
		slot.add_child(button)

	return row


func _refresh_label(task_id: String) -> void:
	var entry: Dictionary = _labels[task_id]
	if entry.special:
		var bullet := "●" if _completed.has(task_id) else "○"
		entry.label.text = "%s %s" % [bullet, entry.task.text]
	else:
		var progress := DayTasks.MAIN_TASK_REQUIRED if _completed.has(task_id) else 0
		entry.label.text = "%d. %s (%d/%d)" % [entry.number, entry.task.text, progress, DayTasks.MAIN_TASK_REQUIRED]


func _make_tick() -> Label:
	var tick := Label.new()
	tick.text = "✓"
	tick.add_theme_color_override("font_color", TICK_COLOR)
	tick.add_theme_font_size_override("font_size", 22)
	return tick


func _on_complete_pressed(task_id: String, is_special: bool, button: Button) -> void:
	if _completed.has(task_id):
		return
	_completed[task_id] = true

	var slot := button.get_parent()
	button.queue_free()
	slot.add_child(_make_tick())
	_refresh_label(task_id)

	task_completed.emit(task_id, is_special)
	if _completed.size() == _labels.size():
		all_tasks_completed.emit()
