#!/usr/bin/env python3
"""Build the EmoSphere brand SVG family.

Source geometry: the variant Vojta picked, "nebulova planeta" (v4):
  /root/workspace/noc/emosphere-icons/icon_v4_nebula.svg
A verbatim copy is kept next to this script as icon_source.svg.

This script applies the four refinement rules from
/root/workspace/noc/emosphere-icon-choice.txt:

  1. simplified for small sizes - one orbit ring instead of three grid
     ellipses, heavier planet rim (9px at 1024), bigger dots
  2. clear dot hierarchy (joy biggest ... tired smallest) and one light
     direction only: upper-left (every gradient centre sits at 30-35% x/y)
  3. nebula fill limited to SIX emotion colours with soft transitions
     (joy, love, sad, calm, anger, fear); the remaining two emotions live
     in the dots only
  4. full output family: master icon, Android adaptive foreground and
     background, maskable PWA icon, splash hero, splash portrait/landscape

Run:  python3 build_svgs.py    # writes the *.svg files next to this script
Then: ./render_icons.sh        # rasterises them to PNG with rsvg-convert
"""

from pathlib import Path

HERE = Path(__file__).resolve().parent

# ---------------------------------------------------------------- palette ---
BG_LIGHT = "#0E1430"   # spec: gradient #0B1020 -> #0E1430
BG_DARK = "#0B1020"
BG_DEEP = "#070A18"
ACCENT = "#6366F1"

JOY = "#FFD93D"
CALM = "#4ADE80"
LOVE = "#F472B6"
SURPRISE = "#FB923C"
SAD = "#60A5FA"
ANGER = "#EF4444"
FEAR = "#A78BFA"
TIRED = "#94A3B8"

# ------------------------------------------------------------------ shapes ---
# Planet disc on the 1024 grid. Content is designed to survive the Android
# adaptive safe zone (66dp of 108dp) and the 80% maskable safe circle.
R = 310
CX = CY = 512

# Dots: (colour, cx, cy, r). Size order IS the hierarchy: joy is the largest
# emotion, tired the smallest. All dots stay inside the planet with margin.
DOTS = [
    (JOY, 500, 296, 46),
    (CALM, 698, 424, 34),
    (SAD, 330, 636, 32),
    (LOVE, 656, 640, 31),
    (SURPRISE, 508, 742, 30),
    (ANGER, 300, 424, 30),
    (FEAR, 392, 336, 25),
    (TIRED, 596, 520, 20),
]

# Nebula wash: exactly six emotion colours, soft and low opacity.
NEBULA = [
    (JOY, 470, 360, 230, 0.30),
    (LOVE, 640, 520, 220, 0.26),
    (SAD, 420, 680, 235, 0.26),
    (CALM, 330, 430, 190, 0.22),
    (ANGER, 610, 720, 200, 0.20),
    (FEAR, 660, 330, 160, 0.20),
]

WORDMARK = "EmoSphere"


