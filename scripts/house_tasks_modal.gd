extends ModalBase

signal task_completed(task_id: String, is_special: bool)
signal all_tasks_completed

const DONE_ICON := "✓"
const DONE_COLOR := Color(0.18, 0.6, 0.25)
const PENDING_ICON := "✗"
const PENDING_COLOR := Color(0.85, 0.2, 0.18)
const STATUS_SLOT_WIDTH := 32.0
const INFO_ICON_SIZE := Vector2(22, 22)

@onready var title_label: Label = %TitleLabel
@onready var main_task_list: VBoxContainer = %MainTaskList

var _day := -1
var _completed := {}
var _labels := {}


# Resets completion state and rebuilds the task list for the given day.
func set_day(day: int) -> void:
	if day == _day:
		return
	_day = day
	_completed.clear()
	title_label.text = "House Needs — Day %d" % day
	_rebuild()


func is_completed(task_id: String) -> bool:
	return _completed.has(task_id)


# Called by gameplay once the player has done what the task's hint describes.
func complete_task(task_id: String) -> void:
	if not _labels.has(task_id) or _completed.has(task_id):
		return
	_completed[task_id] = true
	_refresh_row(task_id)

	task_completed.emit(task_id, _labels[task_id].special)
	if _completed.size() == _labels.size():
		all_tasks_completed.emit()


func _rebuild() -> void:
	_labels.clear()
	for child in main_task_list.get_children():
		child.queue_free()

	for i in DayTasks.MAIN_TASKS.size():
		main_task_list.add_child(_build_row(DayTasks.MAIN_TASKS[i], false, i + 1))


func _build_row(task: Dictionary, is_special: bool, number := 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var status := Label.new()
	status.custom_minimum_size = Vector2(STATUS_SLOT_WIDTH, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	row.add_child(status)

	row.add_child(_make_info_icon(task.hint))

	_labels[task.id] = {"label": label, "status": status, "task": task, "special": is_special, "number": number}
	_refresh_row(task.id)
	return row


func _make_info_icon(hint: String) -> Label:
	var info := Label.new()
	info.text = "i"
	info.custom_minimum_size = INFO_ICON_SIZE
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.theme_type_variation = &"InfoIcon"
	# Labels ignore the mouse by default; tooltips need it.
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.mouse_default_cursor_shape = Control.CURSOR_HELP
	info.tooltip_text = hint
	return info


func _refresh_row(task_id: String) -> void:
	var entry: Dictionary = _labels[task_id]
	var done := _completed.has(task_id)

	if entry.special:
		entry.label.text = "%s %s" % ["●" if done else "○", entry.task.text]
	else:
		var required: int = entry.task.get("required", DayTasks.MAIN_TASK_REQUIRED)
		var progress := required if done else 0
		entry.label.text = "%d. %s (%d/%d)" % [entry.number, entry.task.text, progress, required]

	entry.status.text = DONE_ICON if done else PENDING_ICON
	entry.status.add_theme_color_override("font_color", DONE_COLOR if done else PENDING_COLOR)
