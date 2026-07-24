#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="${1:-/opt/hermes/skills/cybersecurity/offensive-workstation}"
CATALOG="${SKILL_DIR}/help-commands.tsv"
OUTPUT_DIR="${SKILL_DIR}/references/cli-help"
failures=0
HELP_HOME="$(mktemp -d)"
trap 'rm -rf "$HELP_HOME"' EXIT

mkdir -p "$OUTPUT_DIR"

slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

while IFS=$'\t' read -r tool command_name help_arguments; do
  [[ -n "${tool:-}" && "${tool:0:1}" != '#' ]] || continue
  executable="$(command -v "$command_name" 2>/dev/null || true)"
  if [[ -z "$executable" || ! -x "$executable" ]]; then
    printf '[help] missing executable for %s (%s)\n' "$tool" "$command_name" >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ "$help_arguments" == __NO_ARGS__ ]]; then
    arguments=()
    displayed_arguments="(no arguments)"
  else
    read -r -a arguments <<<"$help_arguments"
    displayed_arguments="$help_arguments"
  fi
  raw="$(mktemp)"
  clean="$(mktemp)"
  if env -u SHODAN_API_KEY -u CENSYS_API_ID -u CENSYS_API_SECRET \
      -u VIRUSTOTAL_API_KEY -u GITHUB_TOKEN -u INTERACTSH_TOKEN \
      HOME="$HELP_HOME" XDG_CONFIG_HOME="$HELP_HOME/.config" \
      timeout 30 "$executable" "${arguments[@]}" </dev/null >"$raw" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if (( rc == 124 || rc == 126 || rc == 127 )); then
    printf '[help] failed to capture %s (exit %s)\n' "$tool" "$rc" >&2
    failures=$((failures + 1))
    rm -f "$raw" "$clean"
    continue
  fi
  if grep -Eq 'Traceback \(most recent call last\)|ModuleNotFoundError:|^ImportError:|^SyntaxError:|can.t open file .*\[Errno' "$raw"; then
    printf '[help] %s produced a runtime/import error\n' "$tool" >&2
    tail -n 30 "$raw" >&2
    failures=$((failures + 1))
    rm -f "$raw" "$clean"
    continue
  fi

  if [[ -s "$raw" ]]; then
    # Remove ANSI escapes and unsafe control bytes, avoid ending the Markdown
    # fence, and cap pathological help output at 200 KiB.
    head -c 204800 "$raw" \
      | sed -E $'s/\x1B\[[0-9;?]*[ -/]*[@-~]//g; s/```/` ` `/g' \
      | tr -d '\000-\010\013\014\016-\037\177' > "$clean"
  else
    printf '%s exited successfully but did not print help text for `%s`.\n' \
      "$tool" "$command_name $displayed_arguments" > "$clean"
    printf 'This command may be stdin-driven or may not implement a help flag.\n' >> "$clean"
  fi
  destination="$OUTPUT_DIR/$(slug "$tool").md"
  {
    printf '# Installed help: %s\n\n' "$tool"
    printf -- '- Executable: `%s`\n' "$executable"
    printf -- '- Capture command: `%s %s`\n' "$command_name" "$displayed_arguments"
    printf -- '- Help exit status: `%s`\n\n' "$rc"
    printf '```text\n'
    cat "$clean"
    printf '\n```\n'
  } > "$destination"
  rm -f "$raw" "$clean"
done < "$CATALOG"

if (( failures > 0 )); then
  printf 'Installed-help generation failed for %d command(s).\n' "$failures" >&2
  exit 1
fi

printf 'Generated installed help for %d commands.\n' \
  "$(find "$OUTPUT_DIR" -type f -name '*.md' | wc -l)"
