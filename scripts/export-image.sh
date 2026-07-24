#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ai-offensive-workstation:latest}"
OUTPUT="${2:-ai-offensive-workstation.tar.gz}"
BUNDLE="${3:-${OUTPUT%.tar.gz}-offline-bundle.tar.gz}"
EXPORT_DIR="${OUTPUT%.tar.gz}-offline-files"
IMAGE_BASENAME="$(basename "$OUTPUT")"

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

"${DOCKER[@]}" image inspect "$IMAGE" >/dev/null
printf 'Exporting %s to %s ...\n' "$IMAGE" "$OUTPUT"
"${DOCKER[@]}" save "$IMAGE" | gzip -1 > "$OUTPUT"
printf 'Created %s (%s).\n' "$OUTPUT" "$(du -h "$OUTPUT" | awk '{print $1}')"
printf 'Import elsewhere with: gzip -dc %q | docker load\n' "$OUTPUT"

mkdir -p "$EXPORT_DIR"
cp -f README.md command.md run_exported_image.md docker-compose.yml .env.example secrets.env.example "$EXPORT_DIR/"
ln -f "$OUTPUT" "$EXPORT_DIR/$IMAGE_BASENAME" 2>/dev/null || cp -f "$OUTPUT" "$EXPORT_DIR/$IMAGE_BASENAME"
tar -C "$EXPORT_DIR" -czf "$BUNDLE" .
printf 'Created offline bundle %s (%s).\n' "$BUNDLE" "$(du -h "$BUNDLE" | awk '{print $1}')"
printf 'Bundle contents include: %s, README.md, command.md, run_exported_image.md, docker-compose.yml, .env.example, secrets.env.example\n' "$IMAGE_BASENAME"
