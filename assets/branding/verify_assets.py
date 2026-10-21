#!/usr/bin/env python3
"""Verify the brand art stays inside the platform safe zones.

Two metrics:
  * alpha extent, for images that must be transparent (adaptive foreground,
    splash hero, logo);
  * art extent, for the maskable icon, measured by re-rendering the same SVG
    with the full-bleed background rect removed, so the remaining alpha is
    exactly the halo + planet art.
"""
import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

BRAND = Path("/root/workspace/emosphere/assets/branding")
TMP = Path(tempfile.mkdtemp(prefix="emosphere-verify-"))

ADAPTIVE_SAFE = 1024 * (66.0 / 108.0) / 2   # Android: centre 66dp of the 108dp canvas
MASKABLE_SAFE = 1024 * 0.80 / 2             # PWA: 80% minimum safe zone


def alpha_extent(path, thresholds=(8, 64)) -> dict[int, float]:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    a = im.getchannel("A")
    assert a is not None
    px = a.load()
    cx, cy = w / 2.0, h / 2.0
    worst: dict[int, float] = {t: 0.0 for t in thresholds}
    for y in range(h):
        for x in range(w):
            v = px[x, y]
            if v > min(thresholds):
                r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                for t in thresholds:
                    if v > t and r > worst[t]:
                        worst[t] = r
    scale = 1024.0 / w
    return {t: r * scale for t, r in worst.items()}


def strip_background(svg_name, tag):
    src = (BRAND / svg_name).read_text(encoding="utf-8")
    stripped, n = re.subn(r'<rect width="\d+" height="\d+" fill="url\(#bg\)"/>', "", src)
    if n != 1:
        raise SystemExit(f"{svg_name}: expected one background rect, found {n}")
    tmp_svg = TMP / f"{tag}_art.svg"
    tmp_png = TMP / f"{tag}_art.png"
    tmp_svg.write_text(stripped, encoding="utf-8")
    subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", str(tmp_svg), "-o", str(tmp_png)],
                   check=True)
    return tmp_png


failures = []


def check(label, radius, safe, extra=""):
    ok = radius <= safe
    print(f"  {label:34s} {radius:7.1f} / {safe:6.1f}  {'OK' if ok else 'OUTSIDE SAFE ZONE'} {extra}")
    if not ok:
        failures.append(label)


print("Android adaptive foreground (art must be inside the 66/108 zone, radius 312.9)")
for name in ("emosphere_adaptive_foreground_1024.png", "android_adaptive_foreground_432.png"):
    ext = alpha_extent(BRAND / name)
    check(name, ext[8], ADAPTIVE_SAFE, f"(alpha>64 at {ext[64]:.1f})")

print("\nTransparency (these three must have no background)")
for name in ("emosphere_adaptive_foreground_1024.png", "emosphere_logo_1024.png",
             "emosphere_splash_hero_1024.png"):
    im = Image.open(BRAND / name).convert("RGBA")
    w, h = im.size
    corners = [im.getpixel(p)[3] for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    ok = all(c == 0 for c in corners)
    print(f"  {name:34s} corner alpha {corners}  {'OK' if ok else 'NOT TRANSPARENT'}")
    if not ok:
        failures.append(name)

print("\nMaskable PWA icon (art must be inside the 80% safe zone, radius 409.6)")
art = strip_background("emosphere_maskable.svg", "maskable")
ext = alpha_extent(art)
check("maskable art (bg stripped)", ext[8], MASKABLE_SAFE, f"(alpha>64 at {ext[64]:.1f})")

print("\nSplash art")
for name, w, h in (("splash_portrait.png", 1080, 2340), ("splash_landscape.png", 2340, 1080)):
    im = Image.open(BRAND / name)
    ok = im.size == (w, h)
    print(f"  {name:34s} {im.size}  {'OK' if ok else f'EXPECTED {w}x{h}'}")
    if not ok:
        failures.append(name)


# --------------------------------------------------------------------------
# Inventory: the platform resources the generators are supposed to produce.
# --------------------------------------------------------------------------
ROOT = Path("/root/workspace/emosphere")
RES = ROOT / "android/app/src/main/res"
WEB = ROOT / "web"


def expect_file(path: Path, size=None, note=""):
    if not path.exists():
        print(f"  MISSING  {path.relative_to(ROOT)}")
        failures.append(str(path.relative_to(ROOT)))
        return
    detail = ""
    if size is not None:
        actual = Image.open(path).size
        if actual != size:
            print(f"  WRONG SIZE {path.relative_to(ROOT)} {actual} expected {size}")
            failures.append(str(path.relative_to(ROOT)))
            return
        detail = f"{actual[0]}x{actual[1]}"
    print(f"  OK       {str(path.relative_to(ROOT)):58s} {detail} {note}")


def expect_text(path: Path, needles, note=""):
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    missing = [n for n in needles if n not in text]
    label = path.relative_to(ROOT)
    if missing:
        print(f"  MISSING CONTENT {label}: {missing}")
        failures.append(f"{label}:{missing}")
    else:
        print(f"  OK       {str(label):58s} {note}")


print("\nAndroid launcher icons (mipmap-*)")
for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    expect_file(RES / f"mipmap-{density}/ic_launcher.png", (size, size))
expect_text(RES / "mipmap-anydpi-v26/ic_launcher.xml",
            ["@color/ic_launcher_background", "@drawable/ic_launcher_foreground", 'android:inset="0%"'],
            "adaptive icon")
expect_text(RES / "values/colors.xml", ["#0B1020"], "adaptive background colour")

print("\nAndroid adaptive foreground + splash drawables")
for density, size in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
    expect_file(RES / f"drawable-{density}/ic_launcher_foreground.png", (size, size))
for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    expect_file(RES / f"drawable-{density}/splash.png")
    expect_file(RES / f"drawable-{density}/android12splash.png")
    expect_file(RES / f"drawable-night-{density}/splash.png")
    expect_file(RES / f"drawable-night-{density}/android12splash.png")
expect_text(RES / "values-v31/styles.xml", ["#0B1020", "android12splash"], "Android 12 splash theme")

print("\nWeb / PWA")
for name, size in (("Icon-192.png", (192, 192)), ("Icon-512.png", (512, 512)),
                   ("Icon-maskable-192.png", (192, 192)), ("Icon-maskable-512.png", (512, 512)),
                   ("apple-touch-icon-180.png", (180, 180))):
    expect_file(WEB / "icons" / name, size)
expect_file(WEB / "favicon.png")
expect_text(WEB / "manifest.json",
            ['"name": "EmoSphere"', '"short_name": "EmoSphere"', '"display": "standalone"',
             '"theme_color": "#0B1020"', '"background_color": "#0B1020"',
             "icons/Icon-192.png", "icons/Icon-512.png", "Icon-maskable-192.png",
             "Icon-maskable-512.png", '"purpose": "maskable"'],
            "manifest")
expect_text(WEB / "index.html",
            ['name="theme-color" content="#0B1020"', "apple-mobile-web-app-capable",
             "apple-mobile-web-app-status-bar-style\" content=\"black-translucent",
             "icons/apple-touch-icon-180.png", "manifest.json"],
            "index.html meta")

print("\nRESULT:", "ALL CHECKS PASS" if not failures else f"FAILURES: {failures}")
sys.exit(1 if failures else 0)
