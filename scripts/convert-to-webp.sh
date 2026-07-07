#!/usr/bin/env bash
set -euo pipefail

# Convert all PNG and SVG icons in dist/ to WebP format.
# Requires: ImageMagick (magick/convert) with WebP delegate
#
# Usage: bash scripts/convert-to-webp.sh [dist_dir]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-$REPO_ROOT/dist}"

if [ ! -d "$DIST_DIR" ]; then
  echo "Error: dist directory not found at $DIST_DIR" >&2
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
    if [ -f "$aaguid_dir/icon-$variant.png" ]; then
      src="$aaguid_dir/icon-$variant.png"
    elif [ -f "$aaguid_dir/icon-$variant.svg" ]; then
      src="$aaguid_dir/icon-$variant.svg"
    else
      continue
    fi

    dest="$aaguid_dir/icon-$variant.webp"

    if magick "$src" -background none -quality 90 -define webp:lossless=false "$dest" 2>/dev/null; then
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
