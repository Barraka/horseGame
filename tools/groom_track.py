"""Measure what the grooming salon needs from each gait clip.

1. Where the braids and hair go: points along the top of the neck (the
   crest, from withers to poll), the top of the tail, and down the middle
   of the model's own tail (tail_0 at the root to tail_5 at the tip, which
   scripts/hair.gd hangs the new tail along), followed frame by frame like
   tools/saddle_track.py does for the saddle. Written to
   assets/horse/gaits/groom_track.json for scripts/horse.gd.
2. A markings map, painted in the horse texture's own layout (UV space,
   which all three files share; measured on the walk, standing square), so white face markings and socks can be drawn by
   shaders/coat.gdshader without touching the horse's texture files:
     red   how squarely the spot faces forward on the front of the face
           (1 down the middle of the face, 0 off the face),
     green how far down the face, from the poll (0) to the nose (1),
     blue  height up the leg (0.5 at the knee or hock, 1 off the legs),
     alpha 0.25 on a front leg, 0.75 on a hind leg, 1 elsewhere.
   Written to assets/horse/gaits/markings.png.

Usage: python3 tools/groom_track.py   (after tools/saddle_track.py)
"""
import json
import struct
import zlib
from pathlib import Path

import numpy as np

from saddle_track import CLIPS, GAITS, TYPES, SIZES, components, load

BRAIDS = 7          # Button braids along the crest
TAIL_POINTS = 6     # Down the middle of the tail
# The tail's island in the texture (u from, v from, u to, v to).
TAIL_ISLAND = (0.355, 0.85, 0.64, 1.0)
SIZE = 512          # Markings map size in pixels


def load_uv(path):
    """The animated mesh's texture coordinates and triangles."""
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
    node = gltf["nodes"][anim["channels"][0]["target"]["node"]]
    prim = gltf["meshes"][node["mesh"]]["primitives"][0]
    uv = accessor(prim["attributes"]["TEXCOORD_0"]).astype(float)
    triangles = accessor(prim["indices"]).reshape(-1, 3).astype(int)
    return uv, triangles


def crest_vertices(first, withers, crown):
    """A vertex on top of the neck at each braid, withers to poll."""
    axis = crown - withers
    length = np.linalg.norm(axis)
    axis /= length
    up = np.array([0.0, 1.0, 0.0]) - axis[1] * axis
    up /= np.linalg.norm(up)
    rel = first - withers
    along = rel @ axis
    lift = rel @ up
    sideways = np.linalg.norm(rel - np.outer(along, axis) - np.outer(lift, up), axis=1)
    chosen = []
    for f in np.linspace(0.14, 0.8, BRAIDS):
        sel = np.where((np.abs(along - f * length) < 0.35) & (sideways < 0.9))[0]
        chosen.append(int(sel[np.argmax(lift[sel])]))
    return chosen


def dock_vertex(first, croup, fwd, side):
    """The top of the tail, where it leaves the rump (about 25 cm behind
    the croup, on the top line)."""
    behind = croup[fwd] - first[:, fwd]
    sel = np.where((np.abs(first[:, side] - croup[side]) < 0.6) & (np.abs(behind - 2.9) < 0.35))[0]
    return int(sel[np.argmax(first[sel, 1])])


def tail_spine(first, uv, triangles, dock):
    """Groups of tail vertices from the root to the tip: the tail is the
    piece of its texture island that touches the dock, cut into slices by
    how far each vertex is from the dock."""
    lo_u, lo_v, hi_u, hi_v = TAIL_ISLAND
    island = np.where((uv[:, 0] > lo_u) & (uv[:, 0] < hi_u) & (uv[:, 1] > lo_v) & (uv[:, 1] < hi_v))[0]
    pieces = [np.array(p) for p in components(island, triangles)]
    tail = min(pieces, key=lambda p: np.linalg.norm(first[p] - dock, axis=1).min())
    reach = np.linalg.norm(first[tail] - dock, axis=1)
    edges = np.linspace(0.0, reach.max() + 1e-6, TAIL_POINTS + 1)
    return [tail[(reach >= edges[i]) & (reach < edges[i + 1])] for i in range(TAIL_POINTS)]


