#!/usr/bin/env python3
"""Sprite pipeline: text pixel grids + palette file -> PNGs in game/art/.

Every tools/sprites/<name>.txt grid becomes game/art/<name>.png. Each character
in a grid is a palette key, and '.' is transparent. A grid file may hold several
equal-size frames separated by exactly one empty line; they render left to right
as one horizontal strip (what a Sprite2D with hframes reads). A whitespace-only
row, or two empty lines in a row between frames, is an error, so a stray blank
line can't silently cut a sprite into frames. A file with one frame
renders exactly as before. The script also builds light.png, a radial gradient
used as the PointLight2D texture.

Grids drawn in Aseprite come in through tools/import_sprite.py.

Usage: python3 tools/build_sprites.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "tools" / "sprites"
OUT = ROOT / "game" / "art"
PALETTE_FILE = SPRITES / "palette_edge.txt"
LIGHT_SIZE = 128


def load_palette(path: Path) -> dict[str, tuple[int, int, int, int]]:
    palette: dict[str, tuple[int, int, int, int]] = {".": (0, 0, 0, 0)}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, _, hexcol = line.partition(" ")
        if key == ".":
            raise ValueError(f"{path.name}:{lineno}: '.' is always transparent and can't be a palette key")
        hexcol = hexcol.strip().lstrip("#")
        if len(key) != 1 or len(hexcol) != 6:
            raise ValueError(f"{path.name}:{lineno}: expected '<char> #rrggbb', got {raw!r}")
        try:
            rgb = bytes.fromhex(hexcol)
        except ValueError:
            raise ValueError(f"{path.name}:{lineno}: invalid hex colour {hexcol!r}") from None
        palette[key] = (rgb[0], rgb[1], rgb[2], 255)
    return palette


def load_frames(path: Path) -> list[list[str]]:
    """The file's frames: runs of rows split by exactly one empty line (empty lines at the
    start and end are ignored). Every frame must have equal-width rows and the same size
    as the first. Errors name the file line."""
    frames: list[list[str]] = []
    current: list[str] = []
    starts: list[int] = []
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    last = max((i for i, r in enumerate(lines) if r != ""), default=-1)
    gap = 0  # empty lines since the last row
    for lineno, raw in enumerate(lines, 1):
        if raw == "":
            if current:
                frames.append(current)
                current = []
            gap += 1
            continue
        if not raw.strip():
            raise ValueError(f"{path.name}:{lineno}: whitespace-only row; frames are split by an empty line")
        if frames and gap > 1 and lineno - 1 <= last:
            raise ValueError(f"{path.name}:{lineno}: {gap} empty lines between frames; use exactly one")
        gap = 0
        if not current:
            starts.append(lineno)
        current.append(raw)
        width = len(current[0])
        if len(raw) != width:
            raise ValueError(f"{path.name}:{lineno}: row width {len(raw)} != {width}")
    if current:
        frames.append(current)
    if not frames:
        raise ValueError(f"{path.name}: empty grid")
    w, h = len(frames[0][0]), len(frames[0])
    for i, frame in enumerate(frames[1:], 1):
        if (len(frame[0]), len(frame)) != (w, h):
            raise ValueError(
                f"{path.name}:{starts[i]}: frame {i} is {len(frame[0])}x{len(frame)}, frame 0 is {w}x{h}")
    return frames


def load_grid(path: Path) -> list[str]:
    """A one-frame file's rows (kept for callers that expect a single grid)."""
    frames = load_frames(path)
    if len(frames) != 1:
        raise ValueError(f"{path.name}: {len(frames)} frames, expected 1")
    return frames[0]


def render(rows: list[str], palette: dict, name: str) -> Image.Image:
    img = Image.new("RGBA", (len(rows[0]), len(rows)))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in palette:
                raise ValueError(f"{name}: unknown palette key {ch!r} at ({x},{y})")
            px[x, y] = palette[ch]
    return img


def render_strip(frames: list[list[str]], palette: dict, name: str) -> Image.Image:
    """Frames left to right, in file order, in one image."""
    w, h = len(frames[0][0]), len(frames[0])
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, frame in enumerate(frames):
        strip.paste(render(frame, palette, f"{name} frame {i}"), (i * w, 0))
    return strip


def light_texture(size: int) -> Image.Image:
    """White radial gradient with alpha falloff; smoothstep edge so the rim stays soft."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = min(1.0, math.hypot(x - c, y - c) / c)
            t = 1.0 - d
            a = t * t * (3 - 2 * t)
            px[x, y] = (255, 255, 255, int(a * 255))
    return img


def main(sprites: Path = SPRITES, out: Path = OUT) -> int:
    out.mkdir(parents=True, exist_ok=True)
    palette = load_palette(sprites / PALETTE_FILE.name)
    grids = sorted(p for p in sprites.glob("*.txt") if not p.name.startswith("palette_"))
    if any(g.stem == "light" for g in grids):
        raise ValueError("light.txt would be overwritten by the generated light.png; rename it")
    for grid in grids:
        frames = load_frames(grid)
        img = render_strip(frames, palette, grid.name)
        img.save(out / f"{grid.stem}.png")
        extra = f" ({len(frames)} frames)" if len(frames) > 1 else ""
        print(f"wrote {_shown(out)}/{grid.stem}.png {img.size[0]}x{img.size[1]}{extra}")
    light_texture(LIGHT_SIZE).save(out / "light.png")
    print(f"wrote {_shown(out)}/light.png {LIGHT_SIZE}x{LIGHT_SIZE}")
    return 0


def _shown(p: Path) -> str:
    try:
        return str(p.relative_to(ROOT))
    except ValueError:
        return str(p)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)
