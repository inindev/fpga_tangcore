#!/usr/bin/env python3
# Write the menu's extra glyphs (character codes 0x01-0x1F) into the font in every core's
# src/iosys/gowin_dpb_menu.v. The font is the same in all seven cores; each file keeps its
# own logo. Only INIT_RAM_20-27 (font bytes for codes 0x00-0x1F) are rewritten.
#
#   scripts/font_glyphs.py                    write the glyphs into the cores
#   scripts/font_glyphs.py --check            list cores whose glyphs differ (exit 1 if any)
#   scripts/font_glyphs.py --preview out.png  draw the font and a sample file chooser screen
#
# Codes must match the BOX_* and GLYPH_* names in fpga_firmware-bl616/ui/overlay.h.
# 0x09, 0x0A and 0x0D (tab, newline, return) stay blank: the firmware prints "\n" in places.

import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORES = ["fpga_nestang", "fpga_snestang", "fpga_smstang", "fpga_gbatang",
         "fpga_monitorcore", "fpga_mdtang", "fpga_pctang"]

# 8x8, top row first, leftmost pixel first ('#' on). Single lines on row/column 3, double
# lines on rows/columns 2 and 4, the same middle as the letters (columns and rows 0-6).
GLYPHS = {
    0x01: "........ ........ ........ ######## ........ ........ ........ ........",  # ─
    0x02: "...#.... ...#.... ...#.... ...#.... ...#.... ...#.... ...#.... ...#....",  # │
    0x03: "........ ........ ........ ...##### ...#.... ...#.... ...#.... ...#....",  # ┌
    0x04: "........ ........ ........ ####.... ...#.... ...#.... ...#.... ...#....",  # ┐
    0x05: "...#.... ...#.... ...#.... ...##### ........ ........ ........ ........",  # └
    0x06: "...#.... ...#.... ...#.... ####.... ........ ........ ........ ........",  # ┘
    0x07: "...#.... ...#.... ...#.... ...##### ...#.... ...#.... ...#.... ...#....",  # ├
    0x08: "...#.... ...#.... ...#.... ####.... ...#.... ...#.... ...#.... ...#....",  # ┤
    0x0B: "........ ........ ######## ........ ######## ........ ........ ........",  # ═
    0x0C: "..#.#... ..#.#... ..#.#... ..#.#... ..#.#... ..#.#... ..#.#... ..#.#...",  # ║
    0x0E: "........ ........ ..###### ..#..... ..#.#### ..#.#... ..#.#... ..#.#...",  # ╔
    0x0F: "........ ........ #####... ....#... ###.#... ..#.#... ..#.#... ..#.#...",  # ╗
    0x10: "..#.#... ..#.#... ..#.#### ..#..... ..###### ........ ........ ........",  # ╚
    0x11: "..#.#... ..#.#... ###.#... ....#... #####... ........ ........ ........",  # ╝
    0x12: "..#.#... ..#.#... ..#.#### ..#..... ..#.#### ..#.#... ..#.#... ..#.#...",  # ╠
    0x13: "..#.#... ..#.#... ###.#... ....#... ###.#... ..#.#... ..#.#... ..#.#...",  # ╣
    0x14: "........ ...#.... ..###... .#####.. #######. ........ ........ ........",  # ▲
    0x15: "........ ........ #######. .#####.. ..###... ...#.... ........ ........",  # ▼
    0x16: "....#... ...##... ..###... .####... ..###... ...##... ....#... ........",  # ◄
    0x17: ".#...... .##..... .###.... .####... .###.... .##..... .#...... ........",  # ►
    0x18: "........ ###..... #######. #######. #######. #######. #######. ........",  # folder
    0x19: ".####... .#..##.. .#...#.. .#...#.. .#...#.. .#...#.. .#####.. ........",  # file
    0x1A: ".#####.. ###.###. ##.#.##. #.###.#. #.....#. #.###.#. .#####.. ........",  # A button
    0x1B: ".#####.. #....##. #.###.#. #....##. #.###.#. #....##. .#####.. ........",  # B button
    0x1C: "........ ........ ........ ........ ........ ........ .#.#.#.. ........",  # …
}

FONT_BASE = 0x400               # font bytes in the BRAM, 8 per character
INIT_RE = re.compile(r"(defparam dpb_inst_0\.INIT_RAM_([0-9A-F]{2}) = 256'h)([0-9A-Fa-f]{64});")


