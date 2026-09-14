"""Verify a configured game or a temporary public-source checkout."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from audit_public import candidate_files
from check_assets import missing_files

ROOT = Path(__file__).resolve().parents[1]
TESTS = ["ember_flow", "ember_music", "consecration", "divine_shield",
         "archer", "character_contract", "archer_combat", "ember_scenes"]


def verify(project, godot, output, source_only):
    output.mkdir(parents=True, exist_ok=True)
    results = []

    def run(label, arguments, timeout=180):
        print(label, flush=True)
        result = subprocess.run([godot, "--headless", "--path", str(project), *arguments],
                                cwd=project, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=timeout)
        (output / (label + ".log")).write_text(result.stdout)
        failed = result.returncode != 0 or re.search(r"(?:SCRIPT ERROR:|ERROR:|Parse Error:)", result.stdout)
        results.append({"check": label, "passed": not bool(failed)})
        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        if failed:
            print(result.stdout[-7000:])
            raise RuntimeError(label + " failed; see " + str(output))

    run("import", ["--import"])
    run("build-scenes", ["--script", "scenes/build_ember.gd"])
    for folder in ["scripts", "scenes", "test"]:
        for script in sorted((project / folder).rglob("*.gd")):
            relative = str(script.relative_to(project))
            run("parse-" + relative.replace("/", "-"), ["--check-only", "--script", relative])
    if source_only:
        run("source-checkout", ["--script", "test/source_checkout.gd"])
    else:
        for test in TESTS:
            run(test, ["--fixed-fps", "60", "--script", "test/" + test + ".gd"])
        run("startup", ["--quit-after", "30"])
    print(f"PASS: {len(results)} checks. Logs: {output}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-only", action="store_true",
                        help="Copy Git-eligible files to a temporary directory and check startup without private artwork.")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("Godot executable not found; use --godot /path/to/godot")
    if args.source_only:
        with tempfile.TemporaryDirectory(prefix="kos-source-") as temp:
            project = Path(temp)
            for name in candidate_files():
                dest = project / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, dest)
            verify(project, godot, ROOT / "build/verification-source", True)
    else:
        if any(group["required"] for group, _ in missing_files()):
            print("Required artwork is missing. Run tools/check_assets.py or use --source-only.")
            return 2
        verify(ROOT, godot, ROOT / "build/verification-game", False)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
