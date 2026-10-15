#!/usr/bin/env python3
"""A5-assets: TrayIconGuard v8 programmatic icon generator (PIL, no other deps).

Design: Fluent-style rounded square, diagonal azure->blue gradient with a soft
top-left highlight, a bold white shield (the "guard") with three knocked-out
dots (the promoted tray icons) at sizes >= 40 px; solid shield at tiny sizes
for legibility in the taskbar tray (16-32 px).

Outputs:
  resources/icon.ico        (16,20,24,32,40,48,64,96,128 as 32bpp BMP DIB entries,
                             256 as PNG entry - maximum shell compatibility)
  resources/icon_256.png    (marketing / README)
  resources/icon_512.png    (store-grade master)
  resources/logo_mono.png   (white shield on transparent, 512, for docs/UI art)
"""
import io
import math
import os
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "resources"))
os.makedirs(OUT, exist_ok=True)

ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]

C_TL = (0x5A, 0xC8, 0xFF)  # bright azure
C_TR = (0x2E, 0x99, 0xE4)
C_BL = (0x1E, 0x7F, 0xD6)
C_BR = (0x0A, 0x44, 0x86)  # deep blue


def bilinear_gradient(S: int) -> Image.Image:
    base = Image.new("RGB", (2, 2))
    base.putdata([C_TL, C_TR, C_BL, C_BR])  # row-major: TL, TR, BL, BR
    return base.resize((S, S), Image.BICUBIC).convert("RGBA")


def add_highlight(img: Image.Image, S: int) -> None:
    hl = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(hl)
    cx, cy, r = S * 0.32, S * 0.24, S * 0.82
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=72)
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.20))
    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(hl.point(lambda v: int(v * 0.32)))
    img.alpha_composite(white)


def rounded_mask(S: int, ratio: float = 0.205) -> Image.Image:
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=S * ratio, fill=255)
    return m


def shield_path(S: int, small: bool) -> list:
    """Shield outline in absolute px for a canvas of size S (y down).

    Traversal: left-top corner arc -> top edge -> right-top corner arc ->
    right edge -> right bezier to bottom tip -> mirrored bezier up the left
    side -> left edge (polygon auto-closes to the start point).
    """
    if small:  # chunkier for 16..32 px targets
        x0, x1, yt, ym, yb = 0.235 * S, 0.765 * S, 0.145 * S, 0.50 * S, 0.855 * S
    else:
        x0, x1, yt, ym, yb = 0.265 * S, 0.735 * S, 0.165 * S, 0.50 * S, 0.838 * S
    cx = S / 2.0
    r = 0.045 * S  # top corner rounding
    pts = []

    # top-left corner arc: center (x0+r, yt+r), 180deg -> 270deg
    for i in range(0, 5):
        th = math.pi + (math.pi / 2) * (i / 4.0)
        pts.append((x0 + r + r * math.cos(th), yt + r + r * math.sin(th)))
    # top edge
    pts.append((x1 - r, yt))
    # top-right corner arc: center (x1-r, yt+r), 270deg -> 360deg
    for i in range(1, 5):
        th = 1.5 * math.pi + (math.pi / 2) * (i / 4.0)
        pts.append((x1 - r + r * math.cos(th), yt + r + r * math.sin(th)))
    # right edge down to the shoulder
    pts.append((x1, ym))
    # right curve (quadratic bezier): shoulder -> bottom tip
    p0 = (x1, ym)
    p1 = (x1 - 0.012 * S, ym + (yb - ym) * 0.70)
    p2 = (cx, yb)
    curve = []
    N = 14
    for i in range(1, N + 1):
        t = i / N
        mt = 1 - t
        curve.append((mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0],
                      mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]))
    pts.extend(curve)  # last point == bottom tip (cx, yb)
    # mirror the curve back up the left side (skip duplicated tip)
    for (x, y) in reversed(curve[:-1]):
        pts.append((2 * cx - x, y))
    # left edge up (closes to (x0, yt+r))
    pts.append((x0, ym))
    return pts


