"""Measure what the grooming salon needs from each gait clip.

1. Where the braids and hair go: points along the top of the neck (the
   crest, from withers to poll), the top of the tail, and down the middle
   of the model's own tail (tail_0 at the root to tail_5 at the tip, which
   scripts/hair.gd hangs the new tail along), followed frame by frame like
   tools/saddle_track.py does for the saddle. Also where the bridle lies:
   loops round the head for the noseband (noseband_0..) and the crownpiece
   with its throatlatch (headpiece_0..), the arc of the browband
   (brow_0..), where the cheekpieces start (cheek_top_l/_r) and where the
   bit sits (bit_l/_r), all just off the skin. Written to
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
UNITS = 24.6 / 2.6  # Model units in a metre (horse.gd GAIT_SET_LENGTH, model_length)
# Each eyeball is painted with one spot of the texture; the spots differ
# between the three files (coat.gdshader EYES).
EYE_UVS = np.array([[0.5667, 0.2139], [0.6070, 0.7557], [0.3083, 0.9557], [0.9668, 0.1476]])
LOOP_POINTS = 24    # Round each bridle loop
# Where the bridle goes, in metres along the head from between the eyes
# towards the nose (behind the eyes is negative).
NOSEBAND_AT = 0.17
HEADPIECE_AT = -0.22
HEADPIECE_TILT = 0.52   # The crownpiece leans back over the poll, behind the ears
BROW_AT = -0.17
BIT_AT = 0.31
STRAP_OFF = 0.007   # How far off the skin the straps lie, in metres
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


def head_frame(first, uv, triangles, nose):
    """A frame that turns with the head: the point between the eyes, the
    way to the nose, up through the forehead, and across from eye to eye."""
    eye = np.where(np.min(np.linalg.norm(uv[:, None] - EYE_UVS[None], axis=2), axis=1) < 0.002)[0]
    centre = first[eye].mean(0)
    axis = np.linalg.svd(first[eye] - centre)[2][0]
    one = (first[eye] - centre) @ axis > 0
    mid = centre
    across = first[eye[one]].mean(0) - first[eye[~one]].mean(0)
    across /= np.linalg.norm(across)
    ahead = nose - mid
    ahead -= across * (ahead @ across)
    ahead /= np.linalg.norm(ahead)
    up = np.cross(across, ahead)
    # The head hangs below the eyes, so up is away from most of it.
    rel = first - mid
    near = (rel @ ahead > 0) & (rel @ ahead < 0.3 * UNITS) & (np.abs(rel @ across) < 0.2 * UNITS)
    if (rel[near] @ up).mean() > 0:
        up = -up
    return mid, ahead, up, across


def slice_loop(first, triangles, mid, ahead, up, across, at, tilt=0.0, below=0.45):
    """Where the skin crosses a plane across the head `at` metres along it,
    leaning back by `tilt` radians at the top, down to `below` metres under
    the middle of the head: LOOP_POINTS spots round the
    outside, each as two vertices and how far between them (so they can be
    followed through every frame), and its angle round the loop."""
    centre = mid + ahead * at * UNITS
    normal = ahead * np.cos(tilt) + up * np.sin(tilt)
    rise = up * np.cos(tilt) - ahead * np.sin(tilt)   # Up the plane
    side = (first - centre) @ normal
    edges = []
    for a, b in ((0, 1), (1, 2), (2, 0)):
        i, j = triangles[:, a], triangles[:, b]
        crosses = (side[i] > 0) != (side[j] > 0)
        edges.append(np.stack([i[crosses], j[crosses]], 1))
    edges = np.unique(np.sort(np.concatenate(edges), 1), axis=0)
    t = side[edges[:, 0]] / (side[edges[:, 0]] - side[edges[:, 1]])
    points = first[edges[:, 0]] + (first[edges[:, 1]] - first[edges[:, 0]]) * t[:, None]
    # Only the head: not the neck, nor anything far below the jaw.
    height = (points - centre) @ rise / UNITS
    width = (points - centre) @ across / UNITS
    keep = (height > -below) & (height < 0.3) & (np.abs(width) < 0.2)
    edges, t, height, width = edges[keep], t[keep], height[keep], width[keep]
    middle = np.array([(height.max() + height.min()) / 2, 0.0])
    rel = np.stack([height, width], 1) - middle
    angle = np.arctan2(rel[:, 1], rel[:, 0])   # 0 on top
    radius = np.linalg.norm(rel, axis=1)
    wants = -np.pi + 2 * np.pi * (np.arange(LOOP_POINTS) + 0.5) / LOOP_POINTS
    gaps = [np.abs((angle - want + np.pi) % (2 * np.pi) - np.pi) for want in wants]
    outer = np.array([radius[g < np.pi / LOOP_POINTS].max() if (g < np.pi / LOOP_POINTS).any() else 0.0 for g in gaps])
    loop = []
    for k, want in enumerate(wants):
        # Ears stick out of the loop: keep to the head's own round shape.
        near = np.concatenate([outer[(k + d) % LOOP_POINTS:(k + d) % LOOP_POINTS + 1] for d in (-2, -1, 1, 2)])
        cap = np.median(near[near > 0]) * 1.12 if (near > 0).any() else np.inf
        inside = np.where((gaps[k] < np.pi / LOOP_POINTS) & (radius <= cap))[0]
        best = inside[np.argmax(radius[inside])] if len(inside) else int(np.argmin(gaps[k] + (radius > cap) * 10))
        loop.append((int(edges[best, 0]), int(edges[best, 1]), float(t[best]), float(want)))
    return loop


def follow_loop(frames, loop):
    """A loop's spots in every frame, moved off the skin away from its middle."""
    out = []
    for frame in frames:
        spots = np.array([frame[i] + (frame[j] - frame[i]) * t for i, j, t, _ in loop])
        middle = spots.mean(0)
        away = spots - middle
        away /= np.linalg.norm(away, axis=1)[:, None]
        out.append(spots + away * STRAP_OFF * UNITS)
    return np.array(out)


