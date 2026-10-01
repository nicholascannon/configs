#!/usr/bin/env python3
"""Bake a GLB bust into the compact binary mesh the nvim splash rasterizes.

usage: bake-bust.py <model.glb> [out.bin]

Stdlib only. Output layout (little endian):
  uint32 vertex_count, uint32 triangle_count
  float32 positions[vertex_count * 3]
  int8    normals[vertex_count * 3]      (unit vector * 127), padded to even length
  uint16  indices[triangle_count * 3]
"""
import array
import json
import math
import struct
import sys

# Cut below this fraction of the way up the model (the plinth is at the bottom).
CROP_FRACTION = 0.36
# Vertex-clustering cell size as a fraction of the cropped height.
CELL_FRACTION = 0.012
# Half-height of the baked model in splash units.
HALF_HEIGHT = 1.25
# Extra yaw applied after the node rotation, in degrees; centres the face on +z
# (found by eye from rendered frames).
YAW_OFFSET_DEGREES = -11.0


def main():
    glb = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "bust.bin"
    positions, normals, indices = read_glb(glb)
    positions, normals = orient(positions, normals)
    positions, normals, indices = crop_and_center(positions, normals, indices)
    positions, normals, indices = cluster(positions, normals, indices)
    write_bin(out, positions, normals, indices)
    print(f"{len(positions)} vertices, {len(indices)} triangles -> {out}")


def read_glb(path):
    data = open(path, "rb").read()
    json_len, _ = struct.unpack("<II", data[12:20])
    doc = json.loads(data[20:20 + json_len])
    bin_offset = 20 + json_len + 8
    prim = doc["meshes"][0]["primitives"][0]

    def accessor(index):
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        start = bin_offset + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        width = {"VEC3": 3, "SCALAR": 1}[acc["type"]]
        arr = array.array({5126: "f", 5125: "I", 5123: "H"}[acc["componentType"]])
        arr.frombytes(data[start:start + acc["count"] * width * arr.itemsize])
        return arr

    pos = accessor(prim["attributes"]["POSITION"])
    nrm = accessor(prim["attributes"]["NORMAL"])
    idx = accessor(prim["indices"])
    triples = lambda a: [tuple(a[i:i + 3]) for i in range(0, len(a), 3)]
    return triples(pos), triples(nrm), triples(idx)


def orient(positions, normals):
    """Apply the node's 180 degree z rotation, then turn the face (+x) to +z."""
    yaw = math.radians(YAW_OFFSET_DEGREES)
    c, s = math.cos(yaw), math.sin(yaw)

    def turn(v):
        x, y, z = -v[0], -v[1], v[2]
        x, z = -z, x
        return (x * c + z * s, y, -x * s + z * c)

    return [turn(v) for v in positions], [turn(v) for v in normals]


def crop_and_center(positions, normals, indices):
    ys = [v[1] for v in positions]
    low, high = min(ys), max(ys)
    cut = low + (high - low) * CROP_FRACTION
    # The head turns about the neck, so centre x/z on the upper half's centroid.
    upper = [v for v in positions if v[1] > (cut + high) / 2]
    cx = sum(v[0] for v in upper) / len(upper)
    cz = sum(v[2] for v in upper) / len(upper)
    scale = HALF_HEIGHT / ((high - cut) / 2)
    middle = (cut + high) / 2
    # Flatten everything below the cut onto the plane so the base is a clean edge.
    moved = [((v[0] - cx) * scale, (max(v[1], cut) - middle) * scale, (v[2] - cz) * scale)
             for v in positions]
    kept = [t for t in indices if any(positions[i][1] > cut for i in t)]
    return moved, normals, kept


def cluster(positions, normals, indices):
    """Vertex clustering: snap to a grid, average each cell, drop degenerates."""
    cell = 2 * HALF_HEIGHT * CELL_FRACTION
    cells = {}
    remap = []
    for p, n in zip(positions, normals):
        key = (math.floor(p[0] / cell), math.floor(p[1] / cell), math.floor(p[2] / cell))
        if key not in cells:
            cells[key] = [len(cells), [0.0] * 3, [0.0] * 3, 0]
        c = cells[key]
        for k in range(3):
            c[1][k] += p[k]
            c[2][k] += n[k]
        c[3] += 1
        remap.append(c[0])
    ordered = sorted(cells.values(), key=lambda c: c[0])
    out_pos = [tuple(a / c[3] for a in c[1]) for c in ordered]
    out_nrm = [unit(c[2]) for c in ordered]
    seen, tris = set(), []
    for a, b, c in indices:
        t = (remap[a], remap[b], remap[c])
        if len(set(t)) < 3:
            continue
        key = tuple(sorted(t))
        if key in seen:
            continue
        seen.add(key)
        tris.append(t)
    return out_pos, out_nrm, tris


def unit(v):
    length = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / length for a in v)


def write_bin(path, positions, normals, indices):
    with open(path, "wb") as f:
        f.write(struct.pack("<II", len(positions), len(indices)))
        f.write(array.array("f", [a for p in positions for a in p]).tobytes())
        f.write(array.array("b", [round(a * 127) for n in normals for a in n]).tobytes())
        f.write(b"\0" * ((len(normals) * 3) % 2))
        f.write(array.array("H", [i for t in indices for i in t]).tobytes())


if __name__ == "__main__":
    main()
