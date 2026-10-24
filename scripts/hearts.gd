extends HBoxContainer
## A row of hearts showing a horse's bond with you (Stable.hearts): full
## hearts, then one filling up, then empty ones.

var heart_size := 22.0
var _icons: Array[TextureRect] = []
static var _full: Texture2D
static var _empty: Texture2D


func _init() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hearts(index: int) -> void:
	if _icons.is_empty():
		_build()
	var count: int = Stable.hearts(index)
	var part: float = Stable.heart_progress(index)
	for i in _icons.size():
		var icon := _icons[i]
		if i < count:
			icon.texture = _full
			icon.modulate = Color.WHITE
		else:
			icon.texture = _empty
			# The next heart fills in pink as the bond grows.
			icon.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.6, 0.75), part) if i == count else Color.WHITE


func _build() -> void:
	if not _full:
		_full = _heart(Color(1.0, 0.36, 0.55), Color(1.0, 0.85, 0.9))
		_empty = _heart(Color(0.15, 0.1, 0.18, 0.55), Color(1.0, 0.85, 0.9, 0.9))
	for i in Stable.MAX_HEARTS:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2.ONE * heart_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_icons.append(icon)


## A heart with an outline, from the heart curve (x² + y² - 1)³ - x²y³ <= 0.
static func _heart(fill: Color, edge: Color) -> Texture2D:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var px := (x - size * 0.5) / (size * 0.36)
			var py := (size * 0.56 - y) / (size * 0.36)
			var v := pow(px * px + py * py - 1.0, 3.0) - px * px * py * py * py
			var inside := clampf(-v * 30.0, 0.0, 1.0)
			var core := clampf((-v - 0.12) * 30.0, 0.0, 1.0)
			var color := edge.lerp(fill, core)
			color.a *= inside
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
