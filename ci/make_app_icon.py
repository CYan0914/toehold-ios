"""Draw the Toehold app icon, and write the asset catalog around it.

    python ci/make_app_icon.py

The icon is generated rather than hand-drawn in a design tool for the same
reason the catalog is committed rather than assembled in CI: the validator
only looks at pixels, and the failure is late. An icon that is missing the
120x120 for iPhone or the 152x152 for iPad is rejected at *export* time,
after the archive and the signing and the upload have all succeeded. Nothing
before that point notices, and a simulator build with no icon at all compiles
and runs perfectly.

## The mark

One step, cut as a filled white profile on a calm teal gradient.

  * Exactly one. Not a staircase, not a flight, not an arrow going up. The
    thing this app is for is the person who can see the whole staircase and
    cannot take the first step, so an icon showing several steps would be a
    picture of the problem. The profile below is a single tread and a single
    riser, and the shape is the whole product thesis.
  * The profile shape rather than a pictogram of a foot or a shoe, because a
    foot is a body part and the app is not about bodies. A step is a place to
    stand, which is what a toehold is.
  * Sharp corners, no rounding. The mark is architecture.

## The colour

Teal, and deliberately not warm.

The person opening this app is already under pressure. An amber or orange
icon reads as a warning and a red one reads as a deadline; both are the
feeling the app exists to interrupt. Teal reads as quiet. It is also far
enough from the blues of the stock Reminders and Calendar icons to be picked
out on a home screen at a glance, which is the only competition an app icon
is actually in.

## Sizes

The full traditional set, not the modern single 1024.

`actool` derives the rest from a single size and that is the current
recommendation, but the validator's complaint names pixel sizes in words
("exactly '120x120' pixels", "exactly '152x152' pixels"). Putting those files
in the bundle answers the complaint directly instead of reasoning about the
build step that would generate them. The whole set is a few kilobytes.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "Resources" / "Assets.xcassets"
ICONSET = CATALOG / "AppIcon.appiconset"
ACCENTSET = CATALOG / "AccentColor.colorset"

# Drawn large and reduced. Every edge in the mark is a straight line meeting
# another at a mitre, and those joints are the first thing to go stepped at
# small sizes.
CANVAS = 4096
FINAL = 1024

# Teal. Light enough at the top that the white mark still separates from it,
# deep enough at the bottom that the icon has weight on a bright home screen.
TEAL_TOP = (94, 210, 205)
TEAL_BOTTOM = (26, 122, 138)
MARK = (255, 255, 255)

# The app's tint, taken from the icon so the first screen and the home screen
# agree. The light value is the icon's bottom colour: on white it clears 5:1
# against white text, which matters because the runner's primary button is a
# filled accent-coloured block with white text on it.
ACCENT_LIGHT = (0x1A, 0x7A, 0x8A)
# The dark-appearance value is a lift of the same hue. The light value on a
# black background is legible but muddy; this one is the same colour at the
# brightness a dark surface asks for.
ACCENT_DARK = (0x4F, 0xC3, 0xCE)

# The step profile, in a unit square with y down.
#
# Read it as a staircase seen from the side, stepping up to the right: the
# left edge rises to the tread, the tread runs right, the riser rises to the
# top, and the top runs right. One tread and one riser is the entire mark.
#
# The two runs are equal, which is what makes the silhouette read as a step
# rather than as a corner: an L with unequal arms is a bracket, and equal arms
# are a stair.
INSET = 0.17          # margin from the canvas edge, per side
RISE = 0.5            # where the tread sits, as a fraction of the mark box


def step_profile(x0: float, y0: float, side: float) -> list[tuple[float, float]]:
    """The nine-point outline of one step, in pixels."""
    x1, y1 = x0 + side, y0 + side
    xm = x0 + side * RISE
    ym = y0 + side * RISE
    return [
        (x0, y1),   # bottom-left
        (x0, ym),   # up the left edge to the tread
        (xm, ym),   # the tread, running right
        (xm, y0),   # up the riser to the top
        (x1, y0),   # the top, running right
        (x1, y1),   # down the right edge
    ]


def draw_mark() -> Image.Image:
    """The white area: one step, filled."""
    side = CANVAS * (1 - 2 * INSET)
    x0 = y0 = CANVAS * INSET

    mark = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mark).polygon(step_profile(x0, y0, side), fill=255)
    return mark


def draw_background() -> Image.Image:
    """The teal gradient, top to bottom."""
    img = Image.new("RGB", (1, CANVAS))
    px = img.load()
    for y in range(CANVAS):
        t = y / (CANVAS - 1)
        px[0, y] = tuple(
            round(a + (b - a) * t) for a, b in zip(TEAL_TOP, TEAL_BOTTOM))
    return img.resize((CANVAS, CANVAS), Image.NEAREST)


def render() -> Image.Image:
    art = draw_background()
    art.paste(Image.new("RGB", art.size, MARK), mask=draw_mark())
    # `.convert("RGB")` on the way out is not cosmetic: the App Store rejects
    # an icon whose PNG carries an alpha channel, and PIL writes one for a
    # mode-"RGB" image the moment a mask has been composited into it.
    return art.resize((FINAL, FINAL), Image.LANCZOS).convert("RGB")


# (idiom, point size, scale, pixels). Pixel size is the only thing the
# validator looks at; the rest is bookkeeping that actool requires.
SIZES: list[tuple[str, str, int, int]] = [
    ("iphone", "20x20", 2, 40),
    ("iphone", "20x20", 3, 60),
    ("iphone", "29x29", 2, 58),
    ("iphone", "29x29", 3, 87),
    ("iphone", "40x40", 2, 80),
    ("iphone", "40x40", 3, 120),   # named by the validator
    ("iphone", "60x60", 2, 120),
    ("iphone", "60x60", 3, 180),
    ("ipad", "20x20", 1, 20),
    ("ipad", "20x20", 2, 40),
    ("ipad", "29x29", 1, 29),
    ("ipad", "29x29", 2, 58),
    ("ipad", "40x40", 1, 40),
    ("ipad", "40x40", 2, 80),
    ("ipad", "76x76", 1, 76),
    ("ipad", "76x76", 2, 152),     # named by the validator
    ("ipad", "83.5x83.5", 2, 167),
    ("ios-marketing", "1024x1024", 1, 1024),
]

CONTENTS_HEADER = {
    "info": {"author": "ci/make_app_icon.py", "version": 1},
}


def hex_string(rgb: tuple[int, int, int]) -> str:
    """`0x1A` style components, which is what Xcode writes for sRGB."""
    return "".join(f"0x{c:02X}" for c in rgb)


def write_accent() -> None:
    """The catalog's AccentColor, which the app's tint comes from.

    Written here rather than picked in Xcode because it is the icon's own
    colour. If the icon is ever redrawn, the tint follows it instead of
    drifting, and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` has
    something to resolve to.
    """
    ACCENTSET.mkdir(parents=True, exist_ok=True)

    def entry(rgb: tuple[int, int, int], dark: bool) -> dict:
        color: dict = {
            "color-space": "srgb",
            "components": {
                "alpha": "1.000",
                "red": f"0x{rgb[0]:02X}",
                "green": f"0x{rgb[1]:02X}",
                "blue": f"0x{rgb[2]:02X}",
            },
        }
        item: dict = {"color": color, "idiom": "universal"}
        if dark:
            item["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        return item

    (ACCENTSET / "Contents.json").write_text(
        json.dumps(
            {
                "colors": [entry(ACCENT_LIGHT, False), entry(ACCENT_DARK, True)],
                **CONTENTS_HEADER,
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"  AccentColor {hex_string(ACCENT_LIGHT)} / dark {hex_string(ACCENT_DARK)}")


def main() -> int:
    ICONSET.mkdir(parents=True, exist_ok=True)

    art = render()
    # One file per distinct pixel size. 120 appears twice in the table (iPhone
    # 40@3x and 60@2x) and 40 three times; writing each size once and pointing
    # several entries at it is both smaller and one less thing to keep in sync.
    written: dict[int, str] = {}
    for px in sorted({s[3] for s in SIZES}):
        name = f"AppIcon-{px}.png"
        art.resize((px, px), Image.LANCZOS).save(ICONSET / name, "PNG")
        written[px] = name
        print(f"  {name}")

    images = [
        {"idiom": idiom, "size": size, "scale": f"{scale}x",
         "filename": written[px]}
        for idiom, size, scale, px in SIZES
    ]
    (ICONSET / "Contents.json").write_text(
        json.dumps({"images": images, **CONTENTS_HEADER}, indent=2) + "\n",
        encoding="utf-8")

    (CATALOG / "Contents.json").write_text(
        json.dumps(CONTENTS_HEADER, indent=2) + "\n", encoding="utf-8")

    write_accent()

    print(f"\n{ICONSET}")
    print(f"  {len(written)} files, mode {art.mode} (RGB -- the store rejects alpha)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
