#!/usr/bin/env bash
set -euo pipefail

# Convert all PNG and SVG icons in dist/ to WebP format.
# Requires: ImageMagick (magick) with WebP delegate, rsvg-convert (librsvg)
#
# SVG files are rendered via rsvg-convert (which properly handles gradients,
# <use> references, and transforms) before WebP encoding. ImageMagick's
# internal MSVG renderer is unreliable for complex SVGs.
#
# Usage: bash scripts/convert-to-webp.sh [dist_dir]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-$REPO_ROOT/dist}"

if [ ! -d "$DIST_DIR" ]; then
  echo "Error: dist directory not found at $DIST_DIR" >&2
  exit 1
fi

if ! command -v rsvg-convert &>/dev/null; then
  echo "Error: rsvg-convert not found. Install librsvg (brew install librsvg / apt install librsvg2-bin)." >&2
  exit 1
fi

converted=0
failed=0

for aaguid_dir in "$DIST_DIR"/*/; do
  [ -d "$aaguid_dir" ] || continue

  meta_file="$aaguid_dir/meta.json"
  [ -f "$meta_file" ] || continue

  meta_changed=false
  meta=$(cat "$meta_file")

  for variant in dark light; do
    src=""
    src_type=""
    if [ -f "$aaguid_dir/icon-$variant.png" ]; then
      src="$aaguid_dir/icon-$variant.png"
      src_type="png"
    elif [ -f "$aaguid_dir/icon-$variant.svg" ]; then
      src="$aaguid_dir/icon-$variant.svg"
      src_type="svg"
    else
      continue
    fi

    dest="$aaguid_dir/icon-$variant.webp"
    ok=false

    if [ "$src_type" = "svg" ]; then
      tmp_png=$(mktemp "${TMPDIR:-/tmp}/icon-XXXXXX.png")
      if rsvg-convert "$src" -w 128 -h 128 -o "$tmp_png" 2>/dev/null; then
        if magick "$tmp_png" -quality 90 -define webp:lossless=false "$dest" 2>/dev/null; then
          ok=true
        fi
      fi
      rm -f "$tmp_png"
    else
      if magick "$src" -background none -quality 90 -define webp:lossless=false "$dest" 2>/dev/null; then
        ok=true
      fi
    fi

    if [ "$ok" = true ]; then
      rm -f "$src"
      meta=$(echo "$meta" | jq --arg k "icon_$variant" --arg v "icon-$variant.webp" '. + {($k): $v}')
      meta_changed=true
      converted=$((converted + 1))
    else
      echo "Warning: Failed to convert $src" >&2
      failed=$((failed + 1))
    fi
  done

  if [ "$meta_changed" = true ]; then
    echo "$meta" > "$meta_file"
  fi
done

echo "WebP conversion complete: $converted converted, $failed failed"
