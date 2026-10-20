# Horse Game

A horse riding game inspired by Star Stable, made with Godot 4.7 for Windows PC and Android tablets.

This is the first playable prototype: ride a horse around a meadow, switch gaits, and jump a show jumping course in the arena.

## Open and play on PC

1. Install [Godot 4.7](https://godotengine.org/download) (the standard version, not .NET).
2. In the Godot Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

| Key | Action |
| --- | --- |
| U / J or ↑ / ↓ | Ride on / slow down and back up |
| H / L or ← / → | Steer |
| Left click / right click | One gait faster / slower (also Q / E, or 0 to 4 for halt, walk, trot, canter, gallop) |
| Space | Jump (trot or faster) |
| Mouse drag, scroll | Look around, zoom |

On a tablet, a joystick appears bottom left and Faster, Slower and Jump buttons bottom right; drag on the open screen to look around.

**Stable:** the game opens in your stable. Use the arrows (or ← / →) to look through your six horses, drag to turn the horse around, and press **Ride** (or Enter). The **Stable** button at the top of the riding screen takes you back. The game remembers which horse you picked. To add or change horses, edit the list in `scripts/stable_data.gd`.

**Horse care:** in the stable, the panel on the left shows how full, clean and loved the horse is. **Feed** gives it a carrot, **Pet** gives it a pat, and **Brush** lets you rub the mud off by dragging over the horse (press **Done** to go back to turning it). Riding makes a horse hungry and muddy, and food and love slowly run down while you're away, so come back and look after your horses. The rates are at the top of `scripts/stable_data.gd`.

**Tack:** press **Tack** in the stable to dress the horse you're looking at: saddle pad colour, pad trim, saddle leather, bridle colour and leg wraps (or none). Changes show straight away and each horse keeps its own tack, which it wears when you ride it. The colour lists are at the top of `scripts/tack.gd`.

**Coins and the shop:** riding earns a coin every 50 m, finishing the jumping course earns 15 (40 for a clear round), and finding a new place earns 30. Press **Shop** in the stable to spend them on new horses (buckskin, cremello, dapple grey, two pintos and a spotted appaloosa) and fancy tack colours. Tap anything in the shop to try it on before buying. Prices and rewards are in `scripts/stable_data.gd` and `scripts/tack.gd`.

**Quests:** six people around the countryside need help. Ride up to someone to talk: a gold **!** above their head means they have a quest, and a **?** means your reward is waiting. Lily by the arena wants a clear round, Farmer Tom at the windmill has lost some apples, Rosa at the lake has a letter for Ben at the Wild Horse Meadow (who then wants a gallop), Mia in Flower Valley wants flowers, and Old Sam at the Stone Circle lost a golden horseshoe. Your quests are listed at the top right. People and quests are listed at the top of `scripts/quests.gd`.

**Training:** every horse gets better at what you do with it. Cantering and galloping train **speed** (a faster canter and gallop), jumping trains **jumping** (higher jumps, with extra for clearing a course fence), and riding anywhere trains **stamina** (a longer gallop). Galloping uses up the horse's breath, shown as a blue bar above the gait buttons; when it runs out the horse drops to a canter until it has its breath back. Each skill goes from level 1 to 10, shown under **Training** in the stable. The numbers are at the top of `scripts/stable_data.gd` and `scripts/horse.gd`.

**Competitions:** Judge Clara stands by the arena with a table of cups. Ride up to her to enter **show jumping** (beat the other riders' rounds on the arena course: fewest faults, then fastest time) or the **trail race** (line up with three other riders, then race 700 m along the trail through the numbered sky blue checkpoints). Each has a Bronze, Silver and Gold cup, with better riders in each. Every place wins a rosette and coins, and winning a cup wins its trophy and opens the next cup. Afterwards Judge Clara tells you how you did, with a tip when you didn't win. The **Trophies** button in the stable shows the cups and rosettes you've won. The riders and prizes are at the top of `scripts/competitions.gd`.

**Your rider:** the first time the game starts, you design your rider: girl or boy, skin tone, hairstyle and colour, outfit and riding helmet. Drag to turn the rider around and press **Done**. The **My Rider** button in the stable brings the screen back. Your rider sits on whichever horse you ride.

**Exploring:** a trail loops out from the arena through the countryside, past six places to find: Sparkle Lake, Flower Valley, the Stone Circle, the Old Windmill, the Hilltop Lookout and the Wild Horse Meadow. Places you haven't found yet have a golden light beam over them, so you can spot them from far away. Ride up to one to find it; the count shows under the course status and is saved. The places and the trail are listed at the top of `scripts/world.gd`.

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
| `scripts/tack.gd` | The tack (saddle pad, saddle, stirrups, bridle, reins, leg wraps), built from simple shapes and moved along with the horse; add colours to its lists |
| `scripts/tack_panel.gd` | The stable's Tack panel |
| `scripts/competitions.gd` | Judge Clara, the show jumping and trail race cups, the other riders and the results |
| `scripts/portrait.gd` | A close-up picture of a person's face, for Judge Clara's windows |
| `scripts/trophy_shelf.gd` | The stable's Trophies button and panel |
| `scripts/quests.gd` | The people around the world and their quests, the quest list and the talk box |
| `scripts/shop.gd` | The stable's shop: horses and tack colours to buy with coins |
| `scripts/coin_badge.gd` | The coin counter on the stable and riding screens |
| `scenes/rider_creator.tscn`, `scripts/rider_creator.gd` | The screen where you design your rider |
| `scripts/rider.gd` | The rider: puts the character parts together and poses them; add options to its lists |
| `scripts/rider_data.gd` | How your rider looks, saved between games |
| `assets/rider/` | Character parts (bodies, heads, hair, outfits) from Quaternius |
| `tools/prepare_rider.py` | Copies the character parts out of the Quaternius downloads into `assets/rider/` |
| `tools/saddle_track.py` | Measures where the saddle, bridle and leg wraps sit on the horse in each gait (writes `assets/horse/gaits/saddle_track.json`) |
| `shaders/coat.gdshader` | Recolours the horse's coat and adds mud when it's dirty |
| `scripts/horse.gd` | Gaits, steering, jumping, model loading and the placeholder horse |
| `scripts/world.gd` | Terrain, arena, trail, lake shape, trees, rocks, grass and flowers |
| `scripts/explore.gd`, `shaders/water.gdshader` | The places to discover (lake, windmill, stone circle and the rest) and the lake's water |
| `scripts/course.gd`, `scripts/fence.gd`, `scripts/gate.gd` | Show jumping course, scoring, fences and gates |
| `scripts/follow_camera.gd` | Third-person camera |
| `scripts/hud.gd`, `scripts/virtual_joystick.gd` | On-screen display and touch controls |
| `tests/explore_test.gd` | Automatic test: visits every place and checks it is discovered |
| `tests/ride_test.gd` | Automatic test: rides the course twice and checks scoring and that riding wears the horse out |
| `tests/tack_test.gd` | Automatic test: picks tack, rides through every gait, and checks it is saved and stays on the horse |
| `tests/quest_test.gd` | Automatic test: plays every quest and checks the rewards |
| `tests/competition_test.gd` | Automatic test: wins and loses show jumping and race cups, and checks prizes and trophies |
| `tests/controls_test.gd` | Automatic test: U J H L keys, and clicks to change gait |
| `tests/training_test.gd` | Automatic test: trains a horse and checks it gallops faster, jumps higher and lasts longer |
| `tests/shop_test.gd` | Automatic test: earns coins, buys a horse and a bridle, and checks they are paid for, saved and in the stable |
| `legacy-babylon/` | The earlier Babylon.js web version, kept for reference |

Run the tests with `godot --headless --path . -s tests/ride_test.gd`, `godot --headless --path . -s tests/explore_test.gd` (the explore test resets your found places), `godot --headless --path . -s tests/tack_test.gd`, `godot --headless --path . -s tests/shop_test.gd` `godot --headless --path . -s tests/quest_test.gd` `godot --headless --path . -s tests/training_test.gd` `godot --headless --path . -s tests/competition_test.gd` and `godot --headless --path . -s tests/controls_test.gd`. The tests put your saved coins, purchases, quests, training and competition results back when they finish.
