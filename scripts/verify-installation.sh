#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${1:-/opt/security-manifest/tool-inventory.tsv}"
MANIFEST="${2:-${TOOL_CHECK_REPORT:-/workspace/reports/tool-manifest.tsv}}"
if ! mkdir -p "$(dirname "$MANIFEST")" 2>/dev/null || [[ ! -w "$(dirname "$MANIFEST")" ]]; then
  MANIFEST=/tmp/security-tool-manifest.tsv
fi
MISSING=0

export PATH="/opt/toolchains/node/bin:/usr/local/go/bin:/opt/toolchains/go/bin:/opt/toolchains/python/bin:/opt/toolchains/cargo/bin:${PATH}"
printf 'kind\tname\tstatus\tresolved_path\n' > "$MANIFEST"

asset_present() {
  local candidate="$1"
  if [[ -f "$candidate" ]]; then
    [[ -s "$candidate" ]]
  elif [[ -d "$candidate" ]]; then
    find "$candidate" -mindepth 1 -print -quit | grep -q .
  else
    return 1
  fi
}

while IFS=$'\t' read -r kind name check; do
  [[ -n "${kind:-}" && "${kind:0:1}" != '#' ]] || continue
  case "$kind" in
    command)
      if resolved="$(command -v "$check" 2>/dev/null)"; then status=found; else status=missing; resolved=-; MISSING=$((MISSING + 1)); fi
      ;;
    path)
      if [[ -e "$check" ]]; then status=found; resolved="$check"; else status=missing; resolved=-; MISSING=$((MISSING + 1)); fi
      ;;
    asset)
      if asset_present "$check"; then status=found; resolved="$check"; else status=missing; resolved=-; MISSING=$((MISSING + 1)); fi
      ;;
    capability)
      IFS='|' read -r capability_command required_capability <<<"$check"
      if executable="$(command -v "$capability_command" 2>/dev/null)" \
        && executable="$(readlink -f "$executable")" \
        && current_capabilities="$(getcap "$executable")" \
        && [[ "$current_capabilities" == *"$required_capability"* ]]; then
        status=found
        resolved="$current_capabilities"
      else
        status=missing
        resolved=-
        MISSING=$((MISSING + 1))
      fi
      ;;
    *)
      printf 'Unknown inventory kind %s for %s\n' "$kind" "$name" >&2
      exit 2
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$kind" "$name" "$status" "$resolved" >> "$MANIFEST"
done < "$INVENTORY"

if (( MISSING > 0 )); then
  printf 'Verification failed: %d required entries are missing.\n' "$MISSING" >&2
  awk -F '\t' '$3 == "missing"' "$MANIFEST" >&2
  exit 1
fi

printf 'Verification passed: %d required entries found.\n' "$(( $(wc -l < "$MANIFEST") - 1 ))"
