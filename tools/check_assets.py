"""Check external dependencies without downloading or modifying any files."""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]


def missing_files():
    groups = json.loads((ROOT / "assets/external.json").read_text())["groups"]
    return [(group, path) for group in groups for path in group["files"]
            if not (ROOT / path).is_file()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-missing", action="store_true",
                        help="Report missing files without failing; useful for a source-only checkout.")
    args = parser.parse_args()
    missing = missing_files()
    required = [(group, path) for group, path in missing if group["required"]]
    for group, path in required:
        print(f"MISSING [{group['id']}]: {path}")
    for group, path in missing:
        if not group["required"]:
            print(f"OPTIONAL [{group['id']}]: {path}")
    if required:
        print(f"{len(required)} required files missing. See docs/ASSETS.md.")
    else:
        print("All required external assets are present.")
    return 0 if args.allow_missing or not required else 2


if __name__ == "__main__":
    raise SystemExit(main())
