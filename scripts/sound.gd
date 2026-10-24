extends Node
## Sounds and music for the whole game (an autoload, "Sound"). Plays the
## gentle tune on a loop, and short sounds by name from assets/audio (made
## by tools/make_sounds.py). Music goes on the "Music" bus and everything
## else on "Sounds", so each has its own volume.
##
## Looking after a horse makes its own sounds here: a crunch and a happy
## nicker for a carrot, a nicker for a pat, a brush sound while brushing,
## and a chime when coins come in (a fanfare for finding a new place).
## Every button clicks softly.

const DIR := "res://assets/audio/"
const LOOPS := ["music", "rain", "waves", "wind", "crickets"]
const VOICES := 12           ## Sounds that can play at once
const MUSIC_DB := -9.0

var counts := {}              ## How often each sound has played (for the tests)
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _care := {}               ## Horse index -> its care levels when last seen
var _found := 0               ## Places found, to tell a discovery from other coins
var _brush_wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "Sounds"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Sounds"
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = stream("music")
	_music.volume_db = -40.0
	add_child(_music)
	if not DisplayServer.get_name() == "headless":
		_music.play()
		create_tween().tween_property(_music, "volume_db", MUSIC_DB, 3.0)
	get_tree().node_added.connect(func(node):
		if node is BaseButton:
			node.pressed.connect(play.bind("click", -6.0)))
	var stable := get_node_or_null("/root/Stable")
	if stable:
		for i in stable.care.size():
			_care[i] = stable.care[i].duplicate()
		_found = stable.discovered.size()
		stable.care_changed.connect(_on_care_changed)
		stable.coins_changed.connect(_on_coins_changed)


func _process(delta: float) -> void:
	_brush_wait -= delta
	# Keep up with care levels that change quietly (time passing).
	var stable := get_node_or_null("/root/Stable")
	if stable:
		for i in stable.care.size():
			_care[i] = stable.care[i].duplicate()


## A sound file (without .ogg), loaded once. Loops are set to loop.
func stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var loaded := load(DIR + sound + ".ogg") as AudioStream
		if loaded is AudioStreamOggVorbis:
			loaded.loop = sound in LOOPS
		_streams[sound] = loaded
	return _streams[sound]


## Play a short sound. `sound` can name a set ("whinny" picks one of
## whinny_1, whinny_2...) when `variants` is more than one.
func play(sound: String, volume_db := 0.0, pitch := 1.0, variants := 0) -> void:
	if variants > 0:
		sound = "%s_%d" % [sound, randi_range(1, variants)]
	counts[sound] = counts.get(sound, 0) + 1
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Soften the music (in a competition, say) or bring it back.
func set_music_quiet(quiet: bool) -> void:
	create_tween().tween_property(_music, "volume_db", MUSIC_DB - (8.0 if quiet else 0.0), 1.5)


func _on_care_changed(index: int) -> void:
	var now: Dictionary = get_node("/root/Stable").care[index]
	var before: Dictionary = _care.get(index, now)   # As it was last frame
	if now.food > before.food + 0.01:
		play("crunch", -4.0)
		get_tree().create_timer(0.45).timeout.connect(play.bind("nicker", -3.0, randf_range(0.95, 1.08)))
	elif now.love > before.love + 0.01:
		play("nicker", -3.0, randf_range(0.92, 1.1))
	elif now.clean > before.clean + 0.001 and _brush_wait <= 0.0:
		_brush_wait = 0.22
		play("brush", -10.0, randf_range(0.85, 1.2))
	_care[index] = now.duplicate()


func _on_coins_changed(_coins: int, gained: int) -> void:
	var found: int = get_node("/root/Stable").discovered.size()
	if found > _found:
		play("discover", -4.0)
	elif gained > 0:
		play("coin", -8.0)
	_found = found
