#!/usr/bin/env python3
"""Render both Numeriqo app icons.

The mark is a stepped cage: two rounded rectangles offset diagonally, stroked as
one union outline. The geometry was measured off the original hand-made
`AppIcon.png`, and both SKUs are now emitted from it, so they are the same
drawing rather than two similar ones.

Pro inverts the field. Standard is a paper ground with an accent-to-ink stroke;
Pro is an ink ground with an accent-to-paper stroke. Same mark, opposite value,
told apart at a glance on one home screen without a second visual idea (no
badge, no "PRO" lettering, which would turn to mush at 40pt).

The original artwork sat 106px above the canvas centre, which is a tenth of the
icon and plainly visible once you look for it. `CENTRE_Y` corrects it for both.

    python3 Tools/AppIcon/make_pro_icon.py

Requires rsvg-convert (brew install librsvg).
"""
import pathlib
import subprocess
import sys

ASSETS = pathlib.Path(__file__).resolve().parents[2] / "Numeriqo/Assets.xcassets"

# Stroke centreline, so the outer edge sits at +/- STROKE/2 from these.
STROKE = 38
CENTRE_Y = 106          # lifts the mark to the middle of the canvas
PATH = "M 191 191 H 621 V 402 H 833 V 620 H 402 V 409 H 191 Z"

INK = "#1A1A1E"
INK_DEEP = "#121315"
PAPER = "#F7F6F4"
PAPER_DIM = "#EDEBE7"
ACCENT = "#4E8A6F"


def svg(field: str, stop_a: str, stop_b: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="g" x1="0.30" y1="0" x2="0.85" y2="1">
      <stop offset="0" stop-color="{stop_a}"/>
      <stop offset="1" stop-color="{stop_b}"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="{field}"/>
  <g transform="translate(0 {CENTRE_Y})">
    <path d="{PATH}" fill="none" stroke="url(#g)" stroke-width="{STROKE}"
          stroke-linejoin="round" stroke-linecap="round"/>
  </g>
</svg>"""


# The tinted variants stay greyscale: iOS applies the user's tint itself, and
# colour here fights it.
ICONS = {
    "AppIcon": {
        "AppIcon.png": svg(PAPER, ACCENT, INK),
        "AppIcon-Dark.png": svg(INK_DEEP, ACCENT, PAPER),
        "AppIcon-Tinted.png": svg("#101010", "#C8C8C8", "#787878"),
    },
    "AppIconPro": {
        "AppIconPro.png": svg(INK, ACCENT, PAPER),
        "AppIconPro-Dark.png": svg(INK_DEEP, ACCENT, PAPER_DIM),
        "AppIconPro-Tinted.png": svg("#101010", "#C8C8C8", "#787878"),
    },
}


def contents(names: list[str]) -> str:
    light, dark, tinted = names
    return f"""{{
  "images" : [
    {{ "filename" : "{light}", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }},
    {{ "appearances" : [ {{ "appearance" : "luminosity", "value" : "dark" }} ],
      "filename" : "{dark}", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }},
    {{ "appearances" : [ {{ "appearance" : "luminosity", "value" : "tinted" }} ],
      "filename" : "{tinted}", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }}
  ],
  "info" : {{ "author" : "xcode", "version" : 1 }}
}}
"""


for name, variants in ICONS.items():
    out = ASSETS / f"{name}.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    for filename, markup in variants.items():
        tmp = out / (filename + ".svg")
        tmp.write_text(markup)
        try:
            subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024",
                            "-o", str(out / filename), str(tmp)], check=True)
        except FileNotFoundError:
            sys.exit("rsvg-convert not found. brew install librsvg")
        tmp.unlink()
    (out / "Contents.json").write_text(contents(list(variants)))
    print(f"wrote {len(variants)} images to {out.name}")
