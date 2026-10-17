extends PanelContainer
## The player's coins: a gold coin and the count, with a little "+5" that
## floats up whenever coins are earned. Used on the riding screen and in
## the stable.

var _label: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.45)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = coin_texture(18)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	row.add_child(_label)
	_label.text = str(Stable.coins)
	Stable.coins_changed.connect(_on_coins_changed)


func _on_coins_changed(coins: int, gained: int) -> void:
	_label.text = str(coins)
	if gained <= 0:
		return
	var pop := Label.new()
	pop.text = "+%d" % gained
	pop.add_theme_font_size_override("font_size", 26)
	pop.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	pop.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	pop.add_theme_constant_override("outline_size", 6)
	pop.top_level = true
	add_child(pop)
	pop.global_position = global_position + Vector2(size.x + 8, 0)
	var tween := pop.create_tween()
	tween.tween_property(pop, "global_position:y", pop.global_position.y - 30, 1.2)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(pop.queue_free)


## A shiny gold coin, drawn in code.
static func coin_texture(radius: int) -> ImageTexture:
	var size := radius * 2 + 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(radius + 1, radius + 1)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			if d > radius:
				continue
			var edge := clampf(radius - d, 0.0, 1.0)
			var color := Color(0.95, 0.7, 0.18)
			if d > radius - 2.5:
				color = Color(0.78, 0.52, 0.1)   # Rim
			elif d < radius * 0.55:
				color = Color(1.0, 0.82, 0.3)    # Raised middle
			# A highlight towards the top left.
			var shine := clampf(1.0 - Vector2(x, y).distance_to(centre - Vector2(radius, radius) * 0.4) / radius, 0.0, 1.0)
			color = color.lerp(Color(1, 1, 0.85), shine * 0.5)
			color.a = edge
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