def bridle(frames, uv, triangles, nose, fwd, side):
    """The bridle's points in every frame (see the top of this file)."""
    first = frames[0]
    mid, ahead, up, across = head_frame(first, uv, triangles, nose)
    left_sign = 1.0 if fwd == 2 else -1.0
    points = {}
    loops = {name: slice_loop(first, triangles, mid, ahead, up, across, at, tilt, below)
        for name, at, tilt, below in (("noseband", NOSEBAND_AT, 0.0, 0.2), ("headpiece", HEADPIECE_AT, HEADPIECE_TILT, 0.45),
            ("brow", BROW_AT, 0.0, 0.45), ("bit", BIT_AT, 0.0, 0.15))}
    spots = {name: follow_loop(frames, loop) for name, loop in loops.items()}
    for name in ("noseband", "headpiece"):
        for k in range(LOOP_POINTS):
            points["%s_%d" % (name, k)] = spots[name][:, k]
    # The browband: the top of its loop, from one side of the forehead to the other.
    arc = [k for k, spot in enumerate(loops["brow"]) if abs(spot[3]) < np.radians(80)]
    for n, k in enumerate(arc):
        points["brow_%d" % n] = spots["brow"][:, k]
    # The cheekpieces start at the sides of the crownpiece, and the bit sits
    # low at the corners of the mouth.
    for name, loop, want in (("cheek_top", "headpiece", np.radians(90)), ("bit", "bit", np.radians(120))):
        for sign in (-1.0, 1.0):
            k = int(np.argmin([abs(spot[3] - sign * want) for spot in loops[loop]]))
            track = spots[loop][:, k]
            is_left = (track[0][side] - mid[side]) * left_sign > 0
            points[name + ("_l" if is_left else "_r")] = track
    return points


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
        nose = np.array(saddle[name]["nose"][0])
        for mark, spots in bridle(frames, uv, triangles, nose, fwd, side).items():
            points[mark] = [[round(float(v), 3) for v in spot] for spot in spots]
        out[name] = points
        if name == "horse_walk.glb":
            write_png(GAITS / "markings.png", paint(uv, triangles, face_and_legs(first, track, fwd, side)))
            print("wrote", GAITS / "markings.png")
    (GAITS / "groom_track.json").write_text(json.dumps(out))
    print("wrote", GAITS / "groom_track.json")


if __name__ == "__main__":
    main()
