class_name DayTasks

const MAIN_TASK_REQUIRED := 12

const MAIN_TASKS := [
	{"id": "water", "text": "Provide water for the house."},
	{"id": "food", "text": "Provide food for the house."},
	{"id": "energy", "text": "Provide energy for the house."},
]

const SPECIAL_TASKS_BY_DAY := {
	1: [
		{"id": "plant_tree", "text": "Plant a tree"},
		{"id": "recycling", "text": "Use recycling"},
		{"id": "water_leak", "text": "Fix the water leak in the house"},
	],
}


static func get_special_tasks(day: int) -> Array:
	return SPECIAL_TASKS_BY_DAY.get(day, [])
