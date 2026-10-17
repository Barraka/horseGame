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

**Stable:** the game opens in your stable. Use the arrows (or ← / →) to look through your six horses, drag to turn the horse around, and press **Ride** (or Enter). The **Stable** button at the top of the riding screen takes you back. The game remembers which horse you picked. To add or change horses, edit the list in `scripts/stable_data.gd`.

**Horse care:** in the stable, the panel on the left shows how full, clean and loved the horse is. **Feed** gives it a carrot, **Pet** gives it a pat, and **Brush** lets you rub the mud off by dragging over the horse (press **Done** to go back to turning it). Riding makes a horse hungry and muddy, and food and love slowly run down while you're away, so come back and look after your horses. The rates are at the top of `scripts/stable_data.gd`.

**Your rider:** the first time the game starts, you design your rider: girl or boy, skin tone, hairstyle and colour, outfit and riding helmet. Drag to turn the rider around and press **Done**. The **My Rider** button in the stable brings the screen back. Your rider sits on whichever horse you ride.

**Show jumping:** ride through the green START gate, jump fences 1 to 5 in order, then ride through FINISH. A knocked rail costs 4 faults.

To change the course, open `scenes/main.tscn` and expand **Course** in the scene tree. Each fence and gate is its own object: select it and drag or rotate it in the 3D view (the green arrow on the ground shows the jumping direction). Change a fence's height in the Inspector. Fences are jumped in the order they're listed; duplicate one with Ctrl+D to add a fence.

## The horse model

The horse is made of three downloads of the same horse, one per gait (walk, trot and gallop), in `assets/horse/gaits/`. See `assets/horse/README.md` for how they fit together, and for using a different model.

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
| `scenes/stable.tscn`, `scripts/stable.gd` | The stable screen where you pick a horse |
| `scripts/stable_data.gd` | Your horses (names and coat colours), which one you ride, and how well each is looked after |
| `scripts/horse_care.gd` | Feeding, brushing and petting in the stable |
| `scenes/rider_creator.tscn`, `scripts/rider_creator.gd` | The screen where you design your rider |
| `scripts/rider.gd` | The rider: puts the character parts together and poses them; add options to its lists |
| `scripts/rider_data.gd` | How your rider looks, saved between games |
| `assets/rider/` | Character parts (bodies, heads, hair, outfits) from Quaternius |
| `tools/prepare_rider.py` | Copies the character parts out of the Quaternius downloads into `assets/rider/` |
| `tools/saddle_track.py` | Measures where the saddle sits on the horse in each gait (writes `assets/horse/gaits/saddle_track.json`) |
| `shaders/coat.gdshader` | Recolours the horse's coat and adds mud when it's dirty |
| `scripts/horse.gd` | Gaits, steering, jumping, model loading and the placeholder horse |
| `scripts/world.gd` | Terrain, arena, trees, rocks, grass and flowers |
| `scripts/course.gd`, `scripts/fence.gd`, `scripts/gate.gd` | Show jumping course, scoring, fences and gates |
| `scripts/follow_camera.gd` | Third-person camera |
| `scripts/hud.gd`, `scripts/virtual_joystick.gd` | On-screen display and touch controls |
| `tests/ride_test.gd` | Automatic test: rides the course twice and checks scoring and that riding wears the horse out |
| `legacy-babylon/` | The earlier Babylon.js web version, kept for reference |

Run the test with `godot --headless --path . -s tests/ride_test.gd`.
