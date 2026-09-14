# Build, test, and record

## Tools

- Godot **4.6.3**, standard GDScript build. Set `GODOT` or pass `--godot`
  to the Python helpers if the executable is not on PATH.
- Python 3.10+ for verification and publication helpers; they use the
  standard library.
- Blender 4/5 for optional prop rebuilding. The retained archer adaptation
  uses Blender 5's action-slot API.
- NumPy for audio synthesis; Pillow for archer contact sheets; FFmpeg
  for music encoding and recording conversion.
- On a Linux host without a display, `xvfb-run` for rendered capture.

Install optional builder dependencies in a virtual environment:

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r tools/requirements.txt
```

## Run and verify

```sh
python3 tools/check_assets.py
godot --headless --path . --import
godot --headless --path . --script scenes/build_ember.gd
godot --path .
python3 tools/verify.py
```

The last command imports assets, regenerates the entry scenes, parses all
GDScripts, tests gameplay and audio controls, runs a complete combat driver,
loads game/dungeon scenes, and checks ordinary startup. Logs stay under
`build/verification-game/`.

To test the exact public-file boundary without external artwork:

```sh
python3 tools/audit_public.py
python3 tools/verify.py --source-only
```

The source-only check copies Git-eligible files to a temporary directory,
imports them without a pre-existing Godot cache, and verifies the missing-asset
screen. Logs stay under `build/verification-source/`. It does not claim that
the original encounter is playable without its external dependencies.

## Rebuild original models and sounds

```sh
blender -b --python tools/build_ember_props.py
blender -b --python tools/build_archer_projectile.py
python3 tools/build_combat_audio.py
python3 tools/build_archer_audio.py
python3 tools/build_consecration_audio.py
python3 tools/build_ember_audio.py
ffmpeg -y -i tools/ember_ambience.wav -c:a libvorbis -q:a 4 assets/audio/ember_ambience.ogg
godot --headless --path . --import
```

Rebuilding models can change GLB exporter metadata across Blender versions.
The game uses the checked-in exports; reproducing identical geometry does
not imply byte-identical files.

For the separately attributed archer adaptation:

```sh
blender -b --python tools/archer/tools/animate_archer.py
python3 tools/archer/tools/finalize_archer.py
blender -b --python tools/archer/tools/review_archer.py
python3 tools/archer/tools/pack_reviews.py
```

The static and animated sources are under `tools/archer/assets/source/`.
These scripts refer to the repository root, emit the runtime GLB under
`assets/models/`, and write reviews under `build/archer/`. The finalizer
retains the CC BY attribution and refreshes public model metadata.

## Export

Install export templates matching Godot 4.6.3 and supply the required external
assets before exporting a playable game.

```sh
mkdir -p build/linux build/windows build/macos
godot --headless --path . --export-release Linux build/linux/game.x86_64
godot --headless --path . --export-release Windows build/windows/game.exe
godot --headless --path . --export-release macOS build/macos/game.zip
```

The macOS preset is universal and unsigned. Native signing and notarization
are a separate distribution step. Linux/Windows exports use a separate PCK.
Include `LICENSE`, `THIRD_PARTY_NOTICES.txt`, and the font licence when
redistributing a permitted build.

**Git exclusions are not export exclusions.** A local export may contain
the separately licensed artwork and optional music. Review their applicable
distribution permissions before sharing the resulting game.

## Record a verification video

```sh
python3 tools/capture.py
```

Godot's Movie Writer renders 540 frames at 30 FPS (18 seconds), starting
on the title screen and then showing real movement, combat, projectiles,
and skills. FFmpeg encodes the result as
`screenshots/public/gameplay.mp4`.

Software rendering works but is slower than playback. Watch the recording,
check the log, and inspect the actual behavior before accepting a visual
change. New recordings are local review artifacts and are excluded from Git.

## Credential checks

With Gitleaks installed, scan both files and Git history with redacted output:

```sh
gitleaks dir . --redact=100 --max-archive-depth 2 --max-decode-depth 3
gitleaks git . --redact=100 --log-opts=--all
```

The lightweight `tools/audit_public.py` additionally checks the public
asset boundary. Use its `--staged` option to read blobs from the Git index.
