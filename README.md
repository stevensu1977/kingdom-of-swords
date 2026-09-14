# Kingdom of Swords — The Last Ember

**An agent-built Godot action game — an Astra showcase.**

[![The Warden using Divine Shield against skeleton guardians in The Last Ember](docs/media/cover.png)](docs/media/gameplay.mp4)

[中文](README.zh-CN.md) · [Development workflow](docs/AGENT_WORKFLOW.md) ·
[Build and test](docs/BUILDING.md) · [Assets and licences](docs/ASSETS.md)

[▶ Watch gameplay — 18 seconds](docs/media/gameplay.mp4)

You are the Warden of a dying sanctuary. Defeat three watches of skeleton
guardians, rekindle their seals, and escape through the northern gate.
Sword combat, physical arrows, two holy skills, and a compact chamber turn
a short encounter into a complete playable loop.

This is an independent development showcase maintained by StevenSu. It
documents an agent's work in an existing Godot project: gameplay implementation,
scripted asset creation, integration, testing, and engine-recorded review.
The character and dungeon artwork have separate origins. See the
[workflow](docs/AGENT_WORKFLOW.md) for the scope of the example.

## Run

Use **Godot 4.6.3**, standard GDScript build, with the Compatibility renderer.
Python 3 is used by the optional command-line helpers.

**This is a source release with external artwork dependencies.** The prepared
paladin, sword, melee skeleton, and native dungeon assets are not distributed
in Git because their original-file redistribution permissions have not been
established. A fresh checkout displays an asset-setup screen until they are
provided. It does not download them automatically.

```sh
git clone https://github.com/stevensu1977/kingdom-of-swords.git
cd kingdom-of-swords
python3 tools/check_assets.py
# Supply the compatible, separately licensed files described in docs/ASSETS.md.
godot --headless --path . --import
godot --path .
```

Reading the code, rebuilding the original props and sounds, and running the
publication audit do not require the external artwork. Playing the original
encounter and running its gameplay tests do.

## Play

| Input | Action |
|---|---|
| WASD / mouse | Move / aim |
| Hold left mouse button | Strike |
| Space | Directional evade |
| Q | Consecration: a healing and burning ground field |
| F | Divine Shield: brief immunity |
| E | Kindle a cleared seal or use the open exit |
| Escape | Pause / resume |
| R | Restart after an ending |
| N / BGM button | Toggle background music; saved between sessions |
| M | Temporarily toggle all game audio |

Each of the three seals restores **30 HP**. The final watch includes an
Oathbreaker. Archers telegraph their aim, fire moving arrows, and can be
interrupted; walls, pillars, crates, and altar bases provide cover.
Completing the encounter records your best time locally.

| Skill | Effect | Cooldown |
|---|---|---|
| Consecration | Six pulses over six seconds in a 3 m field; each heals 4% max HP and deals 6 holy damage, with a 12% chance of +2 damage | 18 s |
| Divine Shield | Three seconds of immunity to direct and periodic damage | 24 s |

## What the showcase contains

- A complete encounter: title, three mixed waves, three seals, extraction,
  victory/defeat, pause, restart, audio preferences, and local records.
- GDScript movement, combat, projectile collision, skill timing, UI, and effects.
- Blender Python builders for the original altar, crown seal, and arrow.
- Reproducible synthesis for combat cues, holy chimes, and ambient music.
- Gameplay fixtures and a normal-input combat driver.
- A script for an 18-second recording using Godot's Movie Writer.

The public copy focuses on the sanctuary. Unrelated shooter, farm, lab, and
warehouse examples are outside this release.
The selected recording shows the original game, including its BGM switch.
It predates the public copy's menu cleanup. The cover is a still from that
recording.

## Art and assets

The chamber uses a fixed orthographic camera at 55 degrees. Blue-green stone
and cool shadows contrast with amber torchlight, brass inlays, ivory lettering,
and warm combat sparks. Large silhouettes and an open center keep attacks
readable. The three altars form a broad triangle; the Warden arrives in the
southwest corner.

| Asset | Source / builder | In-game scale | Distribution |
|---|---|---|---|
| Paladin, greatsword, melee skeleton | Compatible prepared characters; see `assets/characters/character.json` | Hero 2.05 m; skeleton 1.95 m | External |
| Dungeon floors, walls, door, pillars, props | Nine native scene roles in `assets/template/dungeon.json` | 20 × 26 m room | External |
| Skeleton archer | ilyakardailskiy; adapted rig and run/draw/shoot clips | 1.92 m | Recorded CC BY 4.0; attribution retained |
| Ember altar | `tools/build_ember_props.py` | 1.74 m wide, 1.66 m tall | MIT |
| Crown seal | `tools/build_ember_props.py` | 2 m model, displayed at 4.6 m | MIT |
| Flying arrow | `tools/build_archer_projectile.py` | 1.04 m long | MIT |
| Holy effects and icon | GDScript effects / SVG | 3 m field; actor-sized shield | MIT |
| Combat and skill sounds | `tools/build_*audio.py` | Short mono cues, 24 kHz | MIT |
| Ambient music | `tools/build_ember_audio.py` | 48-second loop | MIT |
| Chambre Maudite | Optional local music override | Full-length loop | External; omitted |
| DejaVu fonts | Bitstream Vera / DejaVu / Arev terms | Scalable UI | Separate font licence |

The local music override is used when `assets/models/Chambre Maudite.ogg`
exists; otherwise the bundled procedural ambience plays. Both use the
independent BGM preference.

## Project status

Built: the encounter, two skills, mixed melee/ranged enemies, spread-out
altars, southwest arrival, and persisted BGM controls.

Public preparation includes a separate save directory, descriptive authoring
paths, a dependency checker, a startup screen for missing artwork, and an
audit of files eligible for Git.

Verification results are recorded in [VALIDATION.md](docs/VALIDATION.md).
Remaining: establish redistribution permissions or author open replacements
for the external characters and dungeon; review permissions before publishing
screenshots, recordings, or binaries containing that artwork.

## Licence

Project code and original assets are under the existing [MIT licence](LICENSE).
Third-party assets retain their own terms; the MIT licence does not relicense
them or the externally supplied files.

Read [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) and
[ASSETS.md](docs/ASSETS.md) before redistributing an asset or a built game.
