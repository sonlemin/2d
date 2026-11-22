"""Tests for the sprite pipeline: build_sprites.py (grids -> PNG strips) and
import_sprite.py (PNG -> grid). Every test works in a temporary directory and
never writes to tools/sprites/ or game/art/.

Run from the repo root: python3 -m unittest discover -s tools -p 'test_*.py' -v
"""
from __future__ import annotations

import io
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_sprites  # noqa: E402
import import_sprite  # noqa: E402

PALETTE = build_sprites.load_palette(build_sprites.PALETTE_FILE)
SLOT0 = PALETTE["0"][:3]  # #0d0b14
TOOLS = Path(__file__).resolve().parent


def pixels(img: Image.Image) -> bytes:
    return img.convert("RGBA").tobytes()


def rgba(key: str) -> tuple[int, int, int, int]:
    return PALETTE[key]


class TmpDir(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, name: str, text: str) -> Path:
        p = self.dir / name
        p.write_text(text, encoding="utf-8")
        return p

    def png_from_text(self, text: str, name: str = "src.png") -> Path:
        """A PNG built by the real builder from grid text (strip for several frames)."""
        grid = self.write("src_" + name.replace(".png", ".txt"), text)  # never the import target
        img = build_sprites.render_strip(build_sprites.load_frames(grid), PALETTE, grid.name)
        out = self.dir / name
        img.save(out)
        return out

    def run_import(self, argv: list[str]) -> tuple[int, str]:
        err = io.StringIO()
        with redirect_stderr(err), redirect_stdout(io.StringIO()):
            try:
                code = import_sprite.main(argv, sprites_dir=self.dir)
            except ValueError as e:
                print(f"error: {e}", file=sys.stderr)
                code = 1
        return code, err.getvalue()


class RoundTrip(TmpDir):
    def test_player_frame_round_trips(self) -> None:
        # The game's own 16x24 player (original art) is the one-frame fixture.
        src = (build_sprites.SPRITES / "player.txt").read_text(encoding="utf-8")
        png = self.png_from_text(src, "player_src.png")
        code, err = self.run_import([str(png), "player_rt"])
        self.assertEqual(code, 0, err)
        out = (self.dir / "player_rt.txt").read_text(encoding="utf-8")
        self.assertEqual(out, src.rstrip("\n") + "\n")
        rows = out.splitlines()
        self.assertEqual((len(rows[0]), len(rows)), (16, 24))

    def test_strip_keeps_frame_order(self) -> None:
        frames = ["0..1\n.LL.", "1..2\n.EE.", "2..3\n.33."]  # distinct, so order shows
        src = "\n\n".join(frames) + "\n"
        png = self.png_from_text(src, "strip.png")
        with Image.open(png) as im:
            self.assertEqual(im.size, (12, 2))
        for argv in (["--frames", "3"], ["--cell", "4x2"]):
            with self.subTest(argv=argv):
                code, err = self.run_import([str(png), "strip_rt", "--force", *argv])
                self.assertEqual(code, 0, err)
                self.assertEqual((self.dir / "strip_rt.txt").read_text(encoding="utf-8"), src)

    def test_rgba_and_indexed_give_the_same_grid(self) -> None:
        src = "0L.\n.21\n"
        png = self.png_from_text(src, "rgba.png")
        code, err = self.run_import([str(png), "rgba_rt"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "rgba_rt.txt").read_text(encoding="utf-8"), src)
        # The same pixels as a true indexed PNG, index 0 transparent (Aseprite's indexed export).
        pal_img = Image.new("P", (3, 2))
        keys = [".", "0", "L", "2", "1"]
        flat: list[int] = []
        for k in keys:
            flat += list(PALETTE[k][:3])
        pal_img.putpalette(flat + [0] * (768 - len(flat)))
        idx = {k: i for i, k in enumerate(keys)}
        for y, row in enumerate(src.splitlines()):
            for x, ch in enumerate(row):
                pal_img.putpixel((x, y), idx[ch])
        p = self.dir / "indexed.png"
        pal_img.save(p, transparency=0)
        code, err = self.run_import([str(p), "indexed_rt"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "indexed_rt.txt").read_text(encoding="utf-8"), src)

    def test_png_from_literal_hex_colours(self) -> None:
        # Built without the builder or the palette parser, so a shared bug can't pass both sides.
        img = Image.new("RGBA", (4, 1))
        for x, c in enumerate([(0x0d, 0x0b, 0x14, 255), (0x2a, 0x24, 0x40, 255), (0xff, 0xd2, 0x7a, 255), (9, 9, 9, 0)]):
            img.putpixel((x, 0), c)
        p = self.dir / "hex.png"
        img.save(p)
        code, err = self.run_import([str(p), "hex_rt"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "hex_rt.txt").read_text(encoding="utf-8"), "01L.\n")

    def test_aseprite_indexed_with_the_gpl_palette_keeps_slot0(self) -> None:
        # Aseprite's indexed export: the .gpl's order, index 0 (magenta) transparent. Outlines in
        # slot 0 sit at index 1, so they survive; the magenta slot is never a real colour.
        entries = [import_sprite.GPL_TRANSPARENT] + [PALETTE[k][:3] for k in PALETTE if k != "."]
        img = Image.new("P", (3, 1))
        img.putpalette([v for rgb in entries for v in rgb] + [0] * (768 - 3 * len(entries)))
        for x, i in enumerate([0, 1, 2]):  # transparent, slot 0, slot 1
            img.putpixel((x, 0), i)
        p = self.dir / "ase.png"
        img.save(p, transparency=0)
        code, err = self.run_import([str(p), "ase"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "ase.txt").read_text(encoding="utf-8"), ".01\n")

    def test_grids_are_written_with_lf(self) -> None:
        p = self.png_from_text("01\n23\n", "lf.png")
        self.run_import([str(p), "lf"])
        self.assertEqual((self.dir / "lf.txt").read_bytes(), b"01\n23\n")


