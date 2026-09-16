#!/usr/bin/env bash
set -euo pipefail

selection="$(slurp -p -f '%x,%y')"
if [[ ! "$selection" =~ ^[[:space:]]*(-?[0-9]+),(-?[0-9]+)[[:space:]]*$ ]]; then
  printf 'Invalid point selection: %s\n' "$selection" >&2
  exit 1
fi

x="${BASH_REMATCH[1]}"
y="${BASH_REMATCH[2]}"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT
grim -t ppm -g "$x,$y 1x1" "$tmp_file"

python3 - "$tmp_file" <<'PY'
import colorsys
import json
import sys

data = open(sys.argv[1], "rb").read()
parts = data.split(b"\n", 3)
if len(parts) != 4:
    raise SystemExit("unexpected pixel image from grim")
header, pixel = parts[:3], parts[3]
if header[0] != b"P6" or header[1] != b"1 1" or header[2] != b"255" or len(pixel) < 3:
    raise SystemExit("unexpected pixel image from grim")

r, g, b = pixel[:3]
red, green, blue = (value / 255 for value in (r, g, b))
hue, saturation, lightness = colorsys.rgb_to_hls(red, green, blue)
print(json.dumps({
    "hex": f"#{r:02X}{g:02X}{b:02X}",
    "rgb": f"rgb({r}, {g}, {b})",
    "hsl": f"hsl({round(hue * 360)}, {round(saturation * 100)}%, {round(lightness * 100)}%)",
}))
PY
