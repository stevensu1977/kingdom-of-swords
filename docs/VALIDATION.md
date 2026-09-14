# Public-copy validation

Checked on 2026-09-14 using Godot 4.6.3 on Linux.

## Public source directory

The prepared directory contains no external paladin, greatsword, melee
skeleton, dungeon, or Chambre Maudite files. Their derived import cache
was removed before importing the public assets again.

A temporary copy containing only Git-eligible files passed **42 checks**:
fresh import, scene generation, all GDScript parses, and the missing-asset
startup fixture. The actual public directory also imported and started
without script/resource errors. Its setup screen was inspected in the
renderer and correctly reports 31 missing required files.

## Configured game

Full-game checks ran in a separate temporary directory with the external
artwork. The public directory was not repopulated with it. The optional
local music was absent, exercising the bundled procedural BGM fallback.

**50 checks passed**, including:

| Check | Result |
|---|---|
| Encounter / menu / restart | 25 assertions |
| Music UI, keyboard, pause, save/reload | 28 assertions |
| Consecration | 30 assertions |
| Divine Shield | 33 assertions |
| Archer timing, collision, cover | 32 assertions |
| Character grip and limb lengths | 244 animation samples |
| Complete combat driver | Victory, 12 kills, three seals, 100 HP, 63.92 s |
| Game and dungeon scene loading | 12 scenes |
| Ordinary startup | Passed |

The combat driver used normal movement, attack, evade, and skill commands.
A Linux PCK export and packed-game startup also passed without errors or
warnings. Native Windows/macOS launch and macOS signing were not tested.

## Builders and visual review

Blender rebuilt the original altar, crown seal, and arrow, and rebuilt the
archer adaptation with its rig and three clips. Four audio synthesis
scripts ran successfully. These checks used a separate temporary directory
and a working directory outside the project, verifying relocated paths.
The checked-in runtime models were not replaced by the test outputs.

A new **18-second, 1280 × 720, 30 FPS** Movie Writer recording was rendered
and reviewed across a chronological decoded frame sequence. It shows the
new menu, southwest arrival, movement, sword combat, arrows, Divine Shield,
and clearing the first watch. The full combat check separately verifies
the remaining watches and exit. The MP4 fully decodes. The software
renderer's unsupported V-Sync warning is the only capture warning.
This recording and its review images remain outside the public directory.

The sole included video is `docs/media/gameplay.mp4`: the maintainer-selected
BGM-switch demonstration. It is byte-identical to the selected original,
18 seconds long, 1280 × 720, and approximately 4.33 MiB. No other process
images or older recordings were copied into the public media directory.

## Credential and publication checks

Gitleaks **8.30.1**, obtained from its official release with its published
SHA-256 checksum checked, found no secrets in the public directory or
its Git history. Additional scans of text, credential-like filenames,
JWTs, credential-bearing URLs, and literal credentials found no matches.
The final Git index is independently audited before handoff.

`tools/audit_public.py` checks public file selection, common secret
patterns, private identifiers, and model-builder dependencies. These
pattern-based scans do not guarantee that every possible secret can
be recognized.

The original project's copied source files were hash-checked and remain
unchanged. The original repository history was not copied.

## Remaining limits

The public source is not a self-contained playable distribution: compatible
external character and dungeon artwork is still needed. Source-file
exclusion does not establish permission to redistribute a recorded image
of that artwork or its music. Review the applicable content permissions
before submitting the selected recording to a gallery.
