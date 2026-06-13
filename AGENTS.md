# AGENTS.md

Godot 4.6 project (GDScript). There is no test suite or linter. Verify changes with:

## Compile / import check (no errors expected)
```bash
godot --headless --import
```

## Runtime check (should run until killed; ignore benign warnings)
```bash
godot --headless --path .
```
Benign noise to ignore: `Image.load_from_file` "will not work on export" warnings,
missing `assets/icon.png`, and ALSA errors under virtual displays. Real problems
appear as `SCRIPT ERROR` / `Parse Error`.

## Rebuild the island scene
After editing `scripts/build_island.gd`:
```bash
godot --headless --script scripts/build_island.gd
```

## Render a screenshot (verifies visuals)
Headless mode cannot capture viewports; use a virtual display:
```bash
xvfb-run -a -s "-screen 0 640x480x24" godot res://scenes/render_test.tscn
```

## Conventions
- Assets load via `Image.load_from_file()`, so `.import`/`.uid` artifacts are
  gitignored and intentionally not committed.
- When generating the scene from `build_island.gd`: dynamically-added nodes MUST
  have `owner` set to the scene root, or `PackedScene.pack()` drops them. The
  `set_owners_recursive()` helper handles this — don't remove it.
- `build_island.gd` no longer writes `player.gd`; keep the player script as the
  source of truth and edit it directly.