def defs(bg=True):
    """Gradients shared by every file. Light always comes from upper-left."""
    out = ['<defs>']
    if bg:
        # Background: light corner top-left, deep corner bottom-right.
        out.append(
            f'<radialGradient id="bg" cx="26%" cy="20%" r="108%">'
            f'<stop offset="0%" stop-color="{BG_LIGHT}"/>'
            f'<stop offset="46%" stop-color="{BG_DARK}"/>'
            f'<stop offset="100%" stop-color="{BG_DEEP}"/></radialGradient>'
        )
    out.append(
        f'<radialGradient id="halo" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0%" stop-color="{ACCENT}" stop-opacity="0.36"/>'
        f'<stop offset="100%" stop-color="{ACCENT}" stop-opacity="0"/></radialGradient>'
    )
    # Sphere: the single light source, upper-left.
    out.append(
        '<radialGradient id="sph" cx="33%" cy="27%" r="86%">'
        '<stop offset="0%" stop-color="#3E63B4"/>'
        '<stop offset="45%" stop-color="#1B2E63"/>'
        '<stop offset="100%" stop-color="#0B1330"/></radialGradient>'
    )
    # Rim: bright on the lit side, cool and dim on the far side.
    out.append(
        '<linearGradient id="rim" x1="250" y1="240" x2="790" y2="800" '
        'gradientUnits="userSpaceOnUse">'
        '<stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.62"/>'
        '<stop offset="52%" stop-color="#FFFFFF" stop-opacity="0.24"/>'
        '<stop offset="100%" stop-color="#A9B6F0" stop-opacity="0.18"/>'
        '</linearGradient>'
    )
    # Inner shade on the away-from-light side gives the disc volume.
    out.append(
        '<linearGradient id="rimshade" x1="250" y1="240" x2="790" y2="800" '
        'gradientUnits="userSpaceOnUse">'
        '<stop offset="0%" stop-color="#05070F" stop-opacity="0"/>'
        '<stop offset="60%" stop-color="#05070F" stop-opacity="0.10"/>'
        '<stop offset="100%" stop-color="#05070F" stop-opacity="0.42"/>'
        '</linearGradient>'
    )
    # Every dot keeps its highlight in the same corner.
    out.append(
        '<radialGradient id="dotlight" cx="31%" cy="27%" r="78%">'
        '<stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.40"/>'
        '<stop offset="55%" stop-color="#FFFFFF" stop-opacity="0.06"/>'
        '<stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
    )
    out.append(
        '<radialGradient id="spechilite">'
        '<stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.11"/>'
        '<stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
    )
    out.append(
        '<linearGradient id="wm" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0%" stop-color="#FFFFFF"/>'
        '<stop offset="100%" stop-color="#AEB9FF"/></linearGradient>'
    )
    for i, (color, *_rest) in enumerate(NEBULA):
        out.append(
            f'<radialGradient id="neb{i}">'
            f'<stop offset="0%" stop-color="{color}" stop-opacity="0.9"/>'
            f'<stop offset="100%" stop-color="{color}" stop-opacity="0"/></radialGradient>'
        )
    for i, (color, *_rest) in enumerate(DOTS):
        out.append(
            f'<radialGradient id="glow{i}" cx="35%" cy="30%" r="70%">'
            f'<stop offset="0%" stop-color="{color}" stop-opacity="0.55"/>'
            f'<stop offset="100%" stop-color="{color}" stop-opacity="0"/></radialGradient>'
        )
    out.append(f'<clipPath id="clip"><circle cx="{CX}" cy="{CY}" r="{R}"/></clipPath>')
    out.append('</defs>')
    return "".join(out)


def planet(scale=1.0, dx=0.0, dy=0.0, rim=True):
    """The planet: disc, six-colour nebula wash, one orbit ring, eight dots."""
    g = []
    t = f'translate({dx},{dy}) scale({scale:g}) translate({-CX},{-CY})' if scale != 1.0 else None
    if t:
        g.append(f'<g transform="{t}">')
        dx = dy = 0.0
    g.append(f'<g clip-path="url(#clip)">')
    g.append(f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="url(#sph)"/>')
    for i, (color, nx, ny, nr, op) in enumerate(NEBULA):
        g.append(
            f'<circle cx="{nx}" cy="{ny}" r="{nr}" fill="url(#neb{i})" opacity="{op / 0.9:.3f}"/>'
        )
    # Exactly one orbit ring, tilted so it reads as a sphere, not a grid.
    g.append(
        f'<ellipse cx="{CX}" cy="{CY}" rx="{R}" ry="104" fill="none" '
        'stroke="#FFFFFF" stroke-opacity="0.13" stroke-width="5" '
        f'transform="rotate(-16 {CX} {CY})"/>'
    )
    # Lit sheen, upper-left.
    g.append(
        f'<ellipse cx="412" cy="348" rx="186" ry="110" fill="url(#spechilite)" '
        'transform="rotate(-28 412 348)"/>'
    )
    for i, (color, px, py, pr) in enumerate(DOTS):
        g.append(f'<circle cx="{px}" cy="{py}" r="{pr * 1.7:.1f}" fill="url(#glow{i})"/>')
        g.append(f'<circle cx="{px}" cy="{py}" r="{pr}" fill="{color}"/>')
        g.append(f'<circle cx="{px}" cy="{py}" r="{pr}" fill="url(#dotlight)"/>')
    g.append('</g>')
    if rim:
        # Heavier rim than the source SVG (3 -> 9) so 48px renders still read.
        g.append(
            f'<circle cx="{CX}" cy="{CY}" r="{R - 6}" fill="none" stroke="url(#rimshade)" '
            'stroke-width="16"/>'
        )
        g.append(
            f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="none" stroke="url(#rim)" '
            'stroke-width="9"/>'
        )
        g.append(
            f'<circle cx="{CX}" cy="{CY}" r="{R + 9}" fill="none" stroke="{ACCENT}" '
            'stroke-opacity="0.20" stroke-width="8"/>'
        )
    if t:
        g.append('</g>')
    return "".join(g)


def svg(w, h, body, transparent_note=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}">'
        f'<!-- EmoSphere brand asset, generated by build_svgs.py from icon_source.svg '
        f'(v4 "nebula planet"); do not hand-edit -->{transparent_note}'
        f'{body}</svg>'
    )


