#!/usr/bin/env python3
"""PNG -> text grid: brings art drawn in Aseprite into the sprite pipeline.

The grids in tools/sprites/ stay the source of truth; this script only writes one.
Each pixel must be an exact palette colour (palette_edge.txt). Alpha 0 becomes '.',
alpha 255 becomes the colour's key, and anything else is an error. Transparency
comes from alpha, never from the colour, so a transparent pixel whose RGB equals
slot 0 (#0d0b14) still becomes '.'. Nothing is written until every pixel passes.

A horizontal strip is cut into equal frames, left to right, with --frames N or
--cell WxH. The frames go into one grid file, separated by one blank line, which
build_sprites.py renders back as the same strip.

Aseprite workflow:
  1. Load tools/sprites/palette_edge.gpl (committed; regenerate it with
     python3 tools/import_sprite.py --gpl tools/sprites/palette_edge.gpl after
     a palette change) as the sprite's palette (Palette menu > Load Palette).
     Its entry 0 is a spare magenta "transparent" slot: in an Indexed sprite,
     Aseprite treats index 0 as transparent, so no real colour sits there.
  2. Draw with those colours only, on a transparent layer, with no
     anti-aliasing or partial opacity. Never paint with the magenta slot.
  3. File > Export Sprite Sheet: Horizontal Strip, no borders, padding or
     trim (or File > Export As .png for one frame). RGBA or Indexed (with the
     transparent colour left at index 0) both work. 8-bit, one image.
  4. python3 tools/import_sprite.py run_export.png player_run --cell 16x24
  5. python3 tools/build_sprites.py, then re-import in Godot, and commit the
     grid, the PNG and its .import together.

Usage:
  import_sprite.py <png> <name> [--frames N | --cell WxH] [--palette PATH] [--force]
  import_sprite.py --gpl OUT [--palette PATH]
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_sprites import PALETTE_FILE, SPRITES, load_palette  # noqa: E402

NAME_RE = re.compile(r"[a-z0-9_]+")
GPL_TRANSPARENT = (255, 0, 255)  # index 0 of the .gpl: Aseprite's default transparent index


def check_name(name: str) -> None:
    """A bare grid name the builder accepts: lower snake case, not light (the generated
    light.png) and not palette_* (palette files)."""
    if not NAME_RE.fullmatch(name):
        raise ValueError(f"name {name!r}: a bare grid name like player_run (a-z, 0-9, _)")
    if name == "light" or name.startswith("palette_"):
        raise ValueError(f"name {name!r} is reserved (light.png is generated; palette_* are palettes)")


def png_bit_depth(png: Path) -> int | None:
    """The IHDR bit depth of a PNG file, or None when the file isn't a PNG."""
    with open(png, "rb") as f:
        head = f.read(25)
    if len(head) < 25 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return head[24]


def reverse_palette(palette: dict) -> dict[tuple[int, int, int], str]:
    """RGB -> key for every opaque key. Two keys with one RGB would make a PNG ambiguous."""
    rev: dict[tuple[int, int, int], str] = {}
    for key, rgba in palette.items():
        if key == ".":
            continue
        rgb = rgba[:3]
        if rgb in rev:
            raise ValueError(f"palette keys {rev[rgb]!r} and {key!r} share #{bytes(rgb).hex()}")
        rev[rgb] = key
    return rev


def frame_size(width: int, height: int, frames: int | None, cell: tuple[int, int] | None) -> tuple[int, int, int]:
    """(cell width, cell height, frame count) for a horizontal strip."""
    if frames is not None and cell is not None:
        raise ValueError("give --frames or --cell, not both")
    if cell is not None:
        cw, ch = cell
        if cw <= 0 or ch <= 0:
            raise ValueError(f"cell {cw}x{ch} must be positive")
        if ch != height:
            raise ValueError(f"cell height {ch} != image height {height} (strips are one row)")
        if width % cw:
            raise ValueError(f"image width {width} is not a multiple of the cell width {cw}")
        return cw, ch, width // cw
    n = 1 if frames is None else frames
    if n <= 0:
        raise ValueError(f"--frames {n} must be positive")
    if width % n:
        raise ValueError(f"image width {width} does not divide into {n} frames")
    return width // n, height, n


