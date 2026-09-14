# How this game was developed

The project is shared by its maintainer as an Astra development showcase.
The repository preserves the resulting implementation and reproducible
scripts. It is not a full agent transcript or an audit of which model
produced every file.

## Division of work

The human sets the brief, supplies or selects assets, reviews the running
game, and directs changes. Agent work includes gameplay implementation,
asset adaptation and integration, original procedural props and effects,
tests, builds, and review captures.

The game started from an existing Godot foundation. Prepared characters,
animations, and native dungeon scenes were inputs. Their geometry and
animation authorship are distinct from the new game logic. The archer
adaptation has its own source attribution and authoring scripts.

## Blender: original props from code

`tools/build_ember_props.py` begins with an empty scene, defines materials,
builds an altar and crown seal, applies modifiers and transforms, exports
one GLB per model, and renders an inspection image. Each prop is below
3,000 triangles. `tools/build_archer_projectile.py` builds the flying arrow.

```sh
blender -b --python tools/build_ember_props.py
blender -b --python tools/build_archer_projectile.py
```

The builders are repository-relative. Runtime exports live in
`assets/models/`; generated review images are ignored by Git.

`tools/archer/` contains the separately attributed character adaptation:
a static authoring source, the rigged source, and animation/review scripts.
It is not an original-from-scratch character model. Rebuilding it is optional.
See [BUILDING.md](BUILDING.md).

## Godot: entry scenes and runtime composition

`scenes/build_ember.gd` saves small entry scenes with their scripts attached.
It sets ownership and compares node counts after packing. The environment,
actors, UI, and effects are then composed by runtime GDScript.

The existing character visual controller plays prepared clips. The archer
adapter exposes `play_action`, `set_move_speed`, and `motion_event`; the
game creates an arrow at the configured `shoot / arrow_release` event.
There is no generic character motion-package controller in this snapshot.
Movement, collision, health, and damage remain in game code.

## Verification loop

1. Import changed assets and parse changed scripts.
2. Instantiate game scenes and external dungeon leaves.
3. Check encounter transitions, healing/damage, immunity, projectiles,
   pause/restart, and persisted BGM controls.
4. Drive a complete combat run with normal movement/attack/skill commands.
5. Record an 18-second sequence with Godot's Movie Writer and review it.

State fixtures deliberately set up isolated situations; the full combat
driver uses the normal game rules. Fixed-step capture and seeded skill
randomness make the demonstration repeatable, without claiming bitwise
determinism across operating systems or renderers.

## What can be reproduced from this repository

The original props, sounds, scene entry points, tests, and capture process
have scripts and documented commands. Reproducing the original visual game
also requires the compatible external artwork described in [ASSETS.md](ASSETS.md).
The Blender executable is only needed for rebuilding models; Godot consumes
the checked-in GLB exports.
