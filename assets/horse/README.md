The horse comes as a gait set in `gaits/`: one file per gait, all the same horse.

| File | Used for |
| --- | --- |
| `horse_walk.glb` | Halt (paused) and walk |
| `horse_trot.glb` | Trot |
| `horse_run.glb` | Canter (slowed down), gallop, and the moment of flight over a jump |

The files are animated with blend shapes (no skeleton) and are licensed
CC BY-ND, which means they must not be edited. `scripts/horse.gd` lines them
up as they are, using the measurements in its `GAIT_SET` table.

Without the gait set the game falls back to a single model at
`assets/horse/horse.glb` (animations matched by name: idle, walk, trot,
canter, gallop, jump), then to the built-in placeholder horse. If a single
model rides backwards or looks the wrong size, select the Horse node in
`scenes/main.tscn` and change `Model Yaw Offset` (try 180) or `Model Length`.

Remember to add each model's authors and licence to CREDITS.md.
