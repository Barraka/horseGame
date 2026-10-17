# Horse Game

A horse riding game inspired by Star Stable, made with Godot 4.7 for Windows PC and Android tablets.

This is the first playable prototype: ride a horse around a meadow, switch gaits, and jump a show jumping course in the arena.

## Open and play on PC

1. Install [Godot 4.7](https://godotengine.org/download) (the standard version, not .NET).
2. In the Godot Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

| Key | Action |
| --- | --- |
| W / S or ↑ / ↓ | Ride on / slow down and back up |
| A / D or ← / → | Steer |
| Q / E, or 0 to 4 | Change gait (halt, walk, trot, canter, gallop) |
| Space | Jump (trot or faster) |
| Mouse drag, scroll | Look around, zoom |

On a tablet, a joystick appears bottom left and Faster, Slower and Jump buttons bottom right; drag on the open screen to look around.

**Show jumping:** ride through the green START gate, jump fences 1 to 5 in order, then ride through FINISH. A knocked rail costs 4 faults. Fence positions and heights can be changed on the `Course` node in the Inspector.

## Adding the horse model

Save the model as `assets/horse/horse.glb`. The game picks it up automatically, and its animations are matched by name (idle, walk, trot, canter, gallop, jump). See `assets/horse/README.md` if it looks wrong.

## Play on the Android tablet

One-time setup on the PC:

1. In Godot: **Editor > Manage Export Templates > Download and Install**.
2. Install the Android tools as described in Godot's guide [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) (OpenJDK 17 and the Android SDK), and set their paths in **Editor > Editor Settings > Export > Android**.
3. On the tablet, turn on **Developer options** and **USB debugging**, then plug it into the PC.

Then, any time: click the **Android** button that appears next to ▶ at the top right of Godot to install and start the game on the tablet. **Project > Export > Android** builds an `.apk` file instead.

## Project layout

| Path | What it is |
| --- | --- |
| `scenes/main.tscn` | The game scene: sky and lighting, world, horse, camera, course, HUD |
| `scripts/horse.gd` | Gaits, steering, jumping, model loading and the placeholder horse |
| `scripts/world.gd` | Terrain, arena, trees, rocks, grass and flowers |
| `scripts/course.gd` | Show jumping course and scoring |
| `scripts/follow_camera.gd` | Third-person camera |
| `scripts/hud.gd`, `scripts/virtual_joystick.gd` | On-screen display and touch controls |
| `tests/ride_test.gd` | Automatic test: rides the course twice and checks scoring |
| `legacy-babylon/` | The earlier Babylon.js web version, kept for reference |

Run the test with `godot --headless --path . -s tests/ride_test.gd`.
