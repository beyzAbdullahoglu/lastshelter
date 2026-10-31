class_name DayTasks

const MAIN_TASK_REQUIRED := 12

const MAIN_TASKS := [
	{"id": "water", "text": "Provide water for the house.", "hint": "Go to the water well and collect water."},
	{"id": "food", "text": "Provide food for the house.", "hint": "Go to the field and harvest goods."},
	{"id": "energy", "text": "Provide energy for the house.", "hint": "Go to the solar panel and get energy."},
]

const SPECIAL_TASKS_BY_DAY := {
	1: [
		{"id": "plant_tree", "text": "Plant a tree", "hint": "Go to the forest and plant a tree.", "reward_reason": "you planted 1 tree"},
		{"id": "recycling", "text": "Use recycling", "hint": "Take the waste to the recycling bins and sort it.", "reward_reason": "you used recycling 1 time"},
		{"id": "water_leak", "text": "Fix the water leak in the house", "hint": "Go to the house and repair the leaking pipe.", "reward_reason": "you fixed the water leak in the house"},
	],
}


static func get_special_tasks(day: int) -> Array:
	return SPECIAL_TASKS_BY_DAY.get(day, [])


static func find_special_task(day: int, task_id: String) -> Dictionary:
	for task in get_special_tasks(day):
		if task.id == task_id:
			return task
	return {}
