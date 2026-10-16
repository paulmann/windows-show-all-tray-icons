#!/usr/bin/env python3
"""Render the 1280x640 GitHub social-preview card for TrayIconGuard.

Usage:  python scripts/make_social_card.py [--out shots/social-preview.png]

Requires Pillow and Segoe UI (Windows). The generated file is committed as
shots/social-preview.png and has to be uploaded manually in
Settings -> Social preview, because GitHub exposes no API for it.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: python -m pip install pillow")

ROOT = pathlib.Path(__file__).resolve().parents[1]
W, H = 1280, 640
BG = (13, 17, 23)
CARD = (22, 27, 34)
ACCENT = (255, 143, 0)
TEXT = (240, 246, 252)
MUTED = (166, 173, 186)
FONT_DIR = pathlib.Path(r"C:\Windows\Fonts")

BULLETS = [
    "Native C++17  \u00b7  single ~1 MB exe  \u00b7  zero dependencies",
    "Event-driven guard re-promotes icons the moment Explorer hides them",
    "Fluent GUI  \u00b7  headless --watch  \u00b7  full CLI  \u00b7  30 languages",
    "HKCU only, no admin, no telemetry, SHA-256-pinned self-updates",
]
CHIPS = ["Windows 10 / 11", "Light & Dark", "8.6.2"]


def font(name: str, size: int):
    for candidate in (name, "segoeui.ttf"):
        path = FONT_DIR / candidate
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def version() -> str:
    header = ROOT / "src" / "core" / "version.h"
    try:
        text = header.read_text(encoding="utf-8")
        import re

        match = re.search(r'kVersion\s*=\s*L"([^"]+)"', text)
        if match:
            return match.group(1)
    except OSError:
        pass
    return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="shots/social-preview.png")
    args = parser.parse_args()
    out = (ROOT / args.out) if not pathlib.Path(args.out).is_absolute() else pathlib.Path(args.out)

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    for y in range(H):  # soft gradient
        k = y / H
        draw.line([(0, y), (W, y)], fill=(int(13 + 10 * k), int(17 + 12 * k), int(23 + 16 * k)))

    draw.rectangle([0, 0, 12, H], fill=ACCENT)

    icon_path = ROOT / "resources" / "icon.ico"
    if icon_path.exists():
        try:
            icon = Image.open(icon_path)
            icon.size = (256, 256)
            icon = icon.convert("RGBA")
            img.paste(icon, (86, 92), icon)
        except Exception as exc:  # cosmetic only
            print(f"icon skipped: {exc}", file=sys.stderr)

    draw.text((400, 96), "TrayIconGuard", font=font("segoeuib.ttf", 82), fill=TEXT)
    draw.text((402, 196), "Keep every Windows tray icon visible", font=font("segoeui.ttf", 34), fill=ACCENT)

    y = 286
    for line in BULLETS:
        draw.ellipse([404, y + 12, 416, y + 24], fill=ACCENT)
        draw.text((438, y), line, font=font("segoeui.ttf", 26), fill=MUTED)
        y += 52

    chips = CHIPS[:]
    v = version()
    if v and v not in chips:
        chips[-1] = v
    x = 404
    for chip in chips:
        width = draw.textlength(chip, font=font("segoeuib.ttf", 27))
        draw.rounded_rectangle([x, 512, x + width + 44, 566], radius=27, fill=CARD, outline=(48, 54, 61))
        draw.text((x + 22, 524), chip, font=font("segoeuib.ttf", 27), fill=TEXT)
        x += width + 64

    draw.text((86, 566), "github.com/paulmann/windows-show-all-tray-icons",
              font=font("segoeui.ttf", 26), fill=MUTED)

    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, "PNG", optimize=True)
    print(f"written {out} ({out.stat().st_size} bytes, {W}x{H})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
