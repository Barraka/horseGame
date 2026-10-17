extends Node
## The player's horses, which one they ride, and how well each is looked
## after. Autoloaded as "Stable". Everything is saved, so the game remembers
## it next time.

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

## Care levels run from 0 to 1. Food and love slowly run down over real
## time (gently: a full horse is only hungry after a day and a half);
## riding makes a horse hungry and dirty.
const CARE_KEYS := ["food", "clean", "love"]
const FOOD_PER_HOUR := 1.0 / 36.0
const LOVE_PER_HOUR := 1.0 / 48.0
const RIDE_FOOD_PER_KM := 0.2
const RIDE_DIRT_PER_KM := 0.4
const FEED_AMOUNT := 0.3
const PET_AMOUNT := 0.15

signal care_changed(index: int)

var selected := 0
var care: Array[Dictionary] = []
var tack: Array[Dictionary] = []   ## Each horse's tack colours (tack.gd OPTIONS)
var discovered: Array = []   ## Ids of the places found while exploring (world.gd PLACES)
var _saved_time := 0.0


func _init() -> void:
	for i in HORSES.size():
		# A new horse arrives a little hungry and dusty, so there's
		# something to do straight away.
		care.append({"food": 0.6, "clean": 0.5, "love": 0.5})
		tack.append({})


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		selected = clampi(config.get_value("stable", "selected", 0), 0, HORSES.size() - 1)
		for i in HORSES.size():
			for key in CARE_KEYS:
				care[i][key] = config.get_value("care", "%s_%d" % [key, i], care[i][key])
			tack[i] = config.get_value("tack", str(i), {})
		_saved_time = config.get_value("care", "time", 0.0)
		discovered = config.get_value("explore", "discovered", [])
	# Time passes while the game is closed.
	var now := Time.get_unix_time_from_system()
	if _saved_time > 0.0:
		_pass_time(clampf((now - _saved_time) / 3600.0, 0.0, 24.0 * 30.0))
	_saved_time = now


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()


func current() -> Dictionary:
	return HORSES[selected]


func select(index: int) -> void:
	selected = wrapi(index, 0, HORSES.size())
	_save()


## How happy a horse is overall, from 0 to 1.
func happiness(index: int) -> float:
	var c: Dictionary = care[index]
	return (c.food + c.clean + c.love) / 3.0


func set_tack(index: int, config: Dictionary) -> void:
	tack[index] = config.duplicate()
	_save()


## Remember a place as found. Returns false if it was found before.
func discover(id: String) -> bool:
	if id in discovered:
		return false
	discovered.append(id)
	_save()
	return true


## Returns false if the horse is too full to eat.
func feed(index: int) -> bool:
	if care[index].food > 0.95:
		return false
	_change(index, "food", FEED_AMOUNT)
	_change(index, "love", 0.05)
	return true


## Brush away `amount` of dirt.
func brush(index: int, amount: float) -> void:
	_change(index, "clean", amount)


func pet(index: int) -> void:
	_change(index, "love", PET_AMOUNT)


## The ridden horse covered `metres`: it gets hungrier and dirtier.
func ride(index: int, metres: float) -> void:
	care[index].food = clampf(care[index].food - RIDE_FOOD_PER_KM * metres / 1000.0, 0.0, 1.0)
	care[index].clean = clampf(care[index].clean - RIDE_DIRT_PER_KM * metres / 1000.0, 0.0, 1.0)
	care_changed.emit(index)
	_save()


func _change(index: int, key: String, amount: float) -> void:
	care[index][key] = clampf(care[index][key] + amount, 0.0, 1.0)
	care_changed.emit(index)
	_save()


func _pass_time(hours: float) -> void:
	for c in care:
		c.food = maxf(c.food - FOOD_PER_HOUR * hours, 0.0)
		c.love = maxf(c.love - LOVE_PER_HOUR * hours, 0.0)


func _save() -> void:
	var now := Time.get_unix_time_from_system()
	_pass_time((now - _saved_time) / 3600.0)
	_saved_time = now
	var config := ConfigFile.new()
	config.set_value("stable", "selected", selected)
	for i in HORSES.size():
		for key in CARE_KEYS:
			config.set_value("care", "%s_%d" % [key, i], care[i][key])
	config.set_value("care", "time", _saved_time)
	for i in HORSES.size():
		config.set_value("tack", str(i), tack[i])
	config.set_value("explore", "discovered", discovered)
	config.save(SAVE_PATH)
