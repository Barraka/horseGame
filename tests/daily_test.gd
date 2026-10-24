extends SceneTree
## Daily surprises and the sticker book: three tasks a day picked by the
## date (the same ones all day, never two of a kind), the game's doings
## counting for them, each one done giving coins and a sticker, the surprise
## box once all three are done, new tasks the next day, and the stable's
## Today and Stickers panels. Puts the saved stable and stickers back
## afterwards. Run with: godot --headless --path . -s tests/daily_test.gd

const Stickers := preload("res://scripts/stickers.gd")

var ok := true
var frames := 0
var scene: Node
var saved := {}
var saved_daily := {}


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _kinds(daily: Node) -> Array:
	return daily.today.map(func(t): return daily.task_info(t.id).kind)


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var daily := root.get_node("Daily")
	if frames == 2:
		saved = {"coins": stable.coins, "selected": stable.selected, "rider": root.get_node("RiderData").saved}
		saved_daily = {"day": daily.day, "today": daily.today.duplicate(true), "box": daily.box_opened,
			"stickers": daily.stickers.duplicate(), "new": daily.new_stickers.duplicate()}
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
		return false
	if frames != 4:
		return false

	daily.enabled = true   # Off for the other tests
	# Picking the day's tasks.
	daily.today.clear()
	daily.refresh_day("2026-11-02")
	var first: Array = daily.today.map(func(t): return t.id)
	_check("Three tasks a day", first.size() == daily.PER_DAY)
	var kinds := _kinds(daily)
	_check("Never two of the same kind", kinds.all(func(k): return kinds.count(k) == 1))
	daily.today.clear()
	daily.refresh_day("2026-11-02")
	_check("The same date picks the same tasks", daily.today.map(func(t): return t.id) == first)
	var differ := false
	for d in ["2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"]:
		daily.refresh_day(d)
		if daily.today.map(func(t): return t.id) != first:
			differ = true
	_check("Other days bring other tasks", differ)

	# Doing them.
	# (Today, since the stable's Today panel always looks at today's date.)
	daily.stickers.clear()
	daily.new_stickers.clear()
	daily.today.clear()
	daily.refresh_day(daily.date_today())
	stable.coins = 0
	var task: Dictionary = daily.today[0]
	var info: Dictionary = daily.task_info(task.id)
	stable.note(info.kind, info.goal * 0.5)
	_check("Doing something counts for a task", is_equal_approx(task.progress, info.goal * 0.5) and not task.done)
	stable.note("nothing_like_this", 5)
	daily.enabled = false
	stable.note(info.kind, info.goal)
	_check("Switched off, nothing counts", is_equal_approx(task.progress, info.goal * 0.5))
	daily.enabled = true
	_check("Other things don't count", is_equal_approx(task.progress, info.goal * 0.5))
	stable.note(info.kind, info.goal)
	_check("Finishing a task gives its coins", task.done and stable.coins == info.coins)
	_check("And a sticker", daily.stickers.size() == 1 and Stickers.COMMON.has(daily.stickers[0]))
	_check("A note pops up", daily._toast.visible and info.text in daily._toast_text.text)
	_check("The box waits for all three", not daily.box_ready() and daily.open_box() == "")
	for t in daily.today:
		stable.note(daily.task_info(t.id).kind, daily.task_info(t.id).goal)
	_check("All three done", daily.done_count() == 3 and daily.stickers.size() == 3)
	_check("The surprise box is ready", daily.box_ready())

	# The stable's panels.
	var panel: Node = scene._daily
	_check("The stable has Today and Stickers buttons", panel._today_button.visible and panel._book_button.visible)
	_check("The Today button shows the box is ready", "★" in panel._today_button.text)
	_check("The Stickers button shows new ones", "NEW" in panel._book_button.text)
	panel.open_today()
	_check("Today shows the three tasks", panel._today.visible and panel._rows.get_child_count() >= 3)
	_check("With the button to open the box", panel._box_button.visible)
	var coins_before: int = stable.coins
	panel._open_box()
	var rare: String = panel._box_sticker
	_check("The box gives a rare sticker", Stickers.RARE.has(rare) and rare in daily.stickers)
	_check("And bonus coins", stable.coins == coins_before + daily.BOX_COINS)
	_check("Only once a day", not daily.box_ready() and daily.open_box() == "")
	panel.open_book()
	_check("The sticker book opens (and Today closes)", panel._book.visible and not panel._today.visible)
	_check("With a space for every sticker", panel._pages.get_child_count() == Stickers.all_ids().size())
	_check("Looking clears the NEW", daily.new_stickers.is_empty() and not "NEW" in panel._book_button.text)
	scene._shop._toggle()
	_check("Opening the shop closes the book", not panel.is_open())
	scene._shop.close()

	# Saved, and a new day.
	daily._save()
	var config := ConfigFile.new()
	config.load(daily.SAVE_PATH)
	_check("Stickers are saved", config.get_value("stickers", "have", []).size() == 4)
	daily.refresh_day("2099-01-01")
	_check("A new day brings new tasks", daily.done_count() == 0 and not daily.box_opened and daily.today.size() == 3)
	_check("And keeps the stickers", daily.stickers.size() == 4)

	stable.coins = saved.coins
	stable.select(saved.selected)
	root.get_node("RiderData").saved = saved.rider
	daily.day = saved_daily.day
	daily.today = saved_daily.today
	daily.box_opened = saved_daily.box
	daily.stickers = saved_daily.stickers
	daily.new_stickers = saved_daily.new
	daily._save()
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
