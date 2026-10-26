"""Remove identically oriented coincident triangles, preserving vertex/texture data.

Opposite windings remain separate so authored inside/outside faces are retained.
Usage: python3 scripts/clean_map_mesh.py input.glb output.glb
"""
import json
from pathlib import Path
import struct
import sys

source, target = map(Path, sys.argv[1:3])
raw = source.read_bytes()
assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 4)[0] == 2
json_size, kind = struct.unpack_from("<II", raw, 12)
assert kind == 0x4E4F534A
model = json.loads(raw[20:20 + json_size])
binary_at = 20 + json_size
binary_size, kind = struct.unpack_from("<II", raw, binary_at)
assert kind == 0x004E4942
binary = bytearray(raw[binary_at + 8:binary_at + 8 + binary_size])

def read_accessor(index):
    accessor = model["accessors"][index]
    view = model["bufferViews"][accessor["bufferView"]]
    component = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[accessor["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    format_ = "<" + component * width
    stride = view.get("byteStride", struct.calcsize(format_))
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [struct.unpack_from(format_, binary, offset + i * stride) for i in range(accessor["count"])]

removed = total = 0
for mesh in model["meshes"]:
    for primitive in mesh["primitives"]:
        assert primitive.get("mode", 4) == 4
        positions = read_accessor(primitive["attributes"]["POSITION"])
        indices = [entry[0] for entry in read_accessor(primitive["indices"])]
        seen, retained = set(), []
        for i in range(0, len(indices), 3):
            triangle = indices[i:i + 3]
            points = [positions[index] for index in triangle]
            key = min(tuple(points[j:] + points[:j]) for j in range(3))
            total += 1
            if key in seen:
                removed += 1
            else:
                seen.add(key)
                retained.extend(triangle)
        accessor = model["accessors"][primitive["indices"]]
        view = model["bufferViews"][accessor["bufferView"]]
        assert "byteStride" not in view
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        component = {5125: "I", 5123: "H", 5121: "B"}[accessor["componentType"]]
        encoded = struct.pack("<" + component * len(retained), *retained)
        binary[offset:offset + len(encoded)] = encoded
        accessor["count"] = len(retained)
        accessor["min"], accessor["max"] = [min(retained)], [max(retained)]
model.setdefault("extras", {})["warbase_mesh_cleanup"] = {"removed_coincident_triangles": removed, "original_triangles": total, "texture_data_unchanged": True}
encoded = json.dumps(model, separators=(",", ":")).encode()
encoded += b" " * (-len(encoded) % 4)
result = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(encoded) + 8 + len(binary)) + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded + struct.pack("<II", len(binary), 0x004E4942) + binary
target.write_bytes(result)
print(json.dumps({"original_triangles": total, "removed": removed, "remaining": total - removed, "texture_data_unchanged": True}, indent=2))
