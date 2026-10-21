#!/usr/bin/env bash
# Rasterise the EmoSphere brand SVGs with rsvg-convert.
#
# Source of truth: the *.svg files in this directory (built by build_svgs.py
# from icon_source.svg, the v4 "nebula planet" variant Vojta picked).
# Regenerate the SVGs first if the geometry changed:  python3 build_svgs.py
#
# Usage: ./render_icons.sh   (from anywhere; paths resolve from this file)
set -euo pipefail
cd "$(dirname "$0")"

R=rsvg-convert
command -v $R >/dev/null || { echo "rsvg-convert is required" >&2; exit 1; }

# --- master icon family -----------------------------------------------------
$R -w 1024 -h 1024 emosphere_icon.svg -o emosphere_icon_1024.png
$R -w  512 -h  512 emosphere_icon.svg -o emosphere_icon_512.png
$R -w  192 -h  192 emosphere_icon.svg -o emosphere_icon_192.png
$R -w  180 -h  180 emosphere_icon.svg -o apple_touch_icon_180.png

# Legibility probes: 96px (launcher) and 48px (small rows / favicon).
$R -w   96 -h   96 emosphere_icon.svg -o emosphere_icon_preview_96.png
$R -w   48 -h   48 emosphere_icon.svg -o emosphere_icon_preview_48.png

# --- Android adaptive icon pieces ------------------------------------------
$R -w 1024 -h 1024 emosphere_adaptive_foreground.svg -o emosphere_adaptive_foreground_1024.png
$R -w  432 -h  432 emosphere_adaptive_foreground.svg -o android_adaptive_foreground_432.png
$R -w 1024 -h 1024 emosphere_adaptive_background.svg -o emosphere_adaptive_background_1024.png
$R -w  432 -h  432 emosphere_adaptive_background.svg -o android_adaptive_background_432.png

# --- Maskable PWA icons -----------------------------------------------------
$R -w 512 -h 512 emosphere_maskable.svg -o emosphere_maskable_512.png
$R -w 192 -h 192 emosphere_maskable.svg -o emosphere_maskable_192.png

# --- Splash screens + hero --------------------------------------------------
$R -w 1024 -h 1024 emosphere_splash_hero.svg -o emosphere_splash_hero_1024.png
$R -w 1080 -h 2340 emosphere_splash_portrait.svg -o splash_portrait.png
$R -w 2340 -h 1080 emosphere_splash_landscape.svg -o splash_landscape.png

# --- Web assets: PWA icons, apple-touch-icon, favicon ----------------------
$R -w 512 -h 512 emosphere_icon.svg -o ../../web/icons/Icon-512.png
$R -w 192 -h 192 emosphere_icon.svg -o ../../web/icons/Icon-192.png
$R -w 512 -h 512 emosphere_maskable.svg -o ../../web/icons/Icon-maskable-512.png
$R -w 192 -h 192 emosphere_maskable.svg -o ../../web/icons/Icon-maskable-192.png
$R -w 180 -h 180 emosphere_icon.svg -o ../../web/icons/apple-touch-icon-180.png
$R -w  64 -h  64 emosphere_icon.svg -o ../../web/favicon.png

echo "OK: rendered SVG -> PNG"
