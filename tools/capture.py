"""Record 18 seconds of normal gameplay using Godot's Movie Writer."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
from check_assets import missing_files

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    if any(group["required"] for group, _ in missing_files()):
        parser.error("Required artwork is missing; run tools/check_assets.py")
    godot = shutil.which(args.godot)
    ffmpeg = shutil.which("ffmpeg")
    if not godot or not ffmpeg:
        parser.error("Godot and FFmpeg are required")
    output = ROOT / "screenshots/public"
    output.mkdir(parents=True, exist_ok=True)
    command = [godot, "--path", str(ROOT), "--audio-driver", "Dummy",
               "--write-movie", str(output / "gameplay.avi"), "--fixed-fps", "30",
               "--quit-after", "540", "--script", "test/archer_video.gd"]
    if os.name == "posix" and not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
        command = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", *command]
    print("Recording 540 frames; software rendering can take several minutes.", flush=True)
    with (output / "capture.log").open("w") as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(output / "gameplay.avi"),
                    "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart",
                    str(output / "gameplay.mp4")], check=True)
    print(output / "gameplay.mp4")
    print("Local verification capture; review artwork/music permissions before publication.")


if __name__ == "__main__":
    main()
