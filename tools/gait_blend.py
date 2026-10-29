"""Measure how to blend the horse's gaits into each other.

The three gait files (walk, trot, run) are the same horse, but each was saved
with its own vertex order, and the run file's mesh is a little simpler (no
inside of the mouth, and its eyes are built differently). To blend smoothly
from one gait to the next, scripts/gait_blend.gd poses the walk file's mesh
in every gait. This works out, for each vertex of the walk mesh, which
vertices of the trot and run meshes it follows:

- Most vertices sit on the same spot of the shared coat texture in every
  file, so they follow the vertex with the same texture position.
- The eyes are built differently in each file: each walk eye vertex follows
  the nearest vertex of the same eye.
- The inside of the mouth is missing from the run file: each of its
  vertices follows a weighted mix of the nearest matched vertices, which
  keeps its place as the head moves.

Godot imports the files with its vertices in its own order, so first run
  godot --headless --path . -s tools/mesh_order.gd
which writes tools/mesh_order.json (not kept in git: it holds the model).
Then run this. Writes assets/horse/gaits/gait_blend.json.
"""

import json
import struct

import numpy as np
from scipy.spatial import cKDTree

from saddle_track import GAITS, SIZES, TYPES, load

ORDER = GAITS.parent.parent.parent / "tools" / "mesh_order.json"
WALK = "horse_walk.glb"
OTHERS = ["horse_trot.glb", "horse_run.glb"]
# Each file's place in the horse's space (horse.gd GAIT_SET): yaw in degrees
# and offset in model units.
PLACE = {
    "horse_walk.glb": (180.0, np.array([0.09, 0.03, -0.76])),
    "horse_trot.glb": (180.0, np.array([0.01, 0.03, -0.82])),
    "horse_run.glb": (90.0, np.array([-1.24, -0.66, 0.0])),
}
EYE_GROUP = 500       # More vertices than this on one texture spot: an eye
MIX = 32              # Matched vertices each leftover vertex follows


def mesh(file):
    """The file's own vertex positions, texture positions and triangles."""
    data = (GAITS / file).read_bytes()
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
    return (accessor(prim["attributes"]["POSITION"]).astype(float),
            accessor(prim["attributes"]["TEXCOORD_0"]).astype(float),
            accessor(prim["indices"]).astype(int).reshape(-1, 3))


def in_walk_space(file, points):
    """A file's points moved into the walk file's space."""
    yaw, offset = PLACE[file]
    turn = np.radians(yaw - PLACE[WALK][0])
    c, s = np.cos(turn), np.sin(turn)
    p = points + offset
    return np.stack([p[:, 0] * c + p[:, 2] * s, p[:, 1], -p[:, 0] * s + p[:, 2] * c], 1) - PLACE[WALK][1]


def godot_order(file, points, uvs, dump):
    """For each vertex as Godot imported it, its index in the file."""
    theirs = np.hstack([np.array(dump[file]["points"]), np.array(dump[file]["uvs"]) * 100])
    distance, index = cKDTree(np.hstack([points, uvs * 100])).query(theirs)
    assert distance.max() < 1e-3, "%s: Godot's vertices don't match the file" % file
    assert len(np.unique(index)) == len(index)
    return index


def eyes(uvs):
    keys = np.round(uvs * 1e5).astype(int)
    _, inverse, counts = np.unique(keys, axis=0, return_inverse=True, return_counts=True)
    return counts[inverse.ravel()] > EYE_GROUP


def match(walk_uvs, walk_eyes, uvs, their_eyes):
    """Walk vertices that sit on the same texture spot as one of theirs."""
    spots = {}
    for i, key in enumerate(map(tuple, np.round(uvs * 1e5).astype(int))):
        if not their_eyes[i]:
            spots.setdefault(key, []).append(i)
    direct = np.full(len(walk_uvs), -1)
    for i, key in enumerate(map(tuple, np.round(walk_uvs * 1e5).astype(int))):
        if not walk_eyes[i] and len(spots.get(key, [])) == 1:
            direct[i] = spots[key][0]
    return direct


def match_eyes(walk_pose, walk_eyes, pose, their_eyes, direct):
    """Each walk eye vertex follows the nearest vertex of the same eye in the
    other file, measured from the eye's middle."""
    def split(points, eye):
        index = np.where(eye)[0]
        left = points[index, 0] > np.median(points[index, 0])
        return [index[left], index[~left]]
    for mine, theirs in zip(split(walk_pose, walk_eyes), split(pose, their_eyes)):
        _, nearest = cKDTree(pose[theirs] - pose[theirs].mean(0)).query(walk_pose[mine] - walk_pose[mine].mean(0))
        direct[mine] = theirs[nearest]


def pieces(direct, points):
    """The rest (the inside of the mouth) as mixes of nearby matched
    vertices that keep their shape as the head moves: for each, its vertex,
    the walk vertices it follows, their weights and how far it is from their
    middle (a mix can stretch when the mouth opens wide, so the game keeps
    each vertex about that close)."""
    matched = np.where(direct >= 0)[0]
    tree = cKDTree(points[matched])
    rows = []
    for v in np.where(direct < 0)[0]:
        _, nearest = tree.query(points[v], MIX)
        near = matched[nearest]
        solve = np.vstack([points[near].T, np.ones(MIX)])
        weights = solve.T @ np.linalg.solve(solve @ solve.T + 1e-8 * np.eye(4), np.append(points[v], 1.0))
        rows.append((int(v), near, weights, float(np.linalg.norm(points[v] - points[near].mean(0)))))
    return rows


def main():
    dump = json.loads(ORDER.read_text())
    walk_points, walk_uvs, walk_triangles = mesh(WALK)
    walk_order = godot_order(WALK, walk_points, walk_uvs, dump)
    walk_slot = np.empty(len(walk_order), int)   # Godot's index for each of the file's vertices
    walk_slot[walk_order] = np.arange(len(walk_order))
    walk_eyes = eyes(walk_uvs)
    walk_pose = load(GAITS / WALK)[1][0]
    out = {"vertices": len(walk_order)}
    for file in [WALK] + OTHERS:
        times, frames = load(GAITS / file)
        assert np.abs(frames[-1] - frames[0]).max() < 1e-4, "%s: clip doesn't loop" % file
    for file in OTHERS:
        points, uvs, _ = mesh(file)
        order = godot_order(file, points, uvs, dump)
        slot = np.empty(len(order), int)
        slot[order] = np.arange(len(order))
        their_eyes = eyes(uvs)
        direct = match(walk_uvs, walk_eyes, uvs, their_eyes)
        match_eyes(walk_pose, walk_eyes, in_walk_space(file, load(GAITS / file)[1][0]), their_eyes, direct)
        # The rest are fitted on the walk's first frame.
        rows = pieces(direct, walk_pose)
        # Everything in Godot's order: walk vertex -> their vertex.
        follow = np.full(len(walk_order), -1)
        follow[walk_slot[direct >= 0]] = slot[direct[direct >= 0]]
        out[file] = {
            "direct": follow.tolist(),
            "mixes": [[int(walk_slot[v])] + [int(slot[direct[j]]) for j in near] + [round(float(w), 5) for w in weights]
                      + [round(rest, 4)] for v, near, weights, rest in rows],
        }
        print("%s: %d vertices follow their own, %d follow a mix" % (file, (direct >= 0).sum(), len(rows)))
    path = GAITS / "gait_blend.json"
    path.write_text(json.dumps(out, separators=(",", ":")))
    print("wrote", path)


if __name__ == "__main__":
    main()
