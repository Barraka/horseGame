"""Prepare the rider models from Quaternius' free packs (CC0).

Copies the outfits, hairstyles and heads the game uses into assets/rider/,
with textures shrunk to 1024 px. The packs' heads only come as full bodies,
so this keeps just the head and neck triangles (skinned to the Head and
neck_01 bones), since the outfits supply everything else.

Usage: python3 tools/prepare_rider.py <Universal Base Characters dir> <Modular Character Outfits dir>
"""
import json
import shutil
import struct
import sys
from pathlib import Path

from PIL import Image

TEXTURE_SIZE = 1024
HEAD_BONES = {"neck_01", "Head"}
HAIRSTYLES = ["Hair_Long", "Hair_Buns", "Hair_SimpleParted", "Hair_Buzzed", "Hair_BuzzedFemale", "Hair_Beard"]
OUTFITS = ["Female_Ranger", "Female_Peasant", "Male_Ranger", "Male_Peasant"]
EXTRA_TEXTURES = ["Ranger/T_Ranger_3_BaseColor.png", "Peasant/T_Peasant_2_BaseColor.png"]

COMPONENT = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_accessor(gltf, data, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt, size = COMPONENT[acc["componentType"]]
    n = COUNT[acc["type"]]
    stride = view.get("byteStride", size * n)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        values = struct.unpack_from("<" + fmt * n, data, start + i * stride)
        if acc.get("normalized") and fmt != "f":
            values = tuple(v / (2 ** (size * 8) - 1) for v in values)
        out.append(values)
    return out


def copy_texture(src: Path, dest_dir: Path) -> str:
    name = src.name.replace("_png.png", ".png")
    dest = dest_dir / name
    if not dest.exists():
        image = Image.open(src)
        if image.width > TEXTURE_SIZE:
            image = image.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
        image.save(dest, optimize=True)
    return "textures/" + name


def copy_gltf(src: Path, dest_dir: Path, texture_dirs, keep_head_only=False, drop_meshes=()):
    gltf = json.loads(src.read_text())
    data = bytearray((src.parent / gltf["buffers"][0]["uri"]).read_bytes())
    for image in gltf.get("images", []):
        uri = image["uri"]
        # Some files name their textures "X_png.png" though only "X.png" ships.
        candidates = [uri, uri.replace("_png.png", ".png")]
        found = next(d / c for c in candidates for d in texture_dirs if (d / c).exists())
        image["uri"] = copy_texture(found, dest_dir / "textures")
    if keep_head_only:
        joints = [gltf["nodes"][j]["name"] for j in gltf["skins"][0]["joints"]]
        head = {i for i, name in enumerate(joints) if name in HEAD_BONES}
        for mesh in gltf["meshes"]:
            for prim in mesh["primitives"]:
                bones = read_accessor(gltf, data, prim["attributes"]["JOINTS_0"])
                weights = read_accessor(gltf, data, prim["attributes"]["WEIGHTS_0"])
                on_head = [sum(w for b, w in zip(bs, ws) if b in head) >= 0.5 for bs, ws in zip(bones, weights)]
                indices = [i[0] for i in read_accessor(gltf, data, prim["indices"])]
                kept = [v for t in range(0, len(indices), 3) if all(on_head[v] for v in indices[t:t + 3]) for v in indices[t:t + 3]]
                while len(data) % 4:
                    data.append(0)
                offset = len(data)
                data += struct.pack("<%dI" % len(kept), *kept)
                gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(kept) * 4, "target": 34963})
                gltf["accessors"].append({"bufferView": len(gltf["bufferViews"]) - 1, "componentType": 5125, "count": len(kept), "type": "SCALAR"})
                prim["indices"] = len(gltf["accessors"]) - 1
    if drop_meshes:
        for node in gltf["nodes"]:
            if "mesh" in node and gltf["meshes"][node["mesh"]]["name"] in drop_meshes:
                del node["mesh"]
                node.pop("skin", None)
    name = src.stem if not keep_head_only else src.stem.replace("Superhero_", "Head_").replace("_FullBody", "")
    gltf["buffers"][0]["uri"] = name + ".bin"
    gltf["buffers"][0]["byteLength"] = len(data)
    (dest_dir / (name + ".bin")).write_bytes(data)
    (dest_dir / (name + ".gltf")).write_text(json.dumps(gltf))
    print("wrote", name)


def main():
    base, outfits = Path(sys.argv[1]), Path(sys.argv[2])
    dest = Path(__file__).resolve().parent.parent / "assets" / "rider"
    if dest.exists():
        shutil.rmtree(dest)
    (dest / "textures").mkdir(parents=True)
    base_dir = base / "Base Characters" / "Godot - UE"
    hair_dir = base / "Hairstyles" / "Rigged to Head Bone" / "glTF (Godot -Unreal)"
    outfit_dir = outfits / "Exports" / "glTF (Godot-Unreal)" / "Outfits"
    textures = [base_dir, hair_dir, outfit_dir, base / "Base Characters" / "Textures"]
    for body in ["Superhero_Female_FullBody", "Superhero_Male_FullBody"]:
        copy_gltf(base_dir / (body + ".gltf"), dest, textures, keep_head_only=True)
    for hair in HAIRSTYLES:
        copy_gltf(hair_dir / (hair + ".gltf"), dest, textures)
    for outfit in OUTFITS:
        copy_gltf(outfit_dir / (outfit + ".gltf"), dest, textures)
    for extra in EXTRA_TEXTURES:
        copy_texture(outfits / "Textures" / extra, dest / "textures")
    shutil.copy(base / "License_Standard.txt", dest / "LICENSE.txt")


if __name__ == "__main__":
    main()
