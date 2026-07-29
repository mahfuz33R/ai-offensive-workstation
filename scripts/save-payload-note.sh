#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  save-payload-note --category CATEGORY --name NAME [--source URL_OR_NOTE] [--notes TEXT] [--payload TEXT]

Payload text can also be provided on stdin. This command only records vetted
payload notes under /workspace/config/payloads/custom; it never executes them.
EOF
}

category=
name=
source=
notes=
payload=

while (($#)); do
  case "$1" in
    --category) category="${2:-}"; shift 2 ;;
    --name) name="${2:-}"; shift 2 ;;
    --source|--article-url) source="${2:-}"; shift 2 ;;
    --notes) notes="${2:-}"; shift 2 ;;
    --payload) payload="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$category" || -z "$name" ]]; then
  usage
  exit 2
fi

if [[ -z "$payload" && ! -t 0 ]]; then
  payload="$(cat)"
fi

if [[ -z "$payload" ]]; then
  printf 'No payload text supplied. Use --payload or stdin.\n' >&2
  exit 2
fi

slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

category_slug="$(slug "$category")"
name_slug="$(slug "$name")"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
destination_dir="/workspace/config/payloads/custom/$category_slug"
destination="$destination_dir/${timestamp}-${name_slug}.md"

mkdir -p "$destination_dir"
umask 077

{
  printf '# %s\n\n' "$name"
  printf -- '- Category: `%s`\n' "$category"
  printf -- '- Saved UTC: `%s`\n' "$timestamp"
  printf -- '- Source: `%s`\n' "${source:-manual verification}"
  printf -- '- Status: `candidate-needs-revalidation`\n\n'
  printf '## Safety Notes\n\n'
  printf 'Use only on explicitly authorized targets. Revalidate manually before reuse. Redact secrets and target-specific data before sharing.\n\n'
  printf '## Context Notes\n\n'
  printf '%s\n\n' "${notes:-No additional notes recorded.}"
  printf '## Payload\n\n'
  printf '```text\n'
  printf '%s\n' "$payload" | sed 's/```/` ` `/g'
  printf '```\n'
} > "$destination"

printf 'Saved payload note: %s\n' "$destination"
