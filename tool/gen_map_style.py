#!/usr/bin/env python3
"""Generates BonnetCheck's two map styles from OpenFreeMap's Positron.

    python tool/gen_map_style.py

Writes `assets/map/bonnetcheck-light.json` and `-dark.json`.

Why generate rather than hand-write: a MapLibre style is 55 layers of
interlocking paint rules, and hand-editing it means the light and dark versions
drift apart the first time somebody fixes one of them. Here the palette is
declared once, at the top, and both files fall out of it.

Why Positron as the base: it was drawn to sit *underneath* data. Roads and
buildings are barely there, which is what we want — the map is a backdrop for
pins, and a loud basemap swallows them.

Two things this changes beyond colour:

  * **Labels prefer Hebrew.** Positron concatenates the Latin and non-Latin
    name, so every Israeli town would read "Tel Aviv-Yafo תל אביב-יפו" on one
    line. In an app that is Hebrew throughout, the Latin half is noise.
  * **Fewer layers.** Ice shelves, glaciers and US highway shields are dead
    weight in Israel; dropping them makes every tile cheaper to draw.

The source is fetched live from OpenFreeMap and is ODbL OpenStreetMap data —
attribution is required and is rendered by `MapAttribution`, not by the style.
"""

import io
import json
import os
import urllib.request

SOURCE = "https://tiles.openfreemap.org/styles/positron"
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "map")

# ---------------------------------------------------------------- palettes --
# Taken from lib/core/constants/app_colors.dart and lib/core/theme/
# app_palette.dart. If a token changes there, change it here and re-run.

LIGHT = {
    "background": "#F8FAF9",   # AppColors.background — the app's own page colour
    "park":       "#E7EFEA",   # tealLight: green space reads as brand-adjacent
    "wood":       "#DFE9E2",
    "water":      "#CDDBDD",   # desaturated, so it never competes with a pin
    "waterway":   "#C2D2D5",
    "residential": "#F1F3F2",
    "building":   "#ECEFEE",
    "buildingLine": "#E2E6E4",
    "roadFill":   "#FFFFFF",   # surface: roads read as paper, not as lines
    "roadCasing": "#E6EAE8",   # cardBorder — the same hairline the UI uses
    "roadMinor":  "#F2F4F3",
    "rail":       "#E6EAE8",
    "railDash":   "#F8FAF9",
    "boundary":   "#C6CDC9",
    "labelMajor": "#1A202C",   # textPrimary
    "labelMinor": "#5A6169",   # textMuted
    "labelFaint": "#767C81",   # textSubtle
    "labelWater": "#5B7B84",
    "halo":       "#F8FAF9",
}

DARK = {
    "background": "#101312",
    "park":       "#1B2620",
    "wood":       "#18211C",
    # Bluer and clearly lighter than the land, because in the dark theme the
    # first version was #141C1F against a #101312 ground and the Mediterranean
    # simply was not visible. The coastline is how anyone orients themselves on
    # a map of Israel; losing it costs more than the extra contrast does.
    "water":      "#1B2C34",
    "waterway":   "#22363F",
    "residential": "#141817",
    "building":   "#1A1F1D",
    "buildingLine": "#232927",
    "roadFill":   "#2A302E",   # cardBorder: roads lift off the ground, faintly
    "roadCasing": "#151A18",
    "roadMinor":  "#202523",
    "rail":       "#232927",
    "railDash":   "#171B1A",
    "boundary":   "#39413D",
    "labelMajor": "#E8EBEA",   # textPrimary (dark)
    "labelMinor": "#A2ABA6",   # textMuted (dark)
    "labelFaint": "#8A938D",   # textSubtle (dark)
    "labelWater": "#7E9AA2",
    "halo":       "#101312",
}

# Layers that carry no meaning in Israel and only cost draw time.
DROP = {
    "landcover_ice_shelf",
    "landcover_glacier",
    "highway-shield-us-interstate",
    "road_shield_us",
    "label_country_1",
    "label_country_2",
    "label_country_3",
    "boundary_disputed",
}

# id -> (paint key, palette key). Applied in order; the first id that the layer
# starts with wins, so specific ids must precede their prefixes.
FILL = [
    ("park", "park"),
    ("landcover_wood", "wood"),
    ("landuse_residential", "residential"),
    ("water", "water"),
    ("building", "building"),
    ("aeroway-area", "roadFill"),
    ("road_area_pier", "background"),
]