def png_to_frames(png: Path, palette: dict, frames: int | None = None,
                  cell: tuple[int, int] | None = None, palette_name: str = PALETTE_FILE.name) -> list[list[str]]:
    """The PNG's frames as grid rows. Raises ValueError naming the first bad pixel."""
    rev = reverse_palette(palette)
    depth = png_bit_depth(png)
    if depth is not None and depth > 8:
        raise ValueError(f"{png.name}: {depth}-bit PNG; export 8-bit (exact colours can't be matched at {depth} bits)")
    with Image.open(png) as src:
        if getattr(src, "n_frames", 1) > 1:
            raise ValueError(f"{png.name}: holds {src.n_frames} images (animated PNG); export a horizontal strip instead")
        img = src.convert("RGBA")  # applies an indexed PNG's transparency (tRNS) to alpha
    cw, ch, n = frame_size(img.width, img.height, frames, cell)
    px = img.load()
    out: list[list[str]] = []
    for f in range(n):
        rows: list[str] = []
        for y in range(ch):
            row = []
            for x in range(cw):
                r, g, b, a = px[f * cw + x, y]
                if a == 0:
                    row.append(".")
                elif a != 255:
                    raise ValueError(f"frame {f} ({x},{y}): alpha {a}; use fully opaque or fully transparent pixels")
                elif (r, g, b) in rev:
                    row.append(rev[(r, g, b)])
                else:
                    raise ValueError(f"frame {f} ({x},{y}): colour #{r:02x}{g:02x}{b:02x} not in {palette_name}")
            rows.append("".join(row))
        out.append(rows)
    return out


def frames_to_text(frames: list[list[str]]) -> str:
    return "\n\n".join("\n".join(rows) for rows in frames) + "\n"


def gpl_text(palette: dict, name: str) -> str:
    """The palette as a GIMP .gpl file (Aseprite loads it): a spare magenta transparent
    entry at index 0, then every key in palette-file order. In an Indexed sprite Aseprite
    treats index 0 as transparent, so slot 0 (the outline colour) must not sit there."""
    r, g, b = GPL_TRANSPARENT
    lines = ["GIMP Palette", f"Name: {name}", "Columns: 8", "#",
             f"{r:3d} {g:3d} {b:3d}\ttransparent (never paint with it)"]
    for key, (r, g, b, _a) in palette.items():
        if key != ".":
            lines.append(f"{r:3d} {g:3d} {b:3d}\t{key}")
    return "\n".join(lines) + "\n"


def write_atomic(dest: Path, text: str) -> None:
    """Write via a temp file in the same folder, then rename: a failed write never leaves
    a truncated file over the source grid. Always LF line endings (the laptop is Windows)."""
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=f".{dest.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, dest)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def parse_cell(s: str) -> tuple[int, int]:
    try:
        w, h = s.lower().split("x")
        return int(w), int(h)
    except ValueError:
        raise argparse.ArgumentTypeError(f"--cell expects WxH, e.g. 16x24 (got {s!r})") from None


def main(argv: list[str] | None = None, sprites_dir: Path = SPRITES) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("png", nargs="?", type=Path)
    ap.add_argument("name", nargs="?", help="grid name: writes <sprites>/<name>.txt")
    ap.add_argument("--frames", type=int)
    ap.add_argument("--cell", type=parse_cell)
    ap.add_argument("--palette", type=Path, default=PALETTE_FILE)
    ap.add_argument("--force", action="store_true", help="overwrite an existing grid")
    ap.add_argument("--gpl", type=Path, help="write the palette as a .gpl file and exit")
    args = ap.parse_args(argv)
    palette = load_palette(args.palette)
    if args.gpl is not None:
        if args.png is not None or args.name:
            raise ValueError("--gpl writes the palette only; run the import separately")
        if args.gpl.suffix != ".gpl":
            raise ValueError(f"{args.gpl}: the palette file must end in .gpl")
        write_atomic(args.gpl, gpl_text(palette, args.palette.stem))
        print(f"wrote {args.gpl}")
        return 0
    if args.png is None or not args.name:
        raise ValueError("give <png> <name>, or --gpl OUT")
    check_name(args.name)
    dest = sprites_dir / f"{args.name}.txt"
    if dest.exists() and not args.force:
        raise ValueError(f"{dest} exists; pass --force to overwrite it")
    frames = png_to_frames(args.png, palette, args.frames, args.cell, args.palette.name)
    write_atomic(dest, frames_to_text(frames))
    w, h = len(frames[0][0]), len(frames[0])
    print(f"wrote {dest} ({len(frames)} frame{'s' if len(frames) > 1 else ''} of {w}x{h})")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as err:
        print(f"error: {err}", file=sys.stderr)
        sys.exit(1)
