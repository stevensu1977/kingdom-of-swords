"""Audit files eligible for Git; reports locations without printing secret values."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "private workspace identifier": rb"\b20[0-9]{6}-[a-z0-9]{6}\b",
    "private asset identifier": rb"(?:project-asset-|rev-|collection-revision-)[0-9a-f]{8}-[0-9a-f-]{27,}",
    "private workspace path": rb"/(?:home/ubuntu/godogen-runs|mnt/data|workspace)/",
    "private key": rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "AWS access key": rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "API token": rb"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}",
    "GitHub token": rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})",
}


def candidate_files(staged=False):
    command = ["git", "ls-files", "-z", "--cached"]
    if not staged:
        command += ["--others", "--exclude-standard"]
    result = subprocess.check_output(command, cwd=ROOT).decode().split("\0")
    return sorted(set(path for path in result if path))


def read_candidate(path, staged):
    if staged:
        return subprocess.check_output(["git", "show", ":" + path], cwd=ROOT)
    return (ROOT / path).read_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true",
                        help="Read exactly the Git index instead of working-tree files.")
    args = parser.parse_args()
    names = candidate_files(args.staged)
    required = {"LICENSE", "THIRD_PARTY_NOTICES.txt", "README.md",
                "project.godot", "assets/external.json"}
    failures = [f"Missing public file: {p}" for p in required - set(names)]
    external = json.loads(read_candidate("assets/external.json", args.staged))["groups"]
    blocked = {p for group in external for p in group["files"]}
    blocked |= {p + ".import" for p in blocked}
    total = 0
    for name in names:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or (ROOT / name).is_symlink():
            failures.append(f"Unsafe path: {name}")
            continue
        if name in blocked or path.parts[0] in [".godot", "build", "screenshots", ".agents"]:
            failures.append(f"External/generated file selected for Git: {name}")
        if name in ["TEMPLATE.json", "BRIEF.md", "godot.md", "assets.md", "multiplayer.md"]:
            failures.append(f"Internal project document selected for Git: {name}")
        data = read_candidate(name, args.staged)
        total += len(data)
        # Pattern definitions are not leaked values.
        if name != "tools/audit_public.py":
            for label, pattern in PATTERNS.items():
                if re.search(pattern, data):
                    failures.append(f"{label}: {name}")
    if "assets/manifest.json" in names:
        manifest = json.loads(read_candidate("assets/manifest.json", args.staged))
        if manifest.get("bindings") or manifest.get("integrations"):
            failures.append("Public manifest contains private integration records")
        for model in manifest["models"]:
            for name in [model["path"], *model.get("sourceFiles", []), *model.get("dependencies", [])]:
                if name not in names:
                    failures.append(f"Manifest references a file outside public Git: {name}")
    for error in failures:
        print("FAIL:", error)
    print(f"Public file audit: {len(names)} files, {total / 1048576:.2f} MiB, {len(failures)} issue(s)")
    print("Scope: Git file selection, known sensitive patterns, and manifest dependencies; not a licence grant.")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