def glyph_bytes():
    """Font bytes for codes 0x00-0x1F, bit 0 = leftmost pixel."""
    out = bytearray(32 * 8)
    for code, art in GLYPHS.items():
        rows = art.split()
        assert len(rows) == 8 and all(len(r) == 8 for r in rows), hex(code)
        for y, row in enumerate(rows):
            out[code * 8 + y] = sum(1 << x for x, c in enumerate(row) if c == "#")
    return out


def read_bram(text):
    """The 2 KB BRAM contents from a gowin_dpb_menu.v."""
    mem = bytearray(2048)
    for m in INIT_RE.finditer(text):
        start = int(m.group(2), 16) * 32
        mem[start:start + 32] = bytes.fromhex(m.group(3))[::-1]    # hex is byte 31 first
    return mem


def write_glyphs(text, glyphs):
    def sub(m):
        start = int(m.group(2), 16) * 32 - FONT_BASE
        if not 0 <= start < len(glyphs):
            return m.group(0)
        return m.group(1) + glyphs[start:start + 32][::-1].hex().upper() + ";"
    return INIT_RE.sub(sub, text)


def png(path, w, h, rgb):
    raw = b"".join(b"\0" + bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def sample_screen():
    """32x28 file chooser screen as the firmware draws it (no logo): frame rows 5-24 with
    the path and page in the top edge, icons, scroll marker, hints on row 25."""
    s = [[" "] * 32 for _ in range(28)]
    def put(x, y, text):
        for i, ch in enumerate(text):
            s[y][x + i] = ch
    top = "\x0e" + "\x0b" * 30 + "\x0f"
    put(0, 5, top)
    put(2, 5, " nes/Super Mario ")
    put(25, 5, " 1/3 ")
    for y in range(6, 24):
        put(0, y, "\x0c")
        put(31, y, "\x0c")
    put(0, 24, "\x10" + "\x0b" * 30 + "\x11")
    rows = [("\x18", ".."), ("\x18", "Hacks"), ("\x19", "Super Mario Bros (W).nes"),
            ("\x19", "Super Mario Bros 3 (USA) (Rev 1).nes")]
    for i, (icon, name) in enumerate(rows):
        if len(name) > 26:
            name = name[:25] + "\x1c"
        put(2, 6 + i, icon + " " + name)
    put(1, 8, ">")
    put(30, 23, "\x15")
    put(7, 25, "\x1a\x1b Select  \x16\x17 Page")
    return s


def preview(path, font):
    """Left: all 128 characters (16x8). Right: a sample file chooser screen."""
    text, frame, back = (255, 255, 255), (90, 90, 90), (0, 0, 0)
    cols, rows, scale = 52, 28, 3
    grid = [[" "] * cols for _ in range(rows)]
    for c in range(128):
        grid[2 + c // 16][1 + c % 16] = chr(c)
    for y, line in enumerate(sample_screen()):
        for x, ch in enumerate(line):
            grid[y][19 + x] = ch
    W, H = cols * 8 * scale, rows * 8 * scale
    rgb = bytearray(W * H * 3)
    for py in range(H):
        for px in range(W):
            x, y = px // scale, py // scale
            bits = font[ord(grid[y // 8][x // 8]) * 8 + y % 8]
            on = bits >> (x % 8) & 1
            i = (py * W + px) * 3
            rgb[i:i + 3] = bytes(text if on else frame if x // 8 in (18, 51) else back)
    png(path, W, H, rgb)


def main():
    args = sys.argv[1:]
    glyphs = glyph_bytes()
    if args[:1] == ["--preview"] and len(args) == 2:
        path = os.path.join(ROOT, CORES[0], "src/iosys/gowin_dpb_menu.v")
        with open(path) as f:
            font = read_bram(write_glyphs(f.read(), glyphs))[FONT_BASE:]
        preview(args[1], font)
        return 0
    if args not in ([], ["--check"]):
        print("usage: %s [--check | --preview out.png]" % sys.argv[0], file=sys.stderr)
        return 2
    rc = 0
    for core in CORES:
        path = os.path.join(ROOT, core, "src/iosys/gowin_dpb_menu.v")
        with open(path) as f:
            text = f.read()
        new = write_glyphs(text, glyphs)
        if new == text:
            continue
        if args:
            print("differs: %s" % os.path.relpath(path, ROOT))
            rc = 1
        else:
            with open(path, "w") as f:
                f.write(new)
            print("updated: %s" % os.path.relpath(path, ROOT))
    return rc


if __name__ == "__main__":
    sys.exit(main())
