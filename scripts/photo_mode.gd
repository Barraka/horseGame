extends CanvasLayer
## Photo mode: a "Photo" button (or P) stops the game and hides the
## buttons so you can take pictures of your horse. Drag to move the camera
## around the horse, scroll (or + and −) to go closer or further, pick a
## look (golden, black and white, dreamy, old photo) and press Take photo.
## Photos are saved as PNG files in Pictures/Silver Mane on a computer (in
## the game's own folder where that isn't possible), and the Album shows
## them all.

signal photo_taken(path: String)

@export var horse_path: NodePath

const LOOKS := ["As it is", "Golden", "Black & white", "Dreamy", "Old photo"]
const ALBUM_SIZE := 24   ## Newest photos shown in the album

var look := 0
var _horse: Node3D
var _camera: Camera3D
var _was_camera: Camera3D
var _yaw := 0.0
var _pitch := -0.2
var _distance := 5.0
var _hidden: Array[CanvasLayer] = []
var _open_button: Button
var _filter: ColorRect
var _ui: Control
var _look_label: Label
var _flash: ColorRect
var _saved: Label
var _album: PanelContainer
var _grid: GridContainer
var _big: TextureRect


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_horse = get_node(horse_path)
	_build_ui()


func is_open() -> bool:
	return _camera != null


## Where photos go: Pictures/Silver Mane if the computer lets us, otherwise
## a folder in the game's own save folder.
static func photos_dir() -> String:
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "" and OS.get_name() != "Android":
		var dir := pictures.path_join(ProjectSettings.get_setting("application/config/name", "Silver Mane"))
		if DirAccess.make_dir_recursive_absolute(dir) == OK:
			return dir
	DirAccess.make_dir_recursive_absolute("user://photos")
	return "user://photos"


func open() -> void:
	if is_open():
		return
	get_tree().paused = true
	# Hide every other layer of buttons and panels.
	_hidden.clear()
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var other := node as CanvasLayer
		if other != self and other.visible:
			other.visible = false
			_hidden.append(other)
	_open_button.visible = false
	# A camera of our own, starting where the game's camera was.
	_was_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	var target := _target()
	var from := _was_camera.global_position if _was_camera else target + Vector3(0, 1, 5)
	var offset := from - target
	_distance = clampf(offset.length(), 2.0, 12.0)
	_yaw = atan2(offset.x, offset.z)
	_pitch = clampf(asin(clampf(offset.y / maxf(offset.length(), 0.01), -1.0, 1.0)), -0.15, 1.2)
	_camera.current = true
	_place_camera()
	_ui.visible = true
	_set_look(look)


func close() -> void:
	if not is_open():
		return
	_album.visible = false
	_ui.visible = false
	_filter.visible = false
	for other in _hidden:
		if is_instance_valid(other):
			other.visible = true
	_hidden.clear()
	_open_button.visible = true
	if _was_camera and is_instance_valid(_was_camera):
		_was_camera.current = true
	_camera.queue_free()
	_camera = null
	get_tree().paused = false


## Save what's on screen, without the photo buttons. Returns the file's path.
func take_photo() -> String:
	_ui.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if not is_open():
		return ""   # Closed while the picture was being taken
	_ui.visible = true
	if not image or image.is_empty():
		return ""   # Nothing drawn (running without a screen)
	var path := photos_dir().path_join("Silver Mane %s.png" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", " "))
	if FileAccess.file_exists(path):
		path = path.get_basename() + " %d.png" % (Time.get_ticks_msec() % 1000)
	image.save_png(path)
	_flash.modulate.a = 0.9
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.5)
	_saved.text = "Saved!"
	_saved.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(1.4)
	fade.tween_property(_saved, "modulate:a", 0.0, 0.5)
	Sound.play("click", -2.0, 0.6)
	photo_taken.emit(path)
	return path


func _target() -> Vector3:
	return _horse.global_position + Vector3.UP * 1.25


func _place_camera() -> void:
	if not _camera:
		return
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.global_position = _target() + offset
	_camera.look_at(_target())


func _zoom(by: float) -> void:
	_distance = clampf(_distance * by, 1.6, 14.0)
	_place_camera()


