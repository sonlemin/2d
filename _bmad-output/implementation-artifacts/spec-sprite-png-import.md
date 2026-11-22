---
title: 'Import Aseprite PNGs into the text-grid sprite pipeline'
type: 'feature'
created: '2026-11-22'
status: 'done'
baseline_commit: 'e053832'
context: ['{project-root}/_bmad-output/project-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** sonlm draws and animates in Aseprite, but the game's sprite source is text grids (`tools/sprites/*.txt` → `tools/build_sprites.py` → `game/art/*.png`), and there is no way to turn a PNG into a grid, nor to hold animation frames.

**Approach:** a new `tools/import_sprite.py` converts a PNG (indexed or RGBA) into a grid by exact colour match against the palette file, keeping transparency as `.`, distinct from slot 0. A grid file may hold several equal-size frames separated by one blank line; `build_sprites.py` renders those left to right as one strip PNG. Single-frame grids are unchanged.

## Boundaries & Constraints

**Always:**
- Text grids stay the source of truth. The importer writes `tools/sprites/<name>.txt`; only `build_sprites.py` writes `game/art/`.
- Exact colour match against `palette_edge.txt` keys. Alpha 0 → `.`; alpha 255 → its key. Any other alpha, or an unknown colour, is an error naming the frame, x and y. Never nearest-colour.
- Transparency is decided by alpha after `convert("RGBA")`, so an indexed PNG's transparent index maps to `.` even when its RGB equals slot 0 (`#0d0b14`).
- Strip frames are cut left to right in order, all the same size.
- Round trip: grid → build → PNG → import gives byte-identical grid text.
- Python 3 + Pillow only (stdlib `unittest` for tests); no new dependency.

**Ask First:** overwriting an existing grid (the importer refuses unless `--force`); changing any existing PNG's pixels; wiring frames into Godot scenes (`hframes`, animations).

**Never:** hand-edit or hand-create files in `game/art/`; touch game code or scenes; change the palette's colours; add multi-palette or zone-swap logic.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| One frame | 16×24 PNG, palette colours + transparent | grid with 24 rows of 16 chars | N/A |
| Strip | 96×24 PNG, `--frames 6` (or `--cell 16x24`) | 6 frames, blank line between, left-to-right order | N/A |
| Indexed, transparent index = `#0d0b14` | P-mode PNG with tRNS on that index, and the same RGB opaque elsewhere | transparent pixels `.`, opaque ones `0` | N/A |
| Unknown colour | a pixel not in the palette | no file written | exit 1, `frame f (x,y): colour #rrggbb not in palette_edge.txt` |
| Partial alpha | alpha 1–254 | no file written | exit 1, naming the pixel |
| Bad strip width | width not a multiple of the cell, or `--frames` not dividing it | no file written | exit 1 |
| Existing grid | `<name>.txt` exists, no `--force` | no file written | exit 1, says `--force` |
| Unequal frames in a grid | build of a file with frames of different sizes | no PNG written | `build_sprites.py` exits 1 naming the file |

</frozen-after-approval>

## Code Map

- `tools/build_sprites.py` -- palette and grid loading, `render()`; extend `load_grid` to split frames on blank lines and render a horizontal strip.
- `tools/sprites/palette_edge.txt` -- the colour keys (`0`–`3`, `L`, `E`, `e`); read-only here.
- `tools/sprites/player.txt` -- the existing 16×24 player frame, used as the round-trip fixture (original art).
- `docs/development-guide.md` (around line 170), `docs/architecture.md:187`, `docs/source-tree-analysis.md:118` -- the art workflow docs.

## Tasks & Acceptance

**Execution:**
- [x] `tools/build_sprites.py` -- `load_frames(path) -> list[list[str]]`: frames are runs of non-blank rows split by blank lines; each is validated as now, and all must match the first frame's size. `render_strip(frames, palette, name)` pastes them left to right. `main()` uses them, so a one-frame file renders exactly as before. Expose `load_palette` / `load_frames` for the importer.
- [x] `tools/import_sprite.py` -- CLI `import_sprite.py <png> <name> [--frames N | --cell WxH] [--palette PATH] [--force] [--gpl OUT]`. It reverses the palette (RGB → key; an error if two keys share an RGB), converts to RGBA, cuts frames, maps pixels and writes the grid only after every pixel has passed. `--gpl OUT` writes the palette as a GIMP `.gpl` file that Aseprite can load, so drawings use the exact colours. Module docstring with the Aseprite export steps.
- [x] `tools/test_sprites.py` -- unittest over temporary dirs (never the real `tools/sprites/` or `game/art/`): every matrix row; the `player.txt` round trip; a 3-frame strip round trip whose frames are distinct, proving order; unchanged rendering of every existing grid (each rebuilt PNG equals the committed one pixel for pixel).
- [x] `docs/development-guide.md` -- an "Art from Aseprite" subsection: palette `.gpl`, export PNG (indexed or RGBA, no partial alpha), `import_sprite.py`, then `build_sprites.py`, re-import in Godot, commit grid + PNG + `.import`; the strip format; the test command. One-line mentions in `docs/architecture.md` and `docs/source-tree-analysis.md`.

**Acceptance Criteria:**
- Given the committed grids, when `python3 tools/build_sprites.py` runs, then every PNG in `game/art/` is pixel-identical to before (`git status` shows no change).
- Given the test command, when it runs, then every test passes.

## Design Notes

Strip grid format (2 frames, 4×2 each):

```
.01.
0LL0

.10.
0EE0
```

A blank line can't appear inside a frame, because `load_grid` already drops empty rows and no current grid has one (checked). So the split is backward-compatible. A horizontal strip PNG is what a `Sprite2D` with `hframes` or an `AtlasTexture` reads.

## Verification

**Commands:**
- `python3 -m unittest discover -s tools -p 'test_*.py' -v` -- expected: OK
- `python3 tools/build_sprites.py && git status --short game/art` -- expected: no changes

## Suggested Review Order

**Importing a PNG**

- Entry point: the import, in order: name, overwrite guard, pixels, atomic write.
  [`import_sprite.py:174`](../../tools/import_sprite.py#L174)

- Alpha decides transparency before any colour lookup; partial alpha and unknown colours stop it.
  [`import_sprite.py:123`](../../tools/import_sprite.py#L123)

- Refuses animated and 16-bit PNGs that Pillow would silently flatten or truncate.
  [`import_sprite.py:103`](../../tools/import_sprite.py#L103)

- Strip cutting: --frames or --cell, one row, equal cells.
  [`import_sprite.py:82`](../../tools/import_sprite.py#L82)

- Names the builder accepts; light and palette_* are reserved.
  [`import_sprite.py:51`](../../tools/import_sprite.py#L51)

- Temp file + rename, LF endings: a failed write never truncates a source grid.
  [`import_sprite.py:153`](../../tools/import_sprite.py#L153)

**The Aseprite palette**

- A spare magenta slot at index 0, so Aseprite's transparent index never eats slot 0.
  [`import_sprite.py:140`](../../tools/import_sprite.py#L140)

**Building strips**

- Frames split by exactly one empty line; stray blanks are errors, not silent cuts.
  [`build_sprites.py:52`](../../tools/build_sprites.py#L52)

- Frames pasted left to right in file order; one frame renders as before.
  [`build_sprites.py:111`](../../tools/build_sprites.py#L111)

- '.' can never be redefined as an opaque palette colour.
  [`build_sprites.py:39`](../../tools/build_sprites.py#L39)

**Tests and docs**

- Round trip on the game's own player frame.
  [`test_sprites.py:69`](../../tools/test_sprites.py#L69)

- Aseprite indexed export with the .gpl order keeps outlines.
  [`test_sprites.py:126`](../../tools/test_sprites.py#L126)

- Every committed grid still rebuilds its committed PNG, pixel for pixel.
  [`test_sprites.py:317`](../../tools/test_sprites.py#L317)

- The committed .gpl can't go stale.
  [`test_sprites.py:340`](../../tools/test_sprites.py#L340)

- The Aseprite workflow for sonlm.
  [`development-guide.md:178`](../../docs/development-guide.md#L178)