def face_and_legs(first, track, fwd, side):
    """Each vertex's markings values (see the top of this file)."""
    n = len(first)
    values = np.zeros((n, 4))
    values[:, 2] = 1.0
    values[:, 3] = 1.0
    # Face: along the head from the poll to the nose, and how squarely each
    # spot faces the front (the side of the head away from the jaw).
    crown = np.array(track["crown"][0])
    nose = np.array(track["nose"][0])
    axis = nose - crown
    length = np.linalg.norm(axis)
    axis /= length
    front = np.zeros(3)
    front[fwd] = 1.0
    front = front + np.array([0.0, 1.0, 0.0])
    front -= (front @ axis) * axis
    front /= np.linalg.norm(front)
    across = np.cross(axis, front)
    rel = first - crown
    along = rel @ axis / length
    out = rel @ front
    wide = rel @ across
    radius = np.hypot(out, wide)
    facing = out / np.maximum(radius, 1e-6)
    head = (along > -0.1) & (along < 1.1) & (radius < 1.6) & (facing > 0)
    values[head, 0] = facing[head]
    values[:, 1] = np.clip(along, 0, 1)
    # Legs: height up the leg, measured against the knee (or hock).
    for leg in ("fl", "fr", "hl", "hr"):
        low = np.array(track[leg + "_low"][0])
        high = np.array(track[leg + "_high"][0])
        reach = max(track[leg + "_high_radius"], track[leg + "_low_radius"]) * 2.4
        flat = first[:, [fwd, side]]
        near = np.linalg.norm(flat - low[[fwd, side]], axis=1) < reach + 0.4
        near |= np.linalg.norm(flat - high[[fwd, side]], axis=1) < reach
        near &= first[:, 1] < high[1] * 1.6
        knee = high[1] * 1.15
        values[near, 2] = np.minimum(values[near, 2], first[near, 1] / knee * 0.5)
        values[near, 3] = 0.25 if leg[0] == "f" else 0.75
    return values


def paint(uv, triangles, values):
    """Rasterise the per-vertex values into a map in UV space."""
    image = np.zeros((SIZE, SIZE, 4))
    filled = np.zeros((SIZE, SIZE), bool)
    px = uv * SIZE
    px[:, 1] = uv[:, 1] * SIZE   # glTF UVs: v grows downward, like the image rows
    for tri in triangles:
        p = px[tri]
        lo = np.floor(p.min(0)).astype(int)
        hi = np.ceil(p.max(0)).astype(int)
        lo = np.clip(lo, 0, SIZE - 1)
        hi = np.clip(hi, 0, SIZE - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1) + 0.5, np.arange(lo[1], hi[1] + 1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9:
            continue
        w0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        w1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        v = w0[..., None] * values[tri[0]] + w1[..., None] * values[tri[1]] + w2[..., None] * values[tri[2]]
        cols = xs[inside].astype(int)
        rows = ys[inside].astype(int)
        # Keep the value nearest a marking where islands overlap.
        image[rows, cols] = v[inside]
        filled[rows, cols] = True
    # Spread each island's edge outward so filtering doesn't bleed at seams.
    for _ in range(4):
        grown = image.copy()
        got = filled.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(image, dy, 0), dx, 1)
            have = np.roll(np.roll(filled, dy, 0), dx, 1) & ~got
            grown[have] = src[have]
            got |= have
        image, filled = grown, got
    image[~filled] = [0, 0, 1, 1]
    return (np.clip(image, 0, 1) * 255 + 0.5).astype(np.uint8)


def write_png(path, rgba):
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    saddle = json.loads((GAITS / "saddle_track.json").read_text())
    out = {}
    for name, (fwd, side, root_motion, marks) in CLIPS.items():
        times, frames = load(GAITS / name)
        first = frames[0]
        track = saddle[name]
        crest = crest_vertices(first, np.array(track["withers"][0]), np.array(track["crown"][0]))
        dock = dock_vertex(first, np.array(track["croup"][0]), fwd, side)
        points = {}
        for i, vertex in enumerate(crest):
            points["crest_%d" % i] = [[round(float(v), 3) for v in frame[vertex]] for frame in frames]
        points["dock"] = [[round(float(v), 3) for v in frame[dock]] for frame in frames]
        uv, triangles = load_uv(GAITS / name)
        for i, group in enumerate(tail_spine(first, uv, triangles, first[dock])):
            points["tail_%d" % i] = [[round(float(v), 3) for v in frame[group].mean(0)] for frame in frames]
        out[name] = points
        if name == "horse_walk.glb":
            write_png(GAITS / "markings.png", paint(uv, triangles, face_and_legs(first, track, fwd, side)))
            print("wrote", GAITS / "markings.png")
    (GAITS / "groom_track.json").write_text(json.dumps(out))
    print("wrote", GAITS / "groom_track.json")


if __name__ == "__main__":
    main()
