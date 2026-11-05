"""Compress the generated collision data deterministically for the Colyseus geometry extractor."""
import gzip
from pathlib import Path
source = Path(__file__).resolve().parents[1] / "build/map-authoring/maps.json"
with source.open("rb") as reader, source.with_suffix(".json.gz").open("wb") as writer:
    with gzip.GzipFile(fileobj=writer, mode="wb", mtime=0) as compressed:
        compressed.write(reader.read())
source.unlink()
