"""Write a real multi-size Windows .ico (DIB/BMP entries)."""
from __future__ import annotations

import struct
from pathlib import Path
from PIL import Image


def _dib(img: Image.Image) -> bytes:
    """32-bit BITMAPINFOHEADER + BGRA pixels + AND mask (bottom-up)."""
    img = img.convert("RGBA")
    w, h = img.size
    # XOR bitmap (BGRA), bottom-up
    pixels = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            pixels.extend((b, g, r, a))
        # rows already 4-byte aligned for 32bpp
    # AND mask: 1 bit per pixel, padded to 32-bit rows, bottom-up
    row_bytes = ((w + 31) // 32) * 4
    mask = bytearray(row_bytes * h)
    header = struct.pack(
        "<IIIHHIIIIII",
        40,  # biSize
        w,
        h * 2,  # height includes mask
        1,  # planes
        32,  # bit count
        0,  # compression
        len(pixels),
        0,
        0,
        0,
        0,
    )
    return header + bytes(pixels) + bytes(mask)


def write_ico(path: Path, images: list[Image.Image]) -> None:
    entries = []
    data_blobs = []
    offset = 6 + 16 * len(images)
    for im in images:
        im = im.convert("RGBA")
        w, h = im.size
        blob = _dib(im)
        entries.append((w % 256, h % 256, len(blob), offset))
        data_blobs.append(blob)
        offset += len(blob)

    out = bytearray()
    out += struct.pack("<HHH", 0, 1, len(images))
    for w, h, size, off in entries:
        out += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, size, off)
    for blob in data_blobs:
        out += blob
    path.write_bytes(out)


def main() -> None:
    assets = Path(__file__).resolve().parent / "assets"
    src = Image.open(assets / "icon.png").convert("RGBA")
    bg = Image.new("RGBA", src.size, (14, 16, 19, 255))
    bg.paste(src, mask=src.split()[-1])
    src = bg

    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [src.resize((s, s), Image.Resampling.LANCZOS) for s in sizes]
    ico = assets / "icon.ico"
    write_ico(ico, images)

    raw = ico.read_bytes()
    count = struct.unpack_from("<H", raw, 4)[0]
    print("ico bytes", len(raw), "images", count)
    off = 6
    for i in range(count):
        w, h, _, _, _, _, size, o = struct.unpack_from("<BBBBHHII", raw, off)
        print(f"  #{i} {w or 256}x{h or 256} size={size} off={o}")
        off += 16


if __name__ == "__main__":
    main()
