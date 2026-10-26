"""Subtract covered portions of same-facing coplanar triangles in an atlas GLB.

Requires NumPy. Source order determines the retained surface in overlapping areas.
Opposite-facing surfaces and texture pixels are preserved.
Usage: python repair_coplanar_map.py input.glb output.glb
"""
import collections
import json
from pathlib import Path
import struct
import sys
import numpy as np

source, destination = map(Path, sys.argv[1:3])
raw = source.read_bytes()
json_length, _ = struct.unpack_from('<II', raw, 12)
model = json.loads(raw[20:20 + json_length])
binary_start = 28 + json_length
binary = bytearray(raw[binary_start:])

def read_accessor(index):
    accessor = model['accessors'][index]
    view = model['bufferViews'][accessor['bufferView']]
    dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[accessor['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', np.dtype(dtype).itemsize * width)
    return np.ndarray((accessor['count'], width), dtype=dtype, buffer=binary, offset=offset, strides=(stride, np.dtype(dtype).itemsize)).astype(float)

def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]

def area(poly):
    if len(poly) < 3:
        return 0.0
    return abs(sum(cross(poly[i] - poly[0], poly[i + 1] - poly[0]) for i in range(1, len(poly) - 1))) * 0.5

def half(poly, start, edge, sign):
    if len(poly) < 3:
        return []
    result = []
    previous = poly[-1]
    pd = sign * cross(edge, previous - start)
    for current in poly:
        cd = sign * cross(edge, current - start)
        if (cd >= 0) != (pd >= 0):
            result.append(previous + (current - previous) * (pd / (pd - cd)))
        if cd >= 0:
            result.append(current)
        previous, pd = current, cd
    return result

def subtract(poly, cutter):
    sign = 1 if cross(cutter[1] - cutter[0], cutter[2] - cutter[0]) > 0 else -1
    remaining, outside = poly, []
    for edge in range(3):
        start, end = cutter[edge], cutter[(edge + 1) % 3]
        piece = half(remaining, start, end - start, -sign)
        if area(piece) > 1e-8:
            outside.append(piece)
        remaining = half(remaining, start, end - start, sign)
        if area(remaining) <= 1e-8:
            return outside
    return outside

primitive = model['meshes'][0]['primitives'][0]
assert len(model['meshes']) == 1 and len(model['meshes'][0]['primitives']) == 1
assert set(primitive['attributes']) == {'POSITION', 'NORMAL', 'TEXCOORD_0'}
positions = read_accessor(primitive['attributes']['POSITION'])
normals = read_accessor(primitive['attributes']['NORMAL'])
uvs = read_accessor(primitive['attributes']['TEXCOORD_0'])
indices = read_accessor(primitive['indices']).astype(int).reshape(-1, 3)
triangles = positions[indices]
crosses = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
lengths = np.linalg.norm(crosses, axis=1)
groups = collections.defaultdict(list)
for index, triangle in enumerate(triangles):
    if lengths[index] < 1e-10:
        continue
    normal = crosses[index] / lengths[index]
    distance = np.dot(normal, triangle[0])
    groups[tuple(np.round(normal, 5)) + (round(float(distance), 4),)].append(index)

