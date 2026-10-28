# Silver Mane

A horse riding game inspired by Star Stable, made with Godot 4.7 for Windows PC and Android tablets.

This is the first playable prototype: ride a horse around a meadow, switch gaits, and jump a show jumping course in the arena.

## Open and play on PC

1. Install [Godot 4.7](https://godotengine.org/download) (the standard version, not .NET).
2. In the Godot Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

| Key | Action |
| --- | --- |
| U / J or ↑ / ↓ | Ride on / slow down and back up |
| H / K or ← / → | Steer |
| Left click / right click | One gait faster / slower (also Q / E, or 0 to 4 for halt, walk, trot, canter, gallop) |
| Space | Jump (trot or faster) |
| Mouse drag, scroll | Look around, zoom |
| T / R | Move the clock on two hours / change the weather |
| Tab | Open or close the map |
| P | Photo mode (Escape to leave) |

On a tablet, a joystick appears bottom left and Faster, Slower and Jump buttons bottom right; drag on the open screen to look around.

**Stable:** the game opens in your stable, a wooden barn with your horses in their stalls, their names on the doors. The horse you're looking at stands in the aisle. Use the arrows (or ← / →) to look through your six horses, drag to turn the horse around, and press **Ride** (or Enter). The **Stable** button at the top of the riding screen takes you back. The game remembers which horse you picked. To add or change horses, edit the list in `scripts/stable_data.gd`.

**Horse care:** in the stable, the panel on the left shows how full, clean and loved the horse is. **Feed** gives it a carrot, **Pet** gives it a pat, and **Brush** lets you rub the mud off by dragging over the horse (press **Done** to go back to turning it). Riding makes a horse hungry and muddy, and food and love slowly run down while you're away, so come back and look after your horses. The rates are at the top of `scripts/stable_data.gd`.

**Tack:** press **Tack** in the stable to dress the horse you're looking at: saddle pad colour, pad trim, saddle leather, bridle colour and leg wraps (or none). Changes show straight away and each horse keeps its own tack, which it wears when you ride it. The colour lists are at the top of `scripts/tack.gd`.

**Grooming salon:** press **Salon** in the stable to pamper the horse you're looking at: white face markings (star, stripe, blaze or a white face), white socks or stockings, button braids or braids with ribbon bows down the mane, a bow on the tail, ribbon colours, and glitter that twinkles in the light (gold, silver, pink or rainbow). Each horse keeps its own look, in its stall and when you ride. The fancier ones are bought in the shop's **Salon** tab. The lists are at the top of `scripts/tack.gd`.

**Coins and the shop:** riding earns a coin every 50 m, finishing the jumping course earns 15 (40 for a clear round), and finding a new place earns 30. Press **Shop** in the stable to spend them on new horses (buckskin, cremello, dapple grey, two pintos and a spotted appaloosa) and fancy tack colours. Tap anything in the shop to try it on before buying. Prices and rewards are in `scripts/stable_data.gd` and `scripts/tack.gd`.

**Names:** press **Rename** next to a horse's name in the stable to give it a new name; a horse you buy asks for its name straight away. Names show everywhere, from the stall plates to Judge Clara's results.

**Breeds and foals:** every horse has a breed (warmblood, Welsh pony, Fjord, Friesian, Arabian, Gypsy cob and more), drawn at that breed's size and build: ponies are small and stocky, thoroughbreds tall and slim. The shop also sells foals. A foal can't be ridden yet: it grows a little bigger every hour (also while the game is closed, and faster when it's well looked after), each carrot helps, and after about six hours it's grown up and ready to ride. Breeds are listed in `scripts/stable_data.gd`.

**Sounds and music:** a gentle harp tune plays throughout. While you ride you hear hoofbeats in time with the horse's legs (soft on grass, clopping on the trail, hushed in the arena sand, crunching in the snow, splashing in the lake), snorts and whinnies, and the thump of landing a jump. Around you there's wind, birdsong by day, crickets at night, rain when it rains and waves by the sea. In the stable a carrot crunches and your horse nickers when you pat it. Every sound and the music are made from scratch by `tools/make_sounds.py` (run it with Python to remake them), so there are no recordings to credit.

**The beach:** follow the path that branches east off the trail down to the sea. Waves wash up the sand and foam rolls in, palms lean over the dunes and seagulls circle overhead. Three new places to find: **Seashell Cove** (a rock pool, a beach hut and shells everywhere), the **Old Shipwreck** lying in the shallows, and **Lighthouse Point**, whose lamp sweeps round at night. Marina at the cove wants 6 seashells from along the water's edge, and Keeper Finn by the lighthouse lost his spyglass near the wreck. The beach's shape is `coast_x()` in `scripts/world.gd`.

**Daily surprises and stickers:** every day brings three small tasks, like feeding three carrots, riding a kilometre or jumping five times. Press **Today** at the top of the stable to see them and how far along each is. Each task done earns coins and a new sticker, with a little note wherever you are, and once all three are done the surprise box opens for 50 more coins and a shiny gold rare sticker. Press **Stickers** to see your sticker book: 30 to collect. New tasks come the next day. The tasks are listed at the top of `scripts/daily.gd`.

**Quests:** six people around the countryside need help. Ride up to someone to talk: a gold **!** above their head means they have a quest, and a **?** means your reward is waiting. Lily by the arena wants a clear round, Farmer Tom at the windmill has lost some apples, Rosa at the lake has a letter for Ben at the Wild Horse Meadow (who then wants a gallop), Mia in Flower Valley wants flowers, and Old Sam at the Stone Circle lost a golden horseshoe. On the beach, Marina wants seashells and Keeper Finn has lost his spyglass. Up in the mountains, Heidi at the hut needs firewood and Ranger Lars's scarf has blown away. Coach Anna by the arena gives three riding lessons (walk, trot and halt; canter; jumping): follow the blue cones in the gait she asks for. Your quests are listed at the top right. People and quests are listed at the top of `scripts/quests.gd`.

**Training:** every horse gets better at what you do with it. Cantering and galloping train **speed** (a faster canter and gallop), jumping trains **jumping** (higher jumps, with extra for clearing a course fence), and riding anywhere trains **stamina** (a longer gallop). Galloping uses up the horse's breath, shown as a blue bar above the gait buttons; when it runs out the horse drops to a canter until it has its breath back. Each skill goes from level 1 to 10, shown under **Training** in the stable. The numbers are at the top of `scripts/stable_data.gd` and `scripts/horse.gd`.

**Bonding:** your horse's hearts (up to five) and mood show under the coins while you ride. Hearts grow with carrots, brushing, pats, rides, quests and tricks. With enough hearts your horse learns tricks: **Bow** at one heart, **Spin** at two and **Rear** at three. Stop, then press the trick's button (or B, N, V). A grumpy horse won't do tricks, so look after it first. Press **Get off** (G) at a halt to walk about with the same keys; your horse grazes and strolls nearby. Press **Whistle** (F) and it trots over to you, then **Get on** (G). The stable panel shows the hearts too, with trick buttons. The numbers are at the top of `scripts/stable_data.gd`.

**Competitions:** Judge Clara stands by the arena with a table of cups. Ride up to her to enter **show jumping** (beat the other riders' rounds on the arena course: fewest faults, then fastest time), the **trail race** (line up with three other riders, then race 700 m along the trail through the numbered sky blue checkpoints), **dressage** or **cross-country**. In dressage the jumps clear out of the arena and you ride a test from letter to letter (A, K, E, H, C, M, B, F round the fence and X in the middle): ride through each pink ring in the gait shown, and halt at X at the end. Each movement scores marks for the right gait, riding right through the letter and going straight there, and a well-bonded horse earns a harmony bonus. Cross-country is a course of nine natural jumps out along the trail east of the arena (logs, a jump into a splash of water, hay bales, a brush hedge, a stone wall and more), each between a red flag on the right and a white one on the left. A jump too low is a refusal (20 penalties, and you try again), riding past beside it is a run-out (20 penalties), and every second over the optimum time adds 0.4. The jumps stay out there, so you can practise them any time. Each has a Bronze, Silver and Gold cup, with better riders in each. Every place wins a rosette and coins, and winning a cup wins its trophy and opens the next cup. Afterwards Judge Clara tells you how you did, with a tip when you didn't win. The **Trophies** button in the stable shows the cups and rosettes you've won. The riders and prizes are at the top of `scripts/competitions.gd`.

**Your rider:** the first time the game starts, you design your rider: girl or boy, skin tone, hairstyle and colour, outfit and riding helmet. Drag to turn the rider around and press **Done**. The **My Rider** button in the stable brings the screen back. Your rider sits on whichever horse you ride.

**Snowy mountains:** a path branches north off the trail near the Hilltop Lookout and climbs through a pass in the hills (look for the signpost). Beyond it the grass gives way to snow: a valley ringed by high peaks, with snowy pines, poles with red tops marking the track, and snow drifting down (when it rains in the meadows it snows up here). Three new places to find: the **Frozen Lake** (you can ride out on the ice), the **Mountain Hut**, a log cabin with smoke from the chimney, windows that glow at night and a snowman outside, and the **Frozen Falls**, a waterfall frozen down a cliff at the end of the valley. The mountains' shape is `_mountain_height()` in `scripts/world.gd`.

**Map:** press **Map** at the top of the riding screen (or Tab) to see the whole countryside from above: the trail, hills, lake, arena, woods, beach and the snowy mountains to the north. Places you've found are gold stars with their names, places still to find are question marks, people with a quest for you have a **!** (or a **?** when your reward is waiting), the purple dot is Judge Clara, and the arrow is you. The game waits while the map is open.

**Photo mode:** press **Photo** (or P) to stop time and take pictures of your horse. Drag to move the camera around the horse, scroll (or pinch, or press − and +) to go closer, and pick a look: as it is, golden, black and white, dreamy or old photo. Press **Take photo** to save it. On PC photos go in your Pictures folder under *Silver Mane*; on the tablet they're kept in the game. **Album** shows your photos.

**Exploring:** a trail loops out from the arena through the countryside, past six places to find: Sparkle Lake, Flower Valley, the Stone Circle, the Old Windmill, the Hilltop Lookout and the Wild Horse Meadow. Three more are down on the beach, and three up in the snowy mountains. Places you haven't found yet have a golden light beam over them, so you can spot them from far away. Ride up to one to find it; the count shows under the course status and is saved. The places and the trail are listed at the top of `scripts/world.gd`.

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
| `scenes/title.tscn`, `scripts/title.gd` | The title screen: your horse and rider in the evening sun, with Play, Settings and Quit. The game's name is **Application > Config > Name** in Project Settings |
| `scripts/settings.gd`, `scripts/settings_panel.gd` | Music and sound volume, graphics quality (Low, Medium, High), keyboard help and full screen, saved between games; the Settings window is on the title screen and in the stable |
| `scenes/main.tscn` | The game scene: sky and lighting, world, horse, camera, course, HUD |
| `scenes/stable.tscn`, `scripts/stable.gd` | The stable screen where you pick a horse |
| `scripts/stable_barn.gd` | The stable building: aisle, stalls with your horses in them, lanterns, hay and tack |
| `scripts/stable_data.gd` | Your horses (names and coat colours), which one you ride, and how well each is looked after |
| `scripts/horse_care.gd` | Feeding, brushing and petting in the stable |
| `scripts/tack.gd`, `shaders/tack.gdshader` | The tack (quilted saddle pad with piping, saddle with flaps, knee rolls and girth, stirrups, stitched bridle, curved reins, bandage leg wraps), shaped to the horse in code and moved along with it; add colours to its lists |
| `scripts/tack_panel.gd` | The stable's Tack and Salon panels |
| `scripts/competitions.gd` | Judge Clara, the show jumping, trail race, dressage and cross-country cups, the other riders and the results |
| `scripts/dressage.gd` | The dressage letters round the arena, the tests for each cup and their marks |
| `scripts/cross_country.gd` | The cross-country jumps along the trail, the water splash, refusals, run-outs and time penalties |
| `scripts/portrait.gd` | A close-up picture of a person's face, for Judge Clara's windows |
| `scripts/trophy_shelf.gd` | The stable's Trophies button and panel |
| `scripts/daily.gd`, `scripts/daily_panel.gd`, `scripts/stickers.gd` | Daily surprises: the Daily autoload picks the day's tasks and hands out coins and stickers, the panel is the stable's Today and Stickers screens, and the stickers are drawn in code |
| `scripts/quests.gd` | The people around the world and their quests, the quest list and the talk box |
| `scripts/shop.gd` | The stable's shop: horses and tack colours to buy with coins |
| `scripts/coin_badge.gd` | The coin counter on the stable and riding screens |
| `scenes/rider_creator.tscn`, `scripts/rider_creator.gd` | The screen where you design your rider |
| `scripts/rider.gd` | The rider: puts the character parts together and poses them; add options to its lists |
| `scripts/rider_data.gd` | How your rider looks, saved between games |
| `assets/rider/` | Character parts (bodies, heads, hair, outfits) from Quaternius |
| `tools/prepare_rider.py` | Copies the character parts out of the Quaternius downloads into `assets/rider/` |
| `tools/saddle_track.py` | Measures where the saddle, bridle and leg wraps sit on the horse in each gait (writes `assets/horse/gaits/saddle_track.json`) |
| `shaders/coat.gdshader` | Recolours the horse's coat with a satin sheen, makes the eyes glassy, hides the model's own tail, paints white markings and glitter, and adds mud when it's dirty |
| `scripts/hair.gd`, `shaders/hair.gdshader` | The horse's mane, forelock and tail: strands of hair that lie along the neck, hang down the model's own (hidden) tail, and swing as the horse moves |
| `tools/groom_track.py` | Measures where braids, the tail bow and the hair go in each gait, and paints the map of where face and leg markings can be (writes `assets/horse/gaits/groom_track.json` and `markings.png`) |
| `scripts/horse.gd` | Gaits, steering, jumping, model loading and the placeholder horse |
| `scripts/world.gd` | Terrain, arena, trail, lake shape, where trees and bushes grow, rocks and wildflowers |
| `scripts/trees.gd`, `shaders/foliage.gdshader`, `shaders/bark.gdshader` | Trees and bushes made in code: oak, birch, pine, poplar, willow, blossom and autumn trees, plain and flowering bushes, with leaves that sway |
| `scripts/sky_cycle.gd`, `shaders/sky.gdshader` | Day and night (a day lasts 12 minutes), sunrise and sunset, moon, stars and fireflies, clouds, rain and rainbows |
| `scripts/mountains.gd`, `shaders/ice.gdshader` | The snowy mountains: the Frozen Lake's ice, the Mountain Hut and its snowman, the Frozen Falls, the track's poles, the signpost at the pass and falling snow |
| `scripts/beach.gd`, `shaders/sea.gdshader` | The beach: the sea and its waves, palms, rocks and driftwood, Seashell Cove, the Old Shipwreck, Lighthouse Point and seagulls |
| `scripts/bonding.gd`, `scripts/on_foot.gd`, `scripts/hearts.gd` | Bonding while you ride: hearts and mood, tricks at a halt, getting off to walk and whistling your horse over |
| `scripts/sound.gd`, `scripts/ambience.gd`, `assets/audio/`, `tools/make_sounds.py` | Music and sounds: the Sound autoload plays them, the Ambience node does hoofbeats and outdoor sounds while riding, and the tool makes the sound files |
| `scripts/grass.gd`, `shaders/grass.gdshader`, `shaders/wind.gdshaderinc` | Grass that grows around the camera and sways in the wind (fewer, closer blades on tablets) |
| `shaders/terrain.gdshader`, `shaders/ground.gdshaderinc`, `shaders/flower.gdshader` | The ground's painted patches, grain and bumps; the wildflowers |
| `scripts/explore.gd`, `shaders/water.gdshader`, `shaders/flag.gdshader` | The places to discover (lake, windmill, stone circle and the rest), the lake's water and the lookout's flag |
| `scripts/rocks.gd`, `shaders/rock.gdshader` | Lumpy, mossy rocks and standing stones made in code |
| `scripts/course.gd`, `scripts/fence.gd`, `scripts/gate.gd` | Show jumping course, scoring, fences and gates |
| `scripts/follow_camera.gd` | Third-person camera |
| `scripts/world_map.gd` | The map: the countryside drawn from above, with places, people and you |
| `scripts/photo_mode.gd`, `shaders/photo_filter.gdshader` | Photo mode: its own camera around the horse, the looks, saving photos and the album |
| `scripts/hud.gd`, `scripts/virtual_joystick.gd` | On-screen display and touch controls |
| `tests/mountains_test.gd` | Automatic test: canters through the pass into the valley, checks the track is gentle, snow falls (and rain turns to snow), and hooves crunch in the snow and clop on the ice |
| `tests/map_photo_test.gd` | Automatic test: opens and closes the map and photo mode, and checks the map's places, the photo camera and the looks |
| `tests/explore_test.gd` | Automatic test: visits every place and checks it is discovered |
| `tests/bonding_test.gd` | Automatic test: hearts grow with care, tricks unlock and play, and a whistle brings the horse over |
| `tests/sound_test.gd` | Automatic test: every sound loads, hoofbeats keep time and splash in water, and caring for the horse makes its sounds |
| `tests/ride_test.gd` | Automatic test: rides the course twice and checks scoring and that riding wears the horse out |
| `tests/tack_test.gd` | Automatic test: picks tack, rides through every gait, and checks it is saved and stays on the horse |
| `tests/salon_test.gd` | Automatic test: buys a marking, grooms the horse, rides through every gait, and checks the markings, braids and bow show and stay on |
| `tests/quest_test.gd` | Automatic test: plays every quest and checks the rewards |
| `tests/dressage_xc_test.gd` | Automatic test: wins a dressage test ridden neatly and loses a sloppy one, wins the cross-country clear and fast, and checks refusals, run-outs and time penalties |
| `tests/competition_test.gd` | Automatic test: wins and loses show jumping and race cups, and checks prizes and trophies |
| `tests/controls_test.gd` | Automatic test: U J H K keys, and clicks to change gait |
| `tests/daily_test.gd` | Automatic test: the day's tasks, finishing them for coins and stickers, the surprise box and the sticker book |
| `tests/day_night_test.gd` | Automatic test: noon, sunset, night, rain and a rainbow |
| `tests/settings_test.gd` | Automatic test: the title screen, and settings being applied and saved |
| `tests/names_test.gd` | Automatic test: renames a horse, checks the name shows and is saved, and that a bought foal asks for a name |
| `tests/breeds_test.gd` | Automatic test: breed sizes, and a foal growing up until it can be ridden |
| `tests/training_test.gd` | Automatic test: trains a horse and checks it gallops faster, jumps higher and lasts longer |
| `tests/stable_test.gd` | Automatic test: checks your horses stand in their stalls and the one in the aisle's stall is empty |
| `tests/shop_test.gd` | Automatic test: earns coins, buys a horse and a bridle, and checks they are paid for, saved and in the stable |
| `legacy-babylon/` | The earlier Babylon.js web version, kept for reference |

Run the tests with `godot --headless --path . -s tests/ride_test.gd`, `godot --headless --path . -s tests/explore_test.gd` (the explore test resets your found places), `godot --headless --path . -s tests/tack_test.gd`, `godot --headless --path . -s tests/salon_test.gd`, `godot --headless --path . -s tests/shop_test.gd` `godot --headless --path . -s tests/quest_test.gd` `godot --headless --path . -s tests/training_test.gd` `godot --headless --path . -s tests/competition_test.gd` `godot --headless --path . -s tests/controls_test.gd`, `godot --headless --path . -s tests/stable_test.gd`, `godot --headless --path . -s tests/breeds_test.gd`, `godot --headless --path . -s tests/names_test.gd`, `godot --headless --path . -s tests/settings_test.gd` `godot --headless --path . -s tests/day_night_test.gd` `godot --headless --path . -s tests/map_photo_test.gd` `godot --headless --path . -s tests/mountains_test.gd` `godot --headless --path . -s tests/dressage_xc_test.gd` and `godot --headless --path . -s tests/daily_test.gd`. The tests put your saved coins, purchases, quests, training, competition results and stickers back when they finish.
