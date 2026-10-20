extends Node
## Registers the game's controls (keyboard on PC: U J H L or the arrows to
## ride and steer; clicks to change speed are in horse.gd). Touch controls
## on the tablet press the same actions, so the horse code only reads actions.

const KEYS := {
	"ride_forward": [KEY_U, KEY_UP],
	"ride_back": [KEY_J, KEY_DOWN],
	"steer_left": [KEY_H, KEY_LEFT],
	"steer_right": [KEY_L, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"gait_up": [KEY_E],
	"gait_down": [KEY_Q],
	"gait_0": [KEY_0],
	"gait_1": [KEY_1],
	"gait_2": [KEY_2],
	"gait_3": [KEY_3],
	"gait_4": [KEY_4],
}


func _enter_tree() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
