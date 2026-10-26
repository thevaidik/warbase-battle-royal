"""Compress the generated collision data deterministically for Go embedding."""
import gzip
from pathlib import Path
source = Path(__file__).resolve().parents[1] / "warbase-godot/server/internal/engine/maps.json"
with source.open("rb") as reader, source.with_suffix(".json.gz").open("wb") as writer:
    with gzip.GzipFile(fileobj=writer, mode="wb", mtime=0) as compressed:
        compressed.write(reader.read())
source.unlink()
