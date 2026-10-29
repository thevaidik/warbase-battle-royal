#!/usr/bin/env python3
"""Extract only Industrial's collision/spawn JSON from the Go server's map archive."""

from __future__ import annotations

import argparse
import gzip
import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "warbase-godot/server/internal/engine/maps.json.gz"
DEFAULT_TARGET = ROOT / "warbase-colyseus/src/data/industrial.json.gz"
DEFAULT_GODOT_TARGET = ROOT / "warbase-godot/client/assets/data/industrial.json.gz"
FIXTURE_CONTENT = {
    "rays": [
        {"name": "warehouse_wall", "from": [-12, 1.1, -10], "to": [-8, 1.1, -10], "blocked": True},
        {"name": "perimeter_fence", "from": [77, 1.4, -20], "to": [81, 1.4, -20], "blocked": True},
        {"name": "open_road", "from": [67, 0.5, -20], "to": [73, 0.5, -20], "blocked": False},
    ],
    "moves": [
        {"name": "road_clear", "from": [67, 0.8420972846275667, -20], "to": [73, 0.8420972846275667, -20], "expected": [73, 0.8420980699881204, -20]},
        {"name": "fence_stop", "from": [77, 0.8420988520396353, -20], "to": [81, 0.8420988520396353, -20], "expected": [78.484375, 0.8420991422540676, -20]},
        {"name": "warehouse_slide", "from": [-12, 0.8420999299399377, -10], "to": [-8, 0.8420999299399377, -6], "expected": [-10.95703125, 0.8421006282052232, -6]},
    ],
}
PLAYABLE_MAPS = ("football", "resoforge", "industrial", "village", "arena", "shipment", "dust2", "nuketown", "canyon", "desert_oasis")


def encode_map(name: str, entry: dict) -> tuple[bytes, dict]:
    triangles = entry.get("triangles")
    if not isinstance(triangles, list) or not triangles or len(triangles) % 9:
        raise SystemExit(f"{name} has invalid triangle data")
    if not isinstance(entry.get("spawns"), list) or not entry["spawns"]:
        raise SystemExit(f"{name} has no authored spawns")
    if any(not math.isfinite(value) for value in triangles):
        raise SystemExit(f"{name} contains non-finite map vertices")

    triangle_count = len(triangles) // 9
    def f32(value: float) -> float:
        return struct.unpack("<f", struct.pack("<f", value))[0]

    bounds: list[tuple[float, float, float, float, float, float]] = []
    centers: list[tuple[float, float, float]] = []
    for triangle in range(triangle_count):
        values = triangles[triangle * 9 : triangle * 9 + 9]
        xs = [f32(value) for value in values[0::3]]
        ys = [f32(value) for value in values[1::3]]
        zs = [f32(value) for value in values[2::3]]
        box = (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs))
        bounds.append(box)
        centers.append(((box[0] + box[3]) * 0.5, (box[1] + box[4]) * 0.5, (box[2] + box[5]) * 0.5))

    nodes: list[list[float | int]] = []
    order: list[int] = []

    def build(indices: list[int]) -> int:
        node_index = len(nodes)
        box = (
            min(bounds[index][0] for index in indices), min(bounds[index][1] for index in indices), min(bounds[index][2] for index in indices),
            max(bounds[index][3] for index in indices), max(bounds[index][4] for index in indices), max(bounds[index][5] for index in indices),
        )
        nodes.append([*box, -1, -1, 0, 0])
        if len(indices) <= 12:
            nodes[node_index][8] = len(order)
            nodes[node_index][9] = len(indices)
            order.extend(indices)
            return node_index
        extents = (box[3] - box[0], box[4] - box[1], box[5] - box[2])
        axis = 0 if extents[0] >= extents[1] and extents[0] >= extents[2] else 1 if extents[1] >= extents[2] else 2
        indices.sort(key=lambda index: centers[index][axis])
        middle = len(indices) // 2
        nodes[node_index][6] = build(indices[:middle])
        nodes[node_index][7] = build(indices[middle:])
        return node_index

    build(list(range(triangle_count)))
    compact = {
        "name": name,
        "nav_step": entry.get("nav_step", 2),
        "spawns": entry["spawns"],
        "vehicles": entry.get("vehicles", []),
        "triangles": triangles,
        "nodes": [value for node in nodes for value in node],
        "order": order,
    }
    encoded = gzip.compress(json.dumps(compact, separators=(",", ":"), allow_nan=False).encode("utf-8"), compresslevel=9, mtime=0)
    return encoded, compact


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--godot-target", type=Path, default=DEFAULT_GODOT_TARGET)
    parser.add_argument("--all-maps", action="store_true", help="write indexed geometry assets for the ten shipped multiplayer maps")
    args = parser.parse_args()

    with gzip.open(args.source, "rt", encoding="utf-8") as source:
        maps = json.load(source)
    industrial = maps.get("industrial")
    if not isinstance(industrial, dict):
        raise SystemExit("source archive has no Industrial geometry")
    names = PLAYABLE_MAPS if args.all_maps else ("industrial",)
    fixtures: list[dict] = []
    for name in names:
        entry = maps.get(name)
        if not isinstance(entry, dict):
            raise SystemExit(f"source archive has no {name} geometry")
        payload, compact = encode_map(name, entry)
        if args.all_maps:
            targets = (args.target.parent / "maps" / f"{name}.json.gz", args.godot_target.parent / "maps" / f"{name}.json.gz")
        else:
            targets = (args.target, args.godot_target)
        for target in targets:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(payload)
            print(f"Wrote {len(compact['triangles']) // 9} {name} triangles, {len(compact['nodes']) // 10} BVH nodes, {len(compact['spawns'])} authored spawns, and {len(compact['vehicles'])} vehicle spawns to {target}")
        fixtures.append({
            "map": name,
            "triangles": len(compact["triangles"]) // 9,
            "spawns": len(compact["spawns"]),
            "vehicles": len(compact["vehicles"]),
            "nav_step": compact["nav_step"],
            "spawn": compact["spawns"][0],
        })

    geometry_fixtures = json.dumps(FIXTURE_CONTENT, indent=2, allow_nan=False) + "\n"
    map_fixtures = json.dumps(fixtures, indent=2, allow_nan=False) + "\n"
    for target in (args.target.parent / "geometry-fixtures.json", args.godot_target.parent / "geometry-fixtures.json"):
        target.write_text(geometry_fixtures, encoding="utf-8")
    if args.all_maps:
        for target in (args.target.parent / "maps" / "map-fixtures.json", args.godot_target.parent / "maps" / "map-fixtures.json"):
            target.write_text(map_fixtures, encoding="utf-8")


if __name__ == "__main__":
    main()