def write(name, content):
    path = HERE / name
    path.write_text(content, encoding="utf-8")
    print(f"{name:42s} {path.stat().st_size:6d} B")


def main():
    # 1. Master icon: what flutter_launcher_icons uses for legacy launchers.
    write("emosphere_icon.svg", svg(1024, 1024, defs() + (
        f'<rect width="1024" height="1024" fill="url(#bg)"/>'
        f'<circle cx="{CX}" cy="{CY}" r="430" fill="url(#halo)"/>'
        + planet()
    )))

    # 2. Android adaptive foreground: transparent, art inside the 66/108 safe zone.
    safe = 300 / R  # planet radius 300 -> 58.6% of the canvas, inside 61.1%
    write("emosphere_adaptive_foreground.svg", svg(1024, 1024, defs(bg=False) + (
        f'<circle cx="{CX}" cy="{CY}" r="330" fill="url(#halo)"/>'
        + planet(scale=safe)
    )))

    # 3. Android adaptive background: flat brand background, full bleed.
    write("emosphere_adaptive_background.svg", svg(1024, 1024,
        defs(bg=False) + f'<rect width="1024" height="1024" fill="{BG_DARK}"/>'))

    # 4. Maskable PWA icon: art inside the 80% safe circle, background full bleed.
    mask = 190 / R
    write("emosphere_maskable.svg", svg(1024, 1024, defs() + (
        f'<rect width="1024" height="1024" fill="url(#bg)"/>'
        f'<circle cx="{CX}" cy="{CY}" r="360" fill="url(#halo)"/>'
        + planet(scale=mask)
    )))

    # 5. Splash hero: transparent logo for flutter_native_splash.
    write("emosphere_splash_hero.svg", svg(1024, 1024, defs(bg=False) + (
        f'<circle cx="{CX}" cy="430" r="300" fill="url(#halo)"/>'
        + planet(scale=0.78, dx=CX, dy=430)
        + f'<text x="{CX}" y="874" text-anchor="middle" font-family="DejaVu Sans" '
          f'font-weight="bold" font-size="116" letter-spacing="2" fill="url(#wm)">{WORDMARK}</text>'
    )))

    # 5b. Logo only, no wordmark: the Android 12 system splash crops the icon
    #     to a circle of 2/3 of the image, so keep the art well inside that.
    write("emosphere_logo.svg", svg(1024, 1024, defs(bg=False) + planet(scale=0.9)))

    # 6. Splash portrait (phone) and landscape (tablet/desktop) backdrops.
    write("emosphere_splash_portrait.svg", svg(1080, 2340, defs() + (
        '<rect width="1080" height="2340" fill="url(#bg)"/>'
        '<circle cx="540" cy="1060" r="580" fill="url(#halo)"/>'
        + planet(scale=0.62, dx=540, dy=1060)
        + '<text x="540" y="1470" text-anchor="middle" font-family="DejaVu Sans" '
          'font-weight="bold" font-size="108" letter-spacing="2" fill="url(#wm)">'
        + WORDMARK + '</text>'
    )))
    write("emosphere_splash_landscape.svg", svg(2340, 1080, defs() + (
        '<rect width="2340" height="1080" fill="url(#bg)"/>'
        '<circle cx="1170" cy="470" r="620" fill="url(#halo)"/>'
        + planet(scale=0.46, dx=1170, dy=470)
        + '<text x="1170" y="810" text-anchor="middle" font-family="DejaVu Sans" '
          'font-weight="bold" font-size="96" letter-spacing="2" fill="url(#wm)">'
        + WORDMARK + '</text>'
    )))


if __name__ == "__main__":
    main()