output_positions, output_normals, output_uvs = [], [], []
affected = fully_covered = 0
source_area = output_area = 0.0
for key, members in groups.items():
    axes = [axis for axis in range(3) if axis != int(np.argmax(np.abs(key[:3])))]
    projected = triangles[members][:, :, axes]
    low, high = projected.min(axis=1), projected.max(axis=1)
    member_order = np.arange(len(members))
    for local, index in enumerate(members):
        original = projected[local]
        original_area = area(original)
        source_area += original_area
        pieces = [list(original)]
        candidates = np.flatnonzero((member_order < local) & (low[:, 0] < high[local, 0] - 1e-6) & (high[:, 0] > low[local, 0] + 1e-6) & (low[:, 1] < high[local, 1] - 1e-6) & (high[:, 1] > low[local, 1] + 1e-6))
        normal = crosses[index] / lengths[index]
        for other in candidates:
            if np.max(np.abs((triangles[members[other]] - triangles[index, 0]) @ normal)) > 5e-4:
                continue
            pieces = [fragment for piece in pieces for fragment in subtract(piece, projected[other])]
            if not pieces:
                break
            if len(pieces) > 256:
                raise RuntimeError('Unexpected excessive fragmentation; refusing partial repair')
        retained_area = sum(area(piece) for piece in pieces)
        assert retained_area <= original_area + 1e-5
        output_area += retained_area
        if retained_area < original_area - 1e-5:
            affected += 1
        if not pieces:
            fully_covered += 1
        transform = np.column_stack((original[1] - original[0], original[2] - original[0]))
        inverse = np.linalg.inv(transform)
        for poly in pieces:
            for j in range(1, len(poly) - 1):
                verts = [poly[0], poly[j], poly[j + 1]]
                if area(verts) < 1e-8:
                    continue
                for vertex in verts:
                    second, third = inverse @ (vertex - original[0])
                    weights = np.array([1 - second - third, second, third])
                    output_positions.append(weights @ triangles[index])
                    n = weights @ normals[indices[index]]
                    output_normals.append(n / max(np.linalg.norm(n), 1e-12))
                    output_uvs.append(weights @ uvs[indices[index]])

# Discard triangles that collapse when encoded as the runtime float32 vertices.
encoded_positions = np.asarray(output_positions, dtype='<f4')
encoded_triangles = encoded_positions.reshape(-1, 3, 3)
valid = np.linalg.norm(np.cross(encoded_triangles[:, 1] - encoded_triangles[:, 0], encoded_triangles[:, 2] - encoded_triangles[:, 0]), axis=1) > 1e-9
keep = np.repeat(valid, 3)
output_positions = encoded_positions[keep]
output_normals = np.asarray(output_normals, dtype='<f4')[keep]
output_uvs = np.asarray(output_uvs, dtype='<f4')[keep]

# Append new geometry without changing any existing image buffer view.
def append_accessor(values, type_, component, target):
    array = np.asarray(values, dtype='<f4' if component == 5126 else '<u4')
    binary.extend(b'\0' * (-len(binary) % 4))
    start = len(binary)
    encoded = array.tobytes()
    binary.extend(encoded)
    view = len(model['bufferViews'])
    model['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(encoded), 'target': target})
    accessor = {'bufferView': view, 'componentType': component, 'count': len(array), 'type': type_}
    if type_ == 'VEC3':
        accessor['min'], accessor['max'] = array.min(axis=0).tolist(), array.max(axis=0).tolist()
    model['accessors'].append(accessor)
    return len(model['accessors']) - 1
primitive['attributes'] = {'POSITION': append_accessor(output_positions, 'VEC3', 5126, 34962), 'NORMAL': append_accessor(output_normals, 'VEC3', 5126, 34962), 'TEXCOORD_0': append_accessor(output_uvs, 'VEC2', 5126, 34962)}
primitive['indices'] = append_accessor(np.arange(len(output_positions)), 'SCALAR', 5125, 34963)
model['buffers'][0]['byteLength'] = len(binary)
report = {'source_triangles': len(indices), 'output_triangles': len(output_positions) // 3, 'affected_triangles': affected, 'fully_covered_triangles_removed': fully_covered, 'source_projected_area': source_area, 'retained_projected_area': output_area, 'atlas_data_unchanged': True}
model.setdefault('extras', {})['warbase_coplanar_repair'] = report
encoded = json.dumps(model, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
binary.extend(b'\0' * (-len(binary) % 4))
result = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(encoded) + 8 + len(binary)) + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + struct.pack('<II', len(binary), 0x004E4942) + binary
destination.write_bytes(result)
print(json.dumps(report, indent=2))
