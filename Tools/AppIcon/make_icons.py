#!/usr/bin/env python3
"""Render both Numeriqo app icons.

The mark is a *valid clue*: a two-cell cage reading 6x, holding 2 and 3.

Why this and not an abstract shape. The one artefact unique to this genre is a
small target in the corner of an outlined region, so drawing a real one says
"arithmetic puzzle" in a way no logo mark does. The previous icon was a stepped
outline that could have belonged to a chart tool. It also gets the app's own
visual thesis into the mark, which the old one omitted entirely: **line style
encodes cage membership**. The cage boundary is a solid rule, the division
inside it is dotted, exactly as `BoardView` draws them.

Two things it deliberately copies from the board rather than from icon
convention:

- Square corners, mitred joins. The old mark used round caps and joins, which
  contradicted both `BoardView` (`lineJoin: .miter`, `cornerRadius: 0`) and
  DESIGN.md section 1's "Nothing is inset, nothing is rounded".
- Stroke weight in the board's proportion, ~3% of the cell rather than the
  old 17%, so the cage reads as ink instead of as a fat outline. That also puts
  it within a pixel of Just Kakuro's line weight at the same canvas size, so the
  two apps look like they came from the same hand.

Numerals are set in New York, the system serif, which is also the type rule the
app itself now follows: serif for numbers, SF for prose.

Pro inverts the field. Same drawing, opposite value, so the two are told apart
at a glance on one home screen without a second visual idea. No badge and no
"PRO" lettering, which would turn to mush at 40pt.

    python3 Tools/AppIcon/make_icons.py

Requires Pillow. Uses /System/Library/Fonts/NewYork.ttf.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ASSETS = pathlib.Path(__file__).resolve().parents[2] / "Numeriqo/Assets.xcassets"
SERIF = "/System/Library/Fonts/NewYork.ttf"

S = 1024                    # canvas
CAGE = 768                  # the cage is a square, 75% of the canvas
X0 = (S - CAGE) // 2        # 128
X1 = X0 + CAGE              # 896
CELL = CAGE // 2            # 384, one cell of a two-cell cage

# Board proportions. BoardView strokes the cage at 2pt on a cell of up to 72pt
# and the intra-cage rule at 1pt dashed [2, 3].
CAGE_W = 13                 # ~3.4% of the cell
RULE_W = 7
DASH, GAP = 14, 21          # the board's 2:3 dash, scaled to RULE_W

# Sizes are given as target CAP HEIGHTS, not nominal point sizes. New York
# renders a cap at 0.71 of its nominal size, so asking for "half the cell" and
# passing 0.50 * CELL as the point size lands a third too small. Getting this
# wrong is what made the first draft look like a mostly-empty box.
CAP = 0.7125
CLUE_PAD = round(CELL * 0.09)                       # 35, BoardGeometry's ratio
DIGIT_CAP = round(CELL * 0.72)                      # 276
DIGIT_WEIGHT = 560   # New York at 400 is too fine to hold at 40pt
# The board's own clue-to-digit ratio is 0.24 / 0.50, so the clue keeps its
# real proportion rather than being shrunk to look decorative.
CLUE_CAP = round(DIGIT_CAP * 0.48)                  # 103


def size_for(cap: int) -> int:
    return round(cap / CAP)

SLATE = (43, 50, 64)        # #2B3240
PAPER = (247, 246, 244)     # #F7F6F4
PAPER_DIM = (237, 235, 231)
CREAM = (242, 243, 238)     # #F2F3EE
INK = (26, 26, 30)          # #1A1A1E
INK_DEEP = (18, 19, 21)
# The Steady tier accent, in both the values Theme ships. The light one is too
# dark to carry a clue on slate, so each ground takes the variant it was drawn
# for rather than one value used twice.
GREEN = (78, 138, 111)      # #4E8A6F, Theme light
GREEN_ON_DARK = (118, 179, 150)  # #76B396, Theme dark


def serif(size: int, weight: int = 400) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(SERIF, size)
    # Axes are (Optical Size, Weight, GRAD). Pin optical size to the display
    # end so the numerals keep their contrast at this scale.
    font.set_variation_by_axes([256, weight, 0])
    return font


def draw_icon(ground, cage, rule, clue, digits) -> Image.Image:
    img = Image.new("RGB", (S, S), ground)
    d = ImageDraw.Draw(img)

    # The cage boundary: solid, square corners. Drawn as four rectangles rather
    # than one outlined rect so the corners mitre exactly.
    h = CAGE_W // 2
    d.rectangle([X0 - h, X0 - h, X1 + h, X0 + h], fill=cage)   # top
    d.rectangle([X0 - h, X1 - h, X1 + h, X1 + h], fill=cage)   # bottom
    d.rectangle([X0 - h, X0 - h, X0 + h, X1 + h], fill=cage)   # left
    d.rectangle([X1 - h, X0 - h, X1 + h, X1 + h], fill=cage)   # right

    # The division inside the cage: dotted, and finer. This is the whole idea.
    mid, r = S // 2, RULE_W // 2
    y = X0 + GAP
    while y + DASH < X1:
        d.rectangle([mid - r, y, mid + r, y + DASH], fill=rule)
        y += DASH + GAP

    # The clue, top-left inside the cage, as BoardView positions it. The target
    # and the operator are drawn separately: New York's multiplication sign is a
    # hairline next to a numeral at the same weight, so at icon scale it reads
    # as a different colour rather than as part of the clue.
    target_font = serif(size_for(CLUE_CAP), 700)
    x, y = X0 + CLUE_PAD, X0 + CLUE_PAD
    d.text((x, y), "6", font=target_font, fill=clue, anchor="la")

    # The operator is drawn, not set. New York's multiplication sign is a
    # hairline and its weight axis does not touch that glyph, so beside a bold
    # numeral it reads as a smudge in a different colour. Two strokes matched to
    # the numeral's stem is also more honest here: on the board the operator is
    # ink like everything else.
    cx = x + d.textlength("6", font=target_font) + CLUE_CAP * 0.38
    cy = y + CLUE_CAP * 0.56
    arm, w = CLUE_CAP * 0.26, max(round(CLUE_CAP * 0.11), 2)
    d.line([(cx - arm, cy - arm), (cx + arm, cy + arm)], fill=clue, width=w)
    d.line([(cx - arm, cy + arm), (cx + arm, cy - arm)], fill=clue, width=w)

    # The two digits, on one baseline. On a real board only the clue-anchor
    # cell's digit is nudged down; here both drop together, because two digits
    # at different heights read as a mistake rather than as a rule.
    #
    # Centred between the clue and the foot of the cage, then lifted a little:
    # centring on the arithmetic middle leaves them looking like they have
    # slipped down the box.
    top = X0 + CLUE_PAD + CLUE_CAP
    font = serif(size_for(DIGIT_CAP), DIGIT_WEIGHT)
    middle = (top + X1) // 2 - round(CLUE_CAP * 0.22)
    d.text((X0 + CELL // 2, middle), "2", font=font, fill=digits, anchor="mm")
    d.text((X1 - CELL // 2, middle), "3", font=font, fill=digits, anchor="mm")
    return img


# The tinted variants stay greyscale: iOS applies the user's tint itself, and
# colour here fights it.
GREY_BG, GREY_FG, GREY_DIM = (16, 16, 16), (200, 200, 200), (120, 120, 120)

ICONS = {
    "AppIcon": {
        "AppIcon.png": (SLATE, CREAM, CREAM, GREEN_ON_DARK, CREAM),
        "AppIcon-Dark.png": (INK_DEEP, CREAM, CREAM, GREEN_ON_DARK, CREAM),
        "AppIcon-Tinted.png": (GREY_BG, GREY_FG, GREY_DIM, GREY_DIM, GREY_FG),
    },
    "AppIconPro": {
        "AppIconPro.png": (PAPER, INK, INK, GREEN, INK),
        "AppIconPro-Dark.png": (PAPER_DIM, INK, INK, GREEN, INK),
        "AppIconPro-Tinted.png": (GREY_BG, GREY_FG, GREY_DIM, GREY_DIM, GREY_FG),
    },
}

CONTENTS = """{{
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

if __name__ == "__main__":
    if not pathlib.Path(SERIF).exists():
        sys.exit(f"{SERIF} not found")
    for name, variants in ICONS.items():
        out = ASSETS / f"{name}.appiconset"
        out.mkdir(parents=True, exist_ok=True)
        for filename, palette in variants.items():
            # The intra-cage rule is drawn at 45% so it reads as finer than the
            # boundary without being a second colour.
            ground, cage, rule_base, clue, digits = palette
            rule = tuple(round(g + (c - g) * 0.45)
                         for g, c in zip(ground, rule_base))
            draw_icon(ground, cage, rule, clue, digits).save(out / filename)
        files = list(variants)
        (out / "Contents.json").write_text(
            CONTENTS.format(light=files[0], dark=files[1], tinted=files[2]))
        print(f"wrote {len(variants)} images to {out.name}")
