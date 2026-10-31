class_name Rewards

const FLOWERS := [
	{"id": "potted_flower", "name": "Potted Flower", "texture": preload("res://assets/nature/potted_flower.png")},
	{"id": "wildflower_patch", "name": "Wildflower Patch", "texture": preload("res://assets/nature/wildflower_patch.png")},
	{"id": "yellow_shrub", "name": "Yellow Shrub", "texture": preload("res://assets/nature/yellow_shrub.png")},
]


static func random_flower() -> Dictionary:
	return FLOWERS.pick_random()


static func find_flower(flower_id: String) -> Dictionary:
	for flower in FLOWERS:
		if flower.id == flower_id:
			return flower
	return {}
