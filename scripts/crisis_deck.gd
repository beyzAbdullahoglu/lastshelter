class_name CrisisDeck
extends RefCounted

const HUMAN := "human"
const NATURE := "nature"

const CATEGORY_NAMES := {HUMAN: "Human-Caused Crisis", NATURE: "Natural Disaster"}
const RESOURCE_NAMES := {"water": "Water", "food": "Food", "energy": "Energy", "nature": "Nature"}

# The demo has a single water bar, so "well", "household water" and "usable water
# reserves" all map to "water". Effects are deltas applied to the top-panel bars.
# Optional per-outcome "water_growth" scales the daily water growth for upcoming days;
# optional intervene "reward_flower" is a Rewards flower id granted on intervention.
const CRISES := [
	{
		"id": "factory_groundwater", "category": HUMAN,
		"title": "Excessive Groundwater Consumption by a Factory",
		"story": "A large nearby factory is extracting groundwater uncontrollably for its production activities. Local water reserves are rapidly declining. Your well is also supplied by this groundwater source.",
		"ignore": {"effects": {"water": -20, "nature": -5}},
		"intervene": {"text": "Submit an official request for an environmental inspection.", "effects": {"water": -8, "nature": -2}},
		"message": "Natural water resources are not unlimited. Uncontrolled industrial water consumption threatens not only our present but also the water security of future generations.",
	},
	{
		"id": "industrial_waste", "category": HUMAN,
		"title": "Industrial Waste Discharged into the Pond",
		"story": "A nearby manufacturing facility is releasing its wastewater into a natural water source without adequate treatment. The pond's ecosystem is being damaged, and the amount of usable water is decreasing.",
		"ignore": {"effects": {"water": -12, "nature": -12}},
		"intervene": {"text": "Report the waste discharge and start a cleanup operation around the pond.", "effects": {"water": -5, "nature": -5}},
		"message": "Protecting water resources is not just about using water efficiently. Preventing water pollution and managing waste properly are equally essential.",
	},
	{
		"id": "deforestation", "category": HUMAN,
		"title": "Unplanned Deforestation",
		"story": "A nearby forest area is being cleared for a new commercial project. As the number of trees decreases, the soil's ability to retain water and the ecosystem's resilience are reduced.",
		"ignore": {"effects": {"nature": -16, "water": -8}},
		"intervene": {"text": "Contact environmental organizations and the local government to request an investigation into the logging.", "effects": {"nature": -8, "water": -4}},
		"message": "Forests are more than just collections of trees. They are essential ecosystems that support the water cycle, soil health, and the survival of living organisms.",
	},
	{
		"id": "air_pollution", "category": HUMAN,
		"title": "Industrial Air Pollution",
		"story": "Industrial facilities in the region are releasing large amounts of emissions due to their heavy reliance on fossil fuels. Air quality is deteriorating, and an infrastructure dependent on industrial energy is being disrupted.",
		"ignore": {"effects": {"nature": -10, "energy": -8}},
		"intervene": {"text": "Request clean energy transition initiatives and stricter emission inspections.", "effects": {"nature": -5, "energy": -4}},
		"message": "Dependence on fossil fuels accelerates climate change. Transitioning to clean energy is essential for addressing the causes of the climate crisis.",
	},
	{
		"id": "plastic_waste", "category": HUMAN,
		"title": "Plastic and Packaging Waste Pollution",
		"story": "Waste management in a nearby residential area is inadequate. Plastic packaging, single-use products and other waste are carried by wind and rain into the pond area.",
		"ignore": {"effects": {"nature": -9, "water": -6}},
		"intervene": {"text": "Collect the waste and take it to a recycling facility.", "effects": {"nature": -3, "water": -2}, "reward_flower": "yellow_shrub", "reward_reason": "you cleaned up the plastic waste around the pond"},
		"message": "Recycling and proper waste management keep plastic out of our water and protect the ecosystems around us.",
	},
	{
		"id": "heatwave", "category": NATURE,
		"title": "Extreme Heatwave",
		"story": "The region is experiencing a prolonged period of extreme heat. Plants are rapidly losing water, crops are being damaged, and the household's cooling needs are increasing.",
		"ignore": {"effects": {"water": -8, "food": -6, "energy": -5, "nature": -8}},
		"intervene": {"text": "Install temporary shade structures, limit water use and protect the plants.", "effects": {"water": -4, "food": -3, "energy": -3, "nature": -4}},
		"message": "The effects of climate change are not limited to rising temperatures. Increasing temperatures also affect water resources, agricultural production, and the lives of living organisms.",
	},
	{
		"id": "drought", "category": NATURE,
		"title": "Prolonged Drought",
		"story": "There has been insufficient rainfall for an extended period. The water sources supplying the well are declining, the soil is drying out, and agricultural productivity is decreasing.",
		# Normal well regeneration is +12, drought regeneration is +4 -> 1/3 of normal.
		"ignore": {"effects": {"water": -20, "nature": -10}, "water_growth": {"factor": 1.0 / 3.0, "days": 2}},
		"intervene": {"text": "Limit water consumption, protect the soil with mulch and use efficient irrigation.", "effects": {"water": -10, "nature": -5}, "water_growth": {"factor": 1.0 / 3.0, "days": 1}},
		"message": "Collecting water alone is not enough to combat drought. Reducing water consumption and preserving soil moisture are equally important.",
	},
	{
		"id": "flash_flood", "category": NATURE,
		"title": "Flash Flood and Severe Storm",
		"story": "Heavy rainfall causes flash flooding in the region. Part of the farmland is submerged, the solar panels are damaged, and some stored food becomes unusable.",
		"ignore": {"effects": {"food": -10, "energy": -8, "nature": -5, "water": -5}},
		"intervene": {"text": "Use protective equipment to shield the food storage, solar panels and well cover.", "effects": {"food": -5, "energy": -4, "nature": -2, "water": -2}},
		"message": "Creating climate-resilient living environments can help reduce the damage caused by extreme weather events.",
	},
	{
		"id": "forest_fire", "category": NATURE,
		"title": "Forest Fire",
		"story": "Following a prolonged period of heat and drought, a fire breaks out in a nearby forest. Vegetation is damaged, air quality deteriorates, and your garden is put at risk.",
		"ignore": {"effects": {"nature": -18, "food": -6, "energy": -5}},
		"intervene": {"text": "Remove dry vegetation around the house and create a protective firebreak.", "effects": {"nature": -9, "food": -3, "energy": -2}},
		"message": "Healthy ecosystems and proper land management play an important role in reducing the risk of wildfires.",
	},
	{
		"id": "biodiversity_loss", "category": NATURE,
		"title": "Loss of Biodiversity",
		"story": "Natural habitats in the region are gradually disappearing. Bees, butterflies and other pollinators are declining, and the garden plants and field crops are suffering.",
		"ignore": {"effects": {"nature": -12, "food": -8}},
		"intervene": {"text": "Plant native flowering plants and create a habitat for local wildlife.", "effects": {"nature": -5, "food": -3}, "reward_flower": "wildflower_patch", "reward_reason": "you created a habitat for local wildlife"},
		"message": "Biodiversity supports the resilience of food systems and ecosystems.",
	},
]

# Shuffle bags per category: every crisis is seen once before any repeats.
var _bags := {HUMAN: [], NATURE: []}


# One human-caused and one natural crisis per day, in random order.
func draw_day() -> Array:
	var day := [_draw(HUMAN), _draw(NATURE)]
	day.shuffle()
	return day


func _draw(category: String) -> Dictionary:
	var bag: Array = _bags[category]
	if bag.is_empty():
		bag.assign(CRISES.filter(func(c): return c.category == category))
		bag.shuffle()
	return bag.pop_back()


static func describe_effects(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in effects:
		parts.append("%s %+d" % [RESOURCE_NAMES[key], effects[key]])
	return ", ".join(parts)
