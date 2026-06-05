# Ground Tiles — Iteration Log

**Started**: 2026-06-05
**Status**: IN PROGRESS
**Tiles needed**: 
- Base: grass, dirt, sand, shallow water, deep water
- Transitions: grass↔dirt (16), grass↔sand (16), dirt↔sand (16), grass↔water (16), sand↔water (16)
- Total: ~85 tiles

---

## Attempt 1

**Date**: 2026-06-05
**Tool**: `create_topdown_tileset`
**Parameters**:
```json
{
  "lower_description": "dirt path, brown earthy soil, dry ground",
  "upper_description": "green grass field, lush meadow, bright turf",
  "transition_size": 0.0,
  "tile_size": {"width": 16, "height": 16},
  "outline": "selective outline",
  "shading": "basic shading",
  "detail": "medium detail",
  "view": "high top-down",
  "tile_strength": 1.0,
  "text_guidance_scale": 10
}
```

**Output**: 
- Tileset ID: `6b009b3b-57ff-443b-a0df-2899472cba76`
- 16 tiles (64×64 PNG, 4×4 grid)
- Base tile IDs saved for chaining

**Visual Evaluation**:
| Criteria | Result |
|----------|--------|
| Dimensions | ✅ 16×16 tiles, 16 total |
| Palette | ✅ ~8-10 colors (under 16 limit) |
| Wang set | ✅ Corner-based transitions present |
| Style | ⚠️ Too noisy/ textured for classic JRPG |
| Seamless | ⚠️ Needs 3×3 grid test in Godot |

**Issues**:
1. **Grass texture too noisy** — has gravel/speckle texture that doesn't match FF1-6 clean flat style
2. **Dirt pattern visible** — repeating texture noticeable, classic JRPG dirt was flat color with minimal variation
3. **Selective outline is subtle** — might need stronger outlines for authentic 16-bit look
4. **Color vibrancy** — grass is bright but slightly oversaturated compared to NES/SNES palettes

**Adjustments for Attempt 2**:
- Change detail from "medium detail" → "low detail"
- Add prompt constraint: "flat colors, minimal texture, clean pixel art"
- Reduce text_guidance_scale to allow more style freedom
- Try "flat shading" instead of "basic shading"

**Status**: NEEDS_RETOUCH — acceptable foundation but requires cleaner, less noisy art for authentic JRPG feel.

---

## Attempt 2

**Date**: 2026-06-05
**Tool**: `create_topdown_tileset`
**Parameters**:
```json
{
  "lower_description": "dirt path, flat brown earth, minimal texture, clean pixel art",
  "upper_description": "green grass field, flat turf, minimal texture, clean pixel art",
  "transition_size": 0.0,
  "tile_size": {"width": 16, "height": 16},
  "outline": "selective outline",
  "shading": "flat shading",
  "detail": "low detail",
  "view": "high top-down",
  "tile_strength": 0.8,
  "text_guidance_scale": 6
}
```

**Output**:
- Tileset ID: `0043ec18-d233-43f5-a18a-533b70f2a05b`
- 16 tiles (64×64 PNG, 4×4 grid)
- Style: selective outline, flat shading, low detail

**Visual Evaluation**:
| Criteria | Result |
|----------|--------|
| Dimensions | ✅ 16×16 tiles, 16 total |
| Grass texture | ✅ Cleaner than Attempt 1 |
| Dirt texture | ✅ Flatter than Attempt 1 |
| Style | ⚠️ Added unwanted props (rocks, flowers) |

**Issues**:
1. **Unwanted props** — "low detail" caused AI to add small rocks on dirt and flower dots on grass instead of making truly flat terrain
2. **Props won't tile seamlessly** — scattered rocks/flowers create visible repetition in large maps
3. **Still not pure JRPG style** — needs to be cleaner, more uniform

**Adjustments for Attempt 3**:
- Explicitly forbid props: "no rocks, no flowers, no props, pure terrain only"
- Try "single color outline" for stronger JRPG look
- Increase `tile_strength` back to 1.0+ for consistency
- Use "medium detail" but add "smooth, uniform surface"

**Status**: NEEDS_RETOUCH — cleaner base but prop contamination makes it unsuitable.

---

## Attempt 3 ✅ ACCEPTED

**Date**: 2026-06-05
**Tool**: `create_topdown_tileset`
**Parameters**:
```json
{
  "lower_description": "dirt ground, smooth brown earth, no rocks, no props, pure terrain",
  "upper_description": "green grass, smooth turf, no flowers, no props, pure terrain",
  "transition_size": 0.0,
  "tile_size": {"width": 16, "height": 16},
  "outline": "single color outline",
  "shading": "flat shading",
  "detail": "medium detail",
  "view": "high top-down",
  "tile_strength": 1.2,
  "text_guidance_scale": 8
}
```

**Output**:
- Tileset ID: `1b5029eb-ae23-4b59-989f-e6e2fbbd8cd5`
- 16 tiles (64×64 PNG, 4×4 grid)
- Style: single color outline, flat shading, medium detail
- File: `assets/tilesets/generated/attempt3_grass_dirt.png`

**Visual Evaluation**:
| Criteria | Result |
|----------|--------|
| Dimensions | ✅ 16×16 tiles, 16 total |
| Grass texture | ✅ Clean, flat, no props |
| Dirt texture | ✅ Smooth, flat, no rocks |
| Props | ✅ None — pure terrain only |
| Outline | ✅ Visible single-color outline |
| Style | ✅ Authentic JRPG look |
| Seamless | ⚠️ Needs 3×3 grid test in Godot |

**Comparison**:
| | Attempt 1 | Attempt 2 | Attempt 3 |
|--|-----------|-----------|-----------|
| Grass | Noisy, gravel | Clean + flowers | ✅ Clean, flat |
| Dirt | Patterned | Flat + rocks | ✅ Smooth, flat |
| Props | None | Rocks + flowers | ✅ None |
| Outline | Subtle | Subtle | ✅ Visible |

**Key learnings**:
1. **"No props" constraint works** — explicit negative prompts prevent AI from adding decorative elements
2. **"Single color outline" > "selective outline"** — stronger, more authentic 16-bit look
3. **"Medium detail" + "smooth" > "low detail"** — low detail caused prop contamination
4. **Higher `tile_strength` (1.2)** — better consistency than 0.8

**Status**: ✅ ACCEPTED — clean, authentic JRPG style. Ready for seamless tiling test.

---

## Curated Selection

| Tile | File | Source Attempt | Notes |
|------|------|----------------|-------|
| Grass base | | Attempt 3 | Curated from attempt3_grass_dirt.png |
| Dirt base | | Attempt 3 | Curated from attempt3_grass_dirt.png |
| Sand base | | | |
| Shallow water | | | |
| Deep water | | | |
| Grass↔Dirt (16) | | Attempt 3 | Complete Wang set |
| Grass↔Sand (16) | | | |
| Dirt↔Sand (16) | | | |
| Grass↔Water (16) | | | |
| Sand↔Water (16) | | | |