class Transparency(TmpDir):
    def test_transparent_index_with_slot0_rgb_stays_transparent(self) -> None:
        # Index 0 is transparent but has slot 0's exact RGB; index 1 is the same RGB, opaque.
        img = Image.new("P", (2, 1))
        img.putpalette(list(SLOT0) + list(SLOT0) + [0] * (768 - 6))
        img.putpixel((0, 0), 0)
        img.putpixel((1, 0), 1)
        p = self.dir / "tr.png"
        img.save(p, transparency=0)
        code, err = self.run_import([str(p), "tr"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "tr.txt").read_text(encoding="utf-8"), ".0\n")

    def test_rgba_transparent_pixel_with_slot0_rgb(self) -> None:
        img = Image.new("RGBA", (2, 1))
        img.putpixel((0, 0), SLOT0 + (0,))
        img.putpixel((1, 0), SLOT0 + (255,))
        p = self.dir / "tr2.png"
        img.save(p)
        code, err = self.run_import([str(p), "tr2"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "tr2.txt").read_text(encoding="utf-8"), ".0\n")


class Errors(TmpDir):
    def assert_fails(self, argv: list[str], needle: str, name: str) -> None:
        code, err = self.run_import(argv)
        self.assertEqual(code, 1)
        self.assertIn(needle, err)
        self.assertFalse((self.dir / f"{name}.txt").exists(), "nothing may be written on an error")

    def test_unknown_colour_names_frame_and_pixel(self) -> None:
        img = Image.new("RGBA", (8, 2), rgba("1"))
        img.putpixel((5, 1), (1, 2, 3, 255))  # frame 1 at (1, 1) with --frames 2
        p = self.dir / "bad.png"
        img.save(p)
        self.assert_fails([str(p), "bad", "--frames", "2"], "frame 1 (1,1): colour #010203 not in palette_edge.txt", "bad")

    def test_partial_alpha(self) -> None:
        for a in (1, 128, 254):
            with self.subTest(alpha=a):
                img = Image.new("RGBA", (2, 2), rgba("2"))
                img.putpixel((0, 1), PALETTE["2"][:3] + (a,))
                p = self.dir / "alpha.png"
                img.save(p)
                self.assert_fails([str(p), "alpha"], f"frame 0 (0,1): alpha {a}", "alpha")

    def test_unknown_colour_names_the_palette_used(self) -> None:
        pal = self.write("palette_other.txt", "0 #0d0b14\n")
        img = Image.new("RGBA", (1, 1), (1, 2, 3, 255))
        p = self.dir / "o.png"
        img.save(p)
        self.assert_fails([str(p), "o", "--palette", str(pal)], "not in palette_other.txt", "o")

    def test_animated_png_is_refused(self) -> None:
        a, b = Image.new("RGBA", (2, 1), rgba("1")), Image.new("RGBA", (2, 1), rgba("2"))
        p = self.dir / "anim.png"
        a.save(p, save_all=True, append_images=[b])
        self.assert_fails([str(p), "anim"], "animated PNG", "anim")

    def test_16_bit_png_is_refused(self) -> None:
        img = Image.new("I;16", (2, 1), 1000)
        p = self.dir / "deep.png"
        img.save(p)
        self.assertEqual(import_sprite.png_bit_depth(p), 16)
        self.assert_fails([str(p), "deep"], "16-bit PNG", "deep")

    def test_bad_strip_width(self) -> None:
        p = self.png_from_text("0123L\n", "w5.png")
        self.assert_fails([str(p), "w5", "--frames", "2"], "does not divide into 2 frames", "w5")
        self.assert_fails([str(p), "w5", "--cell", "2x1"], "not a multiple of the cell width 2", "w5")
        self.assert_fails([str(p), "w5", "--cell", "5x2"], "cell height 2 != image height 1", "w5")

    def test_frames_and_cell_together(self) -> None:
        p = self.png_from_text("01\n", "both.png")
        self.assert_fails([str(p), "both", "--frames", "1", "--cell", "2x1"], "not both", "both")

    def test_existing_grid_needs_force(self) -> None:
        p = self.png_from_text("01\n", "f.png")
        self.write("keep.txt", "33\n")
        code, err = self.run_import([str(p), "keep"])
        self.assertEqual(code, 1)
        self.assertIn("--force", err)
        self.assertEqual((self.dir / "keep.txt").read_text(encoding="utf-8"), "33\n")
        code, err = self.run_import([str(p), "keep", "--force"])
        self.assertEqual(code, 0, err)
        self.assertEqual((self.dir / "keep.txt").read_text(encoding="utf-8"), "01\n")

    def test_bad_names(self) -> None:
        p = self.png_from_text("01\n", "n.png")
        for name in ("a/b", "a\\b", "x.txt", "x.png", "..", ".", " ", "Player", ""):
            with self.subTest(name=name):
                code, err = self.run_import([str(p), name])
                self.assertEqual(code, 1)
                self.assertTrue("bare grid name" in err or "give <png> <name>" in err, err)
        for name in ("light", "palette_x"):
            with self.subTest(name=name):
                code, err = self.run_import([str(p), name])
                self.assertEqual(code, 1)
                self.assertIn("reserved", err)
                self.assertFalse((self.dir / f"{name}.txt").exists())

    def test_gpl_refuses_an_import_and_a_wrong_suffix(self) -> None:
        p = self.png_from_text("01\n", "g.png")
        code, err = self.run_import([str(p), "g", "--gpl", str(self.dir / "p.gpl")])
        self.assertEqual(code, 1)
        self.assertIn("palette only", err)
        self.assertFalse((self.dir / "g.txt").exists() or (self.dir / "p.gpl").exists())
        code, err = self.run_import(["--gpl", str(self.dir / "pal.txt")])
        self.assertEqual(code, 1)
        self.assertIn("must end in .gpl", err)
        self.assertFalse((self.dir / "pal.txt").exists())

    def test_real_script_exit_codes(self) -> None:
        good = self.png_from_text("01\n", "ok.png")
        bad = self.dir / "bad.png"
        Image.new("RGBA", (1, 1), (1, 2, 3, 255)).save(bad)
        script = TOOLS / "import_sprite.py"
        # The real script writes into tools/sprites/, so only its refusals run here.
        r = subprocess.run([sys.executable, str(script), str(bad), "zz_never_written"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn("not in palette_edge.txt", r.stderr)
        self.assertFalse((build_sprites.SPRITES / "zz_never_written.txt").exists())
        r = subprocess.run([sys.executable, str(script), str(good), "player"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 1)
        self.assertIn("--force", r.stderr)
        r = subprocess.run([sys.executable, str(script), "--gpl", str(self.dir / "s.gpl")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_shared_rgb_in_palette_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "share #"):
            import_sprite.reverse_palette({".": (0, 0, 0, 0), "a": (1, 2, 3, 255), "b": (1, 2, 3, 255)})


class Builder(TmpDir):
    def test_unequal_frames_are_refused(self) -> None:
        g = self.write("uneq.txt", "01\n23\n\n012\n")
        with self.assertRaisesRegex(ValueError, r"uneq.txt:4: frame 1 is 3x1, frame 0 is 2x2"):
            build_sprites.load_frames(g)

    def test_ragged_rows_are_refused(self) -> None:
        g = self.write("rag.txt", "01\n0\n")
        with self.assertRaisesRegex(ValueError, r"rag.txt:2: row width 1 != 2"):
            build_sprites.load_frames(g)

    def test_empty_lines_at_the_ends_are_ignored(self) -> None:
        g = self.write("ends.txt", "\n\n01\n\n23\n\n\n")
        self.assertEqual(build_sprites.load_frames(g), [["01"], ["23"]])

    def test_a_stray_blank_never_cuts_a_sprite_silently(self) -> None:
        g = self.write("ws.txt", "00\n  \n11\n")
        with self.assertRaisesRegex(ValueError, r"ws.txt:2: whitespace-only row"):
            build_sprites.load_frames(g)
        g = self.write("dbl.txt", "00\n\n\n11\n")
        with self.assertRaisesRegex(ValueError, r"dbl.txt:4: 2 empty lines between frames"):
            build_sprites.load_frames(g)

    def test_dot_is_not_a_palette_key(self) -> None:
        pal = self.write("palette_dot.txt", ". #000000\n")
        with self.assertRaisesRegex(ValueError, "always transparent"):
            build_sprites.load_palette(pal)

    def test_build_refuses_unequal_frames_and_writes_no_png_for_them(self) -> None:
        src, out = self.dir / "src", self.dir / "out"
        src.mkdir()
        (src / "palette_edge.txt").write_text(build_sprites.PALETTE_FILE.read_text(encoding="utf-8"), encoding="utf-8")
        (src / "uneq.txt").write_text("01\n23\n\n012\n", encoding="utf-8")
        with redirect_stdout(io.StringIO()), self.assertRaisesRegex(ValueError, "frame 1 is 3x1"):
            build_sprites.main(src, out)
        self.assertFalse((out / "uneq.png").exists())

    def test_every_committed_grid_rebuilds_its_committed_png(self) -> None:
        grids = sorted(p for p in build_sprites.SPRITES.glob("*.txt") if not p.name.startswith("palette_"))
        self.assertTrue(grids)
        for grid in grids:
            with self.subTest(grid=grid.name):
                built = build_sprites.render_strip(build_sprites.load_frames(grid), PALETTE, grid.name)
                with Image.open(build_sprites.OUT / f"{grid.stem}.png") as committed:
                    self.assertEqual(built.size, committed.size)
                    self.assertEqual(pixels(built), pixels(committed))


class Gpl(TmpDir):
    def test_gpl_lists_every_palette_colour(self) -> None:
        out = self.dir / "p.gpl"
        code, err = self.run_import(["--gpl", str(out)])
        self.assertEqual(code, 0, err)
        lines = out.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[0], "GIMP Palette")
        body = [ln for ln in lines[4:] if ln.strip()]
        self.assertEqual(len(body), len(PALETTE))  # the transparent slot + every key but '.'
        self.assertTrue(body[0].startswith("255   0 255\t"), "index 0 is the spare transparent slot")
        self.assertEqual(body[1], " 13  11  20\t0")  # slot 0, #0d0b14, never at index 0

    def test_committed_gpl_matches_the_palette(self) -> None:
        committed = build_sprites.SPRITES / "palette_edge.gpl"
        want = import_sprite.gpl_text(PALETTE, "palette_edge")
        self.assertEqual(committed.read_text(encoding="utf-8"), want,
                         "regenerate: python3 tools/import_sprite.py --gpl tools/sprites/palette_edge.gpl")


if __name__ == "__main__":
    unittest.main()
