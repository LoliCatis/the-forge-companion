#!/usr/bin/env python3
"""Sync and validate the first-party empty desktop bootstrap pack."""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
VERSION = "2026.10.17-bootstrap.1"
FILES = ("manifest.json", "ores.json", "weapons.json", "traits.json", "probabilities.json", "sources.json", "observations.json", "evidence.json")
CANONICAL = ROOT / "data" / "packs" / VERSION
ASSET = ROOT / "apps" / "desktop" / "assets" / "packs" / VERSION
def digest(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()
def verify(directory: Path, label: str) -> None:
    missing = [name for name in FILES if not (directory / name).is_file()]
    if missing: raise SystemExit(f"{label} missing: {', '.join(missing)}")
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("dataVersion") != VERSION: raise SystemExit("Bootstrap version mismatch")
    for name in FILES[1:]:
        value = json.loads((directory / name).read_text(encoding="utf-8"))
        expected = manifest.get("contentHashes", {}).get(name)
        actual = digest(directory / name)
        if value not in ([], {"classes": [], "variants": []}): raise SystemExit("Bootstrap collections must remain empty")
        if expected != actual: raise SystemExit(f"SHA-256 mismatch for {name}: {actual}")
        print(f"OK {label}/{name} sha256={actual}")
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", type=Path, help="verify Flutter assets root")
    args = parser.parse_args()
    if args.verify: verify(args.verify / "assets" / "packs" / VERSION, str(args.verify)); return
    verify(CANONICAL, "bootstrap source")
    ASSET.mkdir(parents=True, exist_ok=True)
    for name in FILES: (ASSET / name).write_bytes((CANONICAL / name).read_bytes())
    verify(ASSET, "desktop assets")
if __name__ == "__main__": main()