LINE = [
    ("waterway", "waterway"),
    ("highway_motorway_casing", "roadCasing"),
    ("highway_motorway_bridge_casing", "roadCasing"),
    ("highway_major_casing", "roadCasing"),
    ("tunnel_motorway_casing", "roadCasing"),
    ("highway_motorway_inner", "roadFill"),
    ("highway_motorway_bridge_inner", "roadFill"),
    ("highway_major_inner", "roadFill"),
    ("tunnel_motorway_inner", "roadFill"),
    ("highway_motorway_subtle", "roadMinor"),
    ("highway_major_subtle", "roadMinor"),
    ("highway_minor", "roadMinor"),
    ("highway_path", "roadMinor"),
    ("aeroway-runway-casing", "roadCasing"),
    ("aeroway-runway", "roadFill"),
    ("aeroway-taxiway", "roadMinor"),
    ("road_pier", "background"),
    ("railway_transit_dashline", "railDash"),
    ("railway_service_dashline", "railDash"),
    ("railway_dashline", "railDash"),
    ("railway_transit", "rail"),
    ("railway_service", "rail"),
    ("railway", "rail"),
    ("boundary_", "boundary"),
]

# Label colour by layer id. Cities and towns are what a person navigating by
# map actually reads, so they get the darkest ink; everything else recedes.
TEXT = [
    ("label_city_capital", "labelMajor"),
    ("label_city", "labelMajor"),
    ("label_town", "labelMajor"),
    ("label_state", "labelFaint"),
    ("label_village", "labelMinor"),
    ("label_other", "labelMinor"),
    ("water_name_point_label", "labelWater"),
    ("water_name_line_label", "labelWater"),
    ("waterway_line_label", "labelWater"),
    ("highway-name-major", "labelMinor"),
    ("highway-name-minor", "labelFaint"),
    ("highway-name-path", "labelFaint"),
    ("airport", "labelMinor"),
]

# Hebrew first, the plain name as a fallback for anything unnamed in Hebrew.
HEBREW_LABEL = [
    "coalesce",
    ["get", "name:he"],
    ["get", "name"],
    ["get", "name:latin"],
]


def _match(layer_id, table):
    for prefix, key in table:
        if layer_id == prefix or layer_id.startswith(prefix):
            return key
    return None


def build(source, palette):
    style = json.loads(json.dumps(source))  # deep copy
    style["name"] = "BonnetCheck"
    layers = []

    for layer in style["layers"]:
        lid = layer.get("id", "")
        if lid in DROP:
            continue

        paint = layer.setdefault("paint", {})
        kind = layer.get("type")

        if kind == "background":
            paint["background-color"] = palette["background"]

        elif kind == "fill":
            key = _match(lid, FILL)
            if key:
                paint["fill-color"] = palette[key]
            if "fill-outline-color" in paint:
                paint["fill-outline-color"] = palette["buildingLine"]

        elif kind == "line":
            key = _match(lid, LINE)
            if key:
                # Some road layers interpolate colour by zoom. Replacing the
                # expression with a flat colour is deliberate: the interpolation
                # existed to fade motorways into Positron's greys, and ours are
                # already quiet enough not to need it.
                paint["line-color"] = palette[key]

        elif kind == "symbol":
            key = _match(lid, TEXT)
            if key:
                paint["text-color"] = palette[key]
            if "text-halo-color" in paint:
                paint["text-halo-color"] = palette["halo"]
            layout = layer.setdefault("layout", {})
            if "text-field" in layout:
                layout["text-field"] = HEBREW_LABEL

        layers.append(layer)

    style["layers"] = layers
    return style


def main():
    print("fetching", SOURCE)
    # A named User-Agent, not urllib's default: OpenFreeMap answers the
    # default with 403. Identify the project, as its own tile policy asks.
    request = urllib.request.Request(
        SOURCE,
        headers={"User-Agent": "BonnetCheck-style-generator (+https://bonnetcheck.web.app)"},
    )
    with urllib.request.urlopen(request) as response:
        source = json.load(response)
    print("  {} layers".format(len(source["layers"])))

    os.makedirs(OUT_DIR, exist_ok=True)
    for name, palette in (("light", LIGHT), ("dark", DARK)):
        style = build(source, palette)
        path = os.path.join(OUT_DIR, "bonnetcheck-{}.json".format(name))
        with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(style, handle, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(path)
        print("wrote {}  {} layers  {:,} bytes".format(
            os.path.relpath(path), len(style["layers"]), size))


if __name__ == "__main__":
    main()
