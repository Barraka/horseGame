extends Node
## The player's horses, which one they ride, how well each is looked
## after, and the coins and shop purchases. Autoloaded as "Stable". Everything is saved, so the game remembers
## it next time.

const SAVE_PATH := "user://stable.cfg"

## Each horse is the same model with its own coat colours. A strength of 0
## keeps the model's original painted coat. A pattern (see coat.gdshader)
## adds patches, spots or dapples. Horses with a price are sold in the shop.
const HORSES := [
	{"name": "Hazel",    "coat": "Bay",       "body": Color(0.42, 0.2, 0.08),   "points": Color(0.05, 0.04, 0.04), "strength": 1.0},
	{"name": "Ginger",   "coat": "Chestnut",  "body": Color(0.6, 0.27, 0.1),    "points": Color(0.42, 0.17, 0.07), "strength": 1.0},
	{"name": "Midnight", "coat": "Black",     "body": Color(0.07, 0.065, 0.07), "points": Color(0.03, 0.03, 0.03), "strength": 1.0},
	{"name": "Silver",   "coat": "Grey",      "body": Color(0.78, 0.78, 0.78),  "points": Color(0.3, 0.3, 0.32),   "strength": 1.0},
	{"name": "Honey",    "coat": "Palomino",  "body": Color(0.86, 0.64, 0.33),  "points": Color(0.93, 0.88, 0.74), "strength": 1.0},
	{"name": "Sandy",    "coat": "Dun",       "body": Color(0.7, 0.55, 0.4),    "points": Color(0.2, 0.15, 0.12),  "strength": 0.0},
	{"name": "Biscuit",  "coat": "Buckskin",  "body": Color(0.8, 0.6, 0.34),    "points": Color(0.05, 0.04, 0.04), "strength": 1.0, "price": 120},
	{"name": "Pearl",    "coat": "Cremello",  "body": Color(0.95, 0.89, 0.78),  "points": Color(0.97, 0.93, 0.85), "strength": 1.0, "price": 150},
	{"name": "Storm",    "coat": "Dapple grey", "body": Color(0.62, 0.62, 0.64), "points": Color(0.18, 0.18, 0.2), "strength": 1.0, "price": 200, "pattern": 3},
	{"name": "Patches",  "coat": "Bay pinto", "body": Color(0.42, 0.2, 0.08),   "points": Color(0.05, 0.04, 0.04), "strength": 1.0, "price": 250, "pattern": 1},
	{"name": "Shadow",   "coat": "Black pinto", "body": Color(0.07, 0.065, 0.07), "points": Color(0.03, 0.03, 0.03), "strength": 1.0, "price": 280, "pattern": 1},
	{"name": "Freckles", "coat": "Appaloosa", "body": Color(0.93, 0.91, 0.87),  "points": Color(0.12, 0.08, 0.06), "strength": 1.0, "price": 320, "pattern": 2, "pattern_color": Color(0.22, 0.12, 0.07)},
]

## Coins are earned by riding, jumping and exploring, and spent in the shop.
const START_COINS := 50
const COINS_PER_KM := 20          ## One coin every 50 m ridden
const COURSE_COINS := 15          ## For finishing the jumping course...
const CLEAR_ROUND_COINS := 25     ## ...and this much more for no faults
const PLACE_COINS := 30           ## For finding a new place

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
signal coins_changed(coins: int, gained: int)

var selected := 0
var care: Array[Dictionary] = []
var tack: Array[Dictionary] = []   ## Each horse's tack colours (tack.gd OPTIONS)
var discovered: Array = []   ## Ids of the places found while exploring (world.gd PLACES)
var coins := START_COINS
var bought: Array = []        ## Names of horses bought in the shop
var bought_tack: Array = []   ## Tack options bought in the shop, as "key:index"
var _coin_metres := 0.0
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
		coins = config.get_value("shop", "coins", START_COINS)
		bought = config.get_value("shop", "horses", [])
		bought_tack = config.get_value("shop", "tack", [])
		if not owns(selected):
			selected = 0
		# Tack already chosen before the shop opened stays the player's.
		var options: Dictionary = preload("res://scripts/tack.gd").OPTIONS
		for chosen in tack:
			for key in chosen:
				if options.has(key) and chosen[key] < options[key].size() and not owns_tack(key, chosen[key], options):
					bought_tack.append("%s:%d" % [key, chosen[key]])
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


func owns(index: int) -> bool:
	return not HORSES[index].has("price") or HORSES[index].name in bought


## The horses in the stable, in order.
func owned_horses() -> Array[int]:
	var list: Array[int] = []
	for i in HORSES.size():
		if owns(i):
			list.append(i)
	return list


## Whether a tack option (tack.gd OPTIONS) can be used.
func owns_tack(key: String, index: int, options: Dictionary) -> bool:
	return not options[key][index].has("price") or "%s:%d" % [key, index] in bought_tack


func earn(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins, amount)
	_save()


## Buy a horse from the shop. Returns false if there aren't enough coins.
func buy_horse(index: int) -> bool:
	if owns(index) or coins < HORSES[index].price:
		return false
	coins -= HORSES[index].price
	bought.append(HORSES[index].name)
	coins_changed.emit(coins, -HORSES[index].price)
	_save()
	return true


## Buy a tack option from the shop. Returns false if there aren't enough coins.
func buy_tack(key: String, index: int, options: Dictionary) -> bool:
	var price: int = options[key][index].get("price", 0)
	if owns_tack(key, index, options) or coins < price:
		return false
	coins -= price
	bought_tack.append("%s:%d" % [key, index])
	coins_changed.emit(coins, -price)
	_save()
	return true


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
	_coin_metres += metres
	var earned := int(_coin_metres * COINS_PER_KM / 1000.0)
	if earned > 0:
		_coin_metres -= earned * 1000.0 / COINS_PER_KM
		earn(earned)   # Saves
	else:
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
	config.set_value("shop", "coins", coins)
	config.set_value("shop", "horses", bought)
	config.set_value("shop", "tack", bought_tack)
	config.save(SAVE_PATH)
