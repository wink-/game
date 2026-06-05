# Pixellab Art Pipeline

## Prompt Structure

All prompts follow this template:

```
Style: 16-bit JRPG overworld (Final Fantasy 1-6, Dragon Warrior 1-3, Chrono Trigger)
Perspective: Top-down, south-facing
Palette: 16 colors max, NES/SNES era limitations
Tile size: 16x16 pixels
Seamless: Must tile seamlessly in all 4 directions
Category: [GROUND/TRANSITION/PROP/BUILDING]
Tiles: [SPECIFIC_TILE_LIST]
Constraints: [SEAMLESS/PALETTE/STYLE NOTES]
```

## Categories

| Category | Description | Example |
|----------|-------------|---------|
| **GROUND** | Base terrain tiles | Grass, dirt, sand, water |
| **TRANSITION** | Edge/corner blends | Grass↔dirt, sand↔water |
| **PROP** | Decorative objects | Trees, rocks, flowers |
| **BUILDING** | Structures | Walls, roofs, doors |

## Validation Checklist (Per Generation)

Before accepting a generated tileset:

- [ ] **Dimensions**: All tiles exactly 16×16
- [ ] **Seamless**: 3×3 grid test shows no visible seams
- [ ] **Palette**: ≤ 16 colors per tileset
- [ ] **Style**: Matches FF/DW 16-bit aesthetic
- [ ] **Transitions**: Complete Wang set (16 tiles for 2-terrain, 47 for 3+)
- [ ] **Consistency**: All tiles look like they belong together

## Iteration Log Format

```markdown
### Attempt [N]
**Date**: YYYY-MM-DD
**Prompt**: [Full prompt used]
**Output**: [Description of what came back]
**Issues**: [What went wrong]
**Adjustments**: [What to change next]
**Status**: [REJECTED / ACCEPTED / NEEDS_RETOUCH]
```

## Curation Workflow

1. Generate batch → `assets/tilesets/generated/`
2. Run validation script
3. Visual review (3×3 test grid in Godot)
4. Hand-pick best tiles → `assets/tilesets/curated/`
5. Name consistently: `[category]_[type]_[variant].png`
6. Regenerate TileSet resource
7. Update TileMap in scene

## File Organization

```
assets/tilesets/
├── prompts/           # Prompt logs and iteration history
├── generated/         # Raw Pixellab output (gitignored)
├── curated/           # Hand-selected, cleaned tiles
│   ├── ground/
│   ├── transition/
│   ├── prop/
│   └── building/
├── preview/           # Test scenes for visual review
└── tileset.tres       # Godot TileSet resource
```

## Naming Convention

`[category]_[type]_[number].[extension]`

Examples:
- `ground_grass_01.png`
- `transition_grass_dirt_01.png` (01-16 for Wang set)
- `prop_tree_pine_01.png`

## Color Palette Rules

- Max 16 colors per tileset
- Shared palette across related tiles (e.g., all ground tiles share a palette)
- Use NES/SNES limited palettes as reference
- Avoid gradients — flat colors with 1-2 shade steps max