def render(S: int, supersample: int = 4, mono: bool = False) -> Image.Image:
    SS = max(64, S * supersample)
    shield = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(shield)
    small = S <= 32
    d.polygon(shield_path(SS, small), fill=(255, 255, 255, 255))
    if not small and not mono:
        # knock out three "promoted tray icon" dots
        holes = Image.new("L", (SS, SS), 255)
        dh = ImageDraw.Draw(holes)
        r = 0.047 * SS
        cyy = 0.395 * SS
        for cxu in (0.393, 0.5, 0.607):
            dh.ellipse([cxu * SS - r, cyy - r, cxu * SS + r, cyy + r], fill=0)
        holes = holes.filter(ImageFilter.GaussianBlur(max(0.6, SS * 0.0035)))
        shield.putalpha(ImageChops.multiply(shield.getchannel("A"), holes))
    if mono:
        return shield.resize((S, S), Image.LANCZOS)

    img = bilinear_gradient(SS)
    add_highlight(img, SS)
    # subtle drop shadow under the shield for depth
    sh = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    path = shield_path(SS, small)
    ds.polygon([(x, y + SS * 0.012) for (x, y) in path], fill=(3, 22, 45, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(SS * 0.014))
    img.alpha_composite(sh)
    img.alpha_composite(shield)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), rounded_mask(SS)))
    return img.resize((S, S), Image.LANCZOS)


def dib_data(img: Image.Image) -> bytes:
    """32bpp BGRA bottom-up DIB (BITMAPINFOHEADER + XOR + 1bpp AND mask)."""
    s = img.size[0]
    px = img.convert("RGBA").load()
    xor = bytearray()
    for y in range(s - 1, -1, -1):
        for x in range(s):
            r, g, b, a = px[x, y]
            xor += bytes((b, g, r, a))
    row = ((s + 31) // 32) * 4
    and_mask = bytes(row * s)
    bih = struct.pack("<IiiHHIIiiII", 40, s, s * 2, 1, 32, 0,
                      len(xor) + len(and_mask), 0, 0, 0, 0)
    return bih + bytes(xor) + and_mask


def build_ico(path: str, sizes: list) -> None:
    entries = []
    for s in sizes:
        img = render(s)
        if s >= 256:
            buf = io.BytesIO()
            img.save(buf, "PNG", optimize=True)
            data = buf.getvalue()
        else:
            data = dib_data(img)
        entries.append((s, data))
    n = len(entries)
    out = struct.pack("<HHH", 0, 1, n)
    offset = 6 + 16 * n
    dirs, blobs = b"", b""
    for s, data in entries:
        wh = 0 if s >= 256 else s
        dirs += struct.pack("<BBBBHHII", wh, wh, 0, 0, 1, 32, len(data), offset)
        blobs += data
        offset += len(data)
    with open(path, "wb") as f:
        f.write(out + dirs + blobs)


def main() -> None:
    build_ico(os.path.join(OUT, "icon.ico"), ICO_SIZES)
    render(256, supersample=3).save(os.path.join(OUT, "icon_256.png"))
    render(512, supersample=2).save(os.path.join(OUT, "icon_512.png"))
    render(512, supersample=2, mono=True).save(os.path.join(OUT, "logo_mono.png"))
    # quick visual sheet for QA review
    sheet = Image.new("RGBA", (sum(ICO_SIZES) + 12 * len(ICO_SIZES), 148), (32, 32, 32, 255))
    x = 8
    for s in ICO_SIZES:
        im = render(s)
        sheet.alpha_composite(im, (x, 140 - s - 4))
        x += s + 12
    sheet.save(os.path.join(OUT, "icon_sheet.png"))
    print("icon assets written to", OUT)


if __name__ == "__main__":
    main()
