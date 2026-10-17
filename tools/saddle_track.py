"""Measure where the saddle sits on each gait clip, frame by frame.

The gait files animate the horse with blend shapes, so there is no bone for
the rider to follow. This finds three points along the horse's back (croup,
seat and withers) and records where they move in every frame, in the file's
own units, into assets/horse/gaits/saddle_track.json for scripts/horse.gd.

Usage: python3 tools/saddle_track.py [--profile]
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

GAITS = Path(__file__).resolve().parent.parent / "assets" / "horse" / "gaits"
# forward axis, sideways axis, how fast the clip travels forward (units/s),
# and the forward position of the croup, seat and withers on the back line.
CLIPS = {
    "horse_walk.glb": (2, 0, 0.0, {"croup": -4.0, "seat": 1.0, "withers": 5.5}),
    "horse_trot.glb": (2, 0, 0.0, {"croup": -4.0, "seat": 1.0, "withers": 5.5}),
    "horse_run.glb": (0, 2, 77.1, {"croup": -7.5, "seat": -3.5, "withers": 2.5}),
}
TYPES = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}
SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    start = 20 + length + 8

    def accessor(i):
        acc = gltf["accessors"][i]
        view = gltf["bufferViews"][acc["bufferView"]]
        n = SIZES[acc["type"]]
        arr = np.frombuffer(data, TYPES[acc["componentType"]], acc["count"] * n,
                            start + view.get("byteOffset", 0) + acc.get("byteOffset", 0))
        return arr.reshape(acc["count"], n) if n > 1 else arr

    anim = gltf["animations"][0]
    sampler = anim["samplers"][anim["channels"][0]["sampler"]]
    node = gltf["nodes"][anim["channels"][0]["target"]["node"]]
    prim = gltf["meshes"][node["mesh"]]["primitives"][0]
    base = accessor(prim["attributes"]["POSITION"]).astype(float)
    targets = np.stack([accessor(t["POSITION"]) for t in prim["targets"]])
    times = accessor(sampler["input"]).astype(float)
    weights = accessor(sampler["output"]).reshape(len(times), len(targets))
    return times, base[None] + np.einsum("fk,kvc->fvc", weights, targets)


def main():
    track = {}
    for name, (fwd, side, root_motion, marks) in CLIPS.items():
        times, frames = load(GAITS / name)
        steady = frames.copy()
        steady[:, :, fwd] -= (root_motion * times)[:, None]
        first = steady[0]
        on_spine = np.abs(first[:, side]) < 0.6
        if "--profile" in sys.argv:
            for f in np.arange(-8, 12, 1.0):
                sel = on_spine & (np.abs(first[:, fwd] - f) < 0.5)
                if sel.any():
                    print(name, "forward %5.1f  back height %.2f" % (f, first[sel, 1].max()))
        points = {}
        for mark, f in marks.items():
            sel = np.where(on_spine & (np.abs(first[:, fwd] - f) < 0.5))[0]
            vertex = sel[np.argmax(first[sel, 1])]
            points[mark] = [[round(float(v), 3) for v in frame[vertex]] for frame in frames]
        track[name] = {"times": [round(float(t), 4) for t in times], **points}
    (GAITS / "saddle_track.json").write_text(json.dumps(track))
    print("wrote", GAITS / "saddle_track.json")


if __name__ == "__main__":
    main()
