# Working on Kingdom of Swords

This repository is a Godot 4.6.3 GDScript project. Read README.md,
docs/BUILDING.md, and docs/ASSETS.md before changing it.

- Keep the sanctuary's movement, combat, and asset interfaces understandable.
- Update README.md when features, controls, or asset provenance change.
- Keep original asset builders and their dependencies reproducible.
- Use `scenes/build_ember.gd` to rebuild entry scenes.
- Keep runtime movement/collision separate from animation presentation.
- Run checks appropriate to the change; record and review gameplay when
  changing visuals, combat behavior, or the player experience.
- Run `python3 tools/audit_public.py` before staging files.
- Never add ignored external artwork without its applicable redistribution
  permission and attribution. Do not embed private paths, tokens, or IDs.
- Do not publish builds or media merely because local tests pass.

The public copy includes a startup screen for missing external dependencies.
Use `tools/verify.py --source-only` when those dependencies are unavailable.
