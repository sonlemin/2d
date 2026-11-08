#!/usr/bin/env python3
"""Sprite pipeline: text pixel grids + palette file -> PNGs in game/art/.

Every tools/sprites/<name>.txt grid becomes game/art/<name>.png. Each character
in a grid is a palette key, and '.' is transparent. The script also builds
light.png, a radial gradient used as the PointLight2D texture.

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
        hexcol = hexcol.strip().lstrip("#")
        if len(key) != 1 or len(hexcol) != 6:
            raise ValueError(f"{path.name}:{lineno}: expected '<char> #rrggbb', got {raw!r}")
        try:
            rgb = bytes.fromhex(hexcol)
        except ValueError:
            raise ValueError(f"{path.name}:{lineno}: invalid hex colour {hexcol!r}") from None
        palette[key] = (rgb[0], rgb[1], rgb[2], 255)
    return palette


def load_grid(path: Path) -> list[str]:
    rows = [r for r in path.read_text(encoding="utf-8-sig").splitlines() if r.strip()]
    if not rows:
        raise ValueError(f"{path.name}: empty grid")
    width = len(rows[0])
    for i, row in enumerate(rows, 1):
        if len(row) != width:
            raise ValueError(f"{path.name}:{i}: row width {len(row)} != {width}")
    return rows


def render(rows: list[str], palette: dict, name: str) -> Image.Image:
    img = Image.new("RGBA", (len(rows[0]), len(rows)))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in palette:
                raise ValueError(f"{name}: unknown palette key {ch!r} at ({x},{y})")
            px[x, y] = palette[ch]
    return img


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


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = load_palette(PALETTE_FILE)
    grids = sorted(p for p in SPRITES.glob("*.txt") if not p.name.startswith("palette_"))
    if any(g.stem == "light" for g in grids):
        raise ValueError("light.txt would be overwritten by the generated light.png; rename it")
    for grid in grids:
        img = render(load_grid(grid), palette, grid.name)
        img.save(OUT / f"{grid.stem}.png")
        print(f"wrote {OUT.relative_to(ROOT)}/{grid.stem}.png {img.size[0]}x{img.size[1]}")
    light_texture(LIGHT_SIZE).save(OUT / "light.png")
    print(f"wrote {OUT.relative_to(ROOT)}/light.png {LIGHT_SIZE}x{LIGHT_SIZE}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)
