extends Node
## The player's horses, and which one they ride. Autoloaded as "Stable".
## The choice is saved, so the game remembers it next time.

const SAVE_PATH := "user://stable.cfg"

## Each horse is the same model with its own coat colours. A strength of 0
## keeps the model's original painted coat.
const HORSES := [
	{"name": "Hazel",    "coat": "Bay",       "body": Color(0.42, 0.2, 0.08),   "points": Color(0.05, 0.04, 0.04), "strength": 1.0},
	{"name": "Ginger",   "coat": "Chestnut",  "body": Color(0.6, 0.27, 0.1),    "points": Color(0.42, 0.17, 0.07), "strength": 1.0},
	{"name": "Midnight", "coat": "Black",     "body": Color(0.07, 0.065, 0.07), "points": Color(0.03, 0.03, 0.03), "strength": 1.0},
	{"name": "Silver",   "coat": "Grey",      "body": Color(0.78, 0.78, 0.78),  "points": Color(0.3, 0.3, 0.32),   "strength": 1.0},
	{"name": "Honey",    "coat": "Palomino",  "body": Color(0.86, 0.64, 0.33),  "points": Color(0.93, 0.88, 0.74), "strength": 1.0},
	{"name": "Sandy",    "coat": "Dun",       "body": Color(0.7, 0.55, 0.4),    "points": Color(0.2, 0.15, 0.12),  "strength": 0.0},
]

var selected := 0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		selected = clampi(config.get_value("stable", "selected", 0), 0, HORSES.size() - 1)


func current() -> Dictionary:
	return HORSES[selected]


func select(index: int) -> void:
	selected = wrapi(index, 0, HORSES.size())
	var config := ConfigFile.new()
	config.set_value("stable", "selected", selected)
	config.save(SAVE_PATH)
