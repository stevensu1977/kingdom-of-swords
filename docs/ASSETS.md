# Assets and distribution

The root MIT licence covers project code and original project assets.
Third-party models and fonts retain their own licences. A local copy or
an internal provenance identifier is not a redistribution grant.

## External files

`assets/external.json` is the exact dependency list. It contains no account,
workspace, or asset-library identifiers. Run:

```sh
python3 tools/check_assets.py
```

Required groups:

- **Prepared characters:** paladin, greatsword, melee skeleton, and their
  texture dependencies, under `assets/characters/`.
- **Dungeon:** the native scenes, resources, materials, and textures under
  `Assets/PolygonDungeon/`. Paths and filename case must match the JSON.

The source release does not provide a public download for these prepared
versions. Use files whose owner permits your intended use, or implement
compatible replacements. Buying another copy of a model does not ensure
that it has this project's exact rig, clips, or native scene paths.

Character requirements are in `assets/characters/character.json`.
The current hero needs Ready, ArmedWalk, Attack, Uppercut and its calibrated
two-handed grip; the skeleton needs Idle, Walk, Attack. A replacement with
a different rig needs a corresponding visual adapter and tests.

The dungeon adapter scales nine scene roles into the room. The native
scenes also supply collision; preserve that behavior in replacements.
The runtime checker uses resource remapping so it also works in an export.

The exact files are ignored by Git. Before adding any of them, obtain the
applicable permission, record its scope and attribution here, and review
the licence of both the original model and any animation inputs.

Synty's current standard terms restrict sharing source assets beyond the
permitted team and contain restrictions involving generative-AI promotion.
Which terms apply depends on the actual acquisition channel and licence.
Review the applicable terms before publishing a game, video, or screenshot
that contains the dungeon artwork.

## Music and sounds

`assets/audio/ember_ambience.ogg` is the bundled procedural music, rebuilt
with `tools/build_ember_audio.py` and FFmpeg.

If the optional local `assets/models/Chambre Maudite.ogg` exists, the game
uses that recording instead. Its author and public redistribution permission
were not supplied, so it and the WAV source are excluded from Git.

Sword, evade, bow, arrow, and holy-skill sounds have synthesis builders in
`tools/`. Public preparation rebuilt sword/evade cues from the new
`build_combat_audio.py`, avoiding an undocumented inherited sound dependency.

## Bundled archer

The supplied archer's metadata records **CC BY 4.0**, author
**ilyakardailskiy**, and the title **Monster_ Skeleton_ Archer_ Vari01 King's raid**.
The original source attribution is retained in `THIRD_PARTY_NOTICES.txt`
and in the GLB metadata.

The adapted version adds a fitted 63-bone skin, run/draw/shoot actions,
skinned bow limbs, and a replacement bowstring. It retains the source
geometry, texture, and palette. The original source page could not be
retrieved during public preparation; the recorded attribution has not been
represented as a new verification of upstream ownership.

The author's recorded licence applies to the model and derived Blender
sources; the root MIT licence does not replace it.

## Fonts

`Title.ttf` is DejaVu Serif; `Body.ttf` and `Display.ttf` are DejaVu Sans
family files. Their upstream copyright and permission text is included
under `docs/licenses/` and in the notices.

## Release boundaries

- Git includes the reviewed source, original props/audio, attributed archer,
  fonts, documentation, the maintainer-selected `docs/media/gameplay.mp4`,
  and `docs/media/cover.png`, a still extracted at 00:10 from that recording.
- This prepared public directory omits the external art entirely. A developer
  may supply it separately for a permitted local use. Full-game verification
  during preparation used a separate temporary working directory.
- A build made from that checkout can contain those external assets.
  `.gitignore` does not control Godot exports or grant permission to
  distribute a binary.
- The selected recording shows the original artwork and local music; the cover
  shows the same artwork. Their inclusion does not change the underlying
  licences. Other process images, older recordings, and new local verification
  media are ignored.

Use `python3 tools/audit_public.py` before staging or publishing changes.
It checks file selection and known sensitive patterns, not legal ownership.

References:

- https://syntystore.com/pages/end-user-licence-agreement
- https://creativecommons.org/licenses/by/4.0/
- https://dejavu-fonts.github.io/License.html