func _set_look(which: int) -> void:
	look = wrapi(which, 0, LOOKS.size())
	_look_label.text = LOOKS[look]
	_filter.visible = look != 0 and is_open()
	(_filter.material as ShaderMaterial).set_shader_parameter("look", look)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_P:
			if is_open():
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif is_open() and key.physical_keycode == KEY_ESCAPE:
			if _album.visible:
				_album.visible = false
			else:
				close()
			get_viewport().set_input_as_handled()
		return
	if not is_open() or _album.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turn(event.relative)
	elif event is InputEventScreenDrag:
		_turn(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / event.factor)


func _turn(relative: Vector2) -> void:
	_yaw -= relative.x * 0.008
	_pitch = clampf(_pitch + relative.y * 0.006, -0.15, 1.3)
	_place_camera()


# --- The album ------------------------------------------------------------------

func _show_album() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_big.visible = false
	var dir := photos_dir()
	var files: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() == "png":
			files.append(file)
	files.sort()
	files.reverse()
	for file in files.slice(0, ALBUM_SIZE):
		var image := Image.load_from_file(dir.path_join(file))
		if not image:
			continue
		var full := ImageTexture.create_from_image(image)
		image.resize(192, int(192.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_BILINEAR)
		var thumb := TextureButton.new()
		thumb.texture_normal = ImageTexture.create_from_image(image)
		thumb.focus_mode = Control.FOCUS_NONE
		thumb.pressed.connect(func():
			_big.texture = full
			_big.visible = true)
		_grid.add_child(thumb)
	if files.is_empty():
		_grid.add_child(_label("No photos yet. Press Take photo!", 20))
	_album.visible = true


# --- Buttons --------------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_filter = ColorRect.new()
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.material = ShaderMaterial.new()
	(_filter.material as ShaderMaterial).shader = preload("res://shaders/photo_filter.gdshader")
	_filter.visible = false
	root.add_child(_filter)

	_open_button = _button("Photo", open, Vector2(120, 48))
	root.add_child(_open_button)
	_open_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_open_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_open_button.position += Vector2(136, 20)   # Right of the Stable button

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	root.add_child(_ui)
	var hint := _label("Drag to move around your horse · Scroll or + − to go closer", 17)
	_ui.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.position.y += 20
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_ui.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 24
	bar.add_child(_button("−", _zoom.bind(1.15), Vector2(56, 56)))
	bar.add_child(_button("+", _zoom.bind(0.87), Vector2(56, 56)))
	bar.add_child(_button("◀", func(): _set_look(look - 1), Vector2(56, 56)))
	_look_label = _label("", 20)
	_look_label.custom_minimum_size.x = 150
	bar.add_child(_look_label)
	bar.add_child(_button("▶", func(): _set_look(look + 1), Vector2(56, 56)))
	var shoot := _button("Take photo", take_photo, Vector2(170, 56))
	var bright := _style(Color(1, 0.97, 0.9, 0.95))
	for state in ["normal", "hover", "pressed"]:
		shoot.add_theme_stylebox_override(state, bright)
		shoot.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color(0.2, 0.15, 0.25))
	bar.add_child(shoot)
	bar.add_child(_button("Album", _show_album, Vector2(110, 56)))
	bar.add_child(_button("Done", close, Vector2(100, 56)))

	_saved = _label("", 34)
	_saved.modulate.a = 0.0
	_ui.add_child(_saved)
	_saved.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_saved.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)

	# The album: thumbnails of the newest photos; tap one to see it big.
	_album = PanelContainer.new()
	_album.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.92)))
	_album.set_anchors_preset(Control.PRESET_FULL_RECT)
	_album.offset_left = 40
	_album.offset_right = -40
	_album.offset_top = 30
	_album.offset_bottom = -30
	_album.visible = false
	root.add_child(_album)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_album.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)
	var title := _label("Photo album", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if OS.get_name() != "Android":
		top.add_child(_button("Open folder", func(): OS.shell_open(ProjectSettings.globalize_path(photos_dir())), Vector2(150, 48)))
	top.add_child(_button("Close", func(): _album.visible = false, Vector2(110, 48)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_big = TextureRect.new()
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.visible = false
	_big.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_big.visible = false)
	_album.add_child(_big)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, action: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 20)
	var style := _style(Color(0.08, 0.06, 0.12, 0.55))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
