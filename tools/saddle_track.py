"""Measure where the saddle, bridle and leg wraps sit on each gait clip,
frame by frame.

The gait files animate the horse with blend shapes, so there is no bone for
the rider or the tack to follow. This finds three points along the horse's
back (croup, seat and withers), four on the head (nose, muzzle, cheek and
crown)
and two on each leg (fetlock and cannon), and records where they move in
every frame, in the file's own units, into
assets/horse/gaits/saddle_track.json for scripts/horse.gd. Head and leg
points are the middle of a small patch of the mesh, so they sit inside the
head or leg; legs get their thickness and the head its width and height.

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


def load_triangles(path):
    """The mesh's triangles, as rows of three vertex indices."""
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    start = 20 + length + 8
    anim = gltf["animations"][0]
    node = gltf["nodes"][anim["channels"][0]["target"]["node"]]
    prim = gltf["meshes"][node["mesh"]]["primitives"][0]
    acc = gltf["accessors"][prim["indices"]]
    view = gltf["bufferViews"][acc["bufferView"]]
    arr = np.frombuffer(data, TYPES[acc["componentType"]], acc["count"],
                        start + view.get("byteOffset", 0) + acc.get("byteOffset", 0))
    return arr.reshape(-1, 3).astype(int)


def components(vertices, triangles):
    """Split a set of vertex indices into connected pieces of the mesh."""
    inside = np.zeros(triangles.max() + 1, bool)
    inside[vertices] = True
    parent = {v: v for v in vertices}

    def root(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for tri in triangles:
        kept = [v for v in tri if inside[v]]
        for a, b in zip(kept, kept[1:]):
            parent[root(a)] = root(b)
    groups = {}
    for v in vertices:
        groups.setdefault(root(v), []).append(v)
    return sorted(groups.values(), key=len, reverse=True)


def head_patches(frame, fwd, side):
    """Vertex patches for the nose, cheek and crown, picked in one frame."""
    high = frame[:, 1] > frame[:, 1].max() * 0.55
    tip = frame[high, fwd].max()
    nose = np.where(high & (frame[:, fwd] > tip - 0.8))[0]
    band = np.where(high & (np.abs(frame[:, fwd] - (tip - 3.6)) < 0.4))[0]
    crown = band[frame[band, 1] > np.percentile(frame[band, 1], 85)]
    muzzle = np.where(high & (np.abs(frame[:, fwd] - (tip - 1.6)) < 0.3))[0]
    return {"nose": nose, "cheek": band, "crown": crown, "muzzle": muzzle}


def head_size(frame, verts, side):
    """Half the width and half the height of the head across a patch."""
    width = np.percentile(frame[verts, side], 95) - np.percentile(frame[verts, side], 5)
    height = np.percentile(frame[verts, 1], 97) - np.percentile(frame[verts, 1], 3)
    return [round(float(width) / 2, 3), round(float(height) / 2, 3)]


def leg_patches(frames, triangles, fwd, side):
    """Vertex patches on each leg: around the fetlock and up the cannon.

    Legs are the pieces of mesh below the belly. The frame where the four
    legs reach furthest down and stand straightest is used to pick them."""
    best = None
    for f in range(0, len(frames), 2):
        frame = frames[f]
        belly = frame[:, 1].max() * 0.36
        legs = components(np.where(frame[:, 1] < belly)[0], triangles)[:4]
        if len(legs) < 4:
            continue
        score = min(np.ptp(frame[leg, 1]) for leg in legs)
        if best is None or score > best[0]:
            best = (score, f, legs)
    _, f, legs = best
    frame = frames[f]
    # The two legs furthest forward are the front legs. The horse's left is
    # +X when it faces +Z, and -Z when it faces +X.
    order = sorted(legs, key=lambda leg: frame[leg, fwd].mean())
    left_sign = 1.0 if fwd == 2 else -1.0
    patches = {}
    for i, leg in enumerate(order):
        leg = np.array(leg)
        pair = order[2:] if i >= 2 else order[:2]
        other = np.array(pair[1] if pair[0] is order[i] else pair[0])
        is_left = (frame[leg, side].mean() - frame[other, side].mean()) * left_sign > 0
        name = ("f" if i >= 2 else "h") + ("l" if is_left else "r")
        y = frame[leg, 1]
        low, top = y.min(), y.max()
        span = top - low
        patches[name + "_low"] = leg[(y > low + span * 0.16) & (y < low + span * 0.26)]
        patches[name + "_high"] = leg[(y > low + span * 0.5) & (y < low + span * 0.62)]
    return patches


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
        triangles = load_triangles(GAITS / name)
        patches = head_patches(first, fwd, side)
        patches.update(leg_patches(frames, triangles, fwd, side))
        for mark, verts in patches.items():
            centres = frames[:, verts].mean(axis=1)
            points[mark] = [[round(float(v), 3) for v in c] for c in centres]
            if mark.endswith("_low") or mark.endswith("_high"):
                # How thick the leg is there (median distance from the middle).
                radius = np.median(np.linalg.norm(frames[0, verts] - centres[0], axis=1))
                points[mark + "_radius"] = round(float(radius), 3)
            elif mark in ("cheek", "muzzle"):
                points[mark + "_size"] = head_size(first, verts, side)
        if "--profile" in sys.argv:
            print(name, {k: len(v) for k, v in patches.items()})
        track[name] = {"times": [round(float(t), 4) for t in times], **points}
    (GAITS / "saddle_track.json").write_text(json.dumps(track))
    print("wrote", GAITS / "saddle_track.json")


if __name__ == "__main__":
    main()
