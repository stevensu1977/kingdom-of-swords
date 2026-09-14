# Contributing

Use Godot 4.6.3 and read [BUILDING.md](docs/BUILDING.md). The original
visual encounter has external dependencies; [ASSETS.md](docs/ASSETS.md)
explains how the public source checkout differs from a configured local game.

Keep movement and collision in game code. Treat character rigs and authored
clip timings as asset contracts. Gameplay changes should include a focused
regression check when they affect combat, state transitions, or saved data.

For asset work, retain source builders, record dependencies and licences,
and review the resulting model in the running scene. Do not commit private
asset downloads, editor caches, build outputs, credentials, or review media
whose publication rights are unresolved.

Before proposing a change:

```sh
python3 tools/audit_public.py
python3 tools/verify.py
git diff --check
```

For a source-only checkout, use `python3 tools/verify.py --source-only`.
Explain what changed, why, which checks you ran, and any remaining limits.
