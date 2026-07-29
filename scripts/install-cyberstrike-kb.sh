#!/usr/bin/env bash
set -uo pipefail
INSTALLER_NAME="cyberstrike-kb"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-common.sh"

KB_SCRIPT="${KB_SCRIPT:-/tmp/install/cyberstrike-kb.py}"
KB_MODEL="${CYBERSTRIKE_KB_MODEL:-BAAI/bge-small-en-v1.5}"
KB_MODEL_CACHE="${FASTEMBED_CACHE_PATH:-/opt/security-assets/models/fastembed}"
KB_VENV="${CYBERSTRIKE_KB_VENV:-$TOOLCHAINS_DIR/python-apps/cyberstrike-kb}"

install_cyberstrike_kb() {
  test -s "$KB_SCRIPT"
  # FastEmbed requires a current tqdm release, while Interlace intentionally
  # pins tqdm 4.62.3. Keep the RAG runtime isolated so both applications retain
  # clean and independently verifiable Python dependency graphs.
  python3 -m venv "$KB_VENV"
  "$KB_VENV/bin/pip" install --upgrade pip wheel
  "$KB_VENV/bin/pip" install fastembed sqlite-vec
  "$KB_VENV/bin/pip" check
  install -d -m 0755 "$KB_MODEL_CACHE"
  install -m 0755 "$KB_SCRIPT" /usr/local/bin/cyberstrike-kb
  install -m 0755 "$KB_SCRIPT" /usr/local/bin/workstation-kb

  FASTEMBED_CACHE_PATH="$KB_MODEL_CACHE" \
    "$KB_VENV/bin/python" - "$KB_MODEL" <<'PY'
import sys
import os
from fastembed import TextEmbedding

model = TextEmbedding(
    model_name=sys.argv[1],
    cache_dir=os.environ["FASTEMBED_CACHE_PATH"],
)
vector = next(iter(model.embed(["query: CyberStrike local knowledge"])))
if len(vector) != 384:
    raise SystemExit(f"unexpected CyberStrike KB embedding size: {len(vector)}")
PY

  /usr/local/bin/cyberstrike-kb --help >/dev/null
  /usr/local/bin/workstation-kb --help >/dev/null
  printf 'cyberstrike-kb\tpython-app-venv\tfastembed+sqlite-vec:%s\t%s\t%s\n' \
    "$KB_MODEL" "$KB_VENV" /usr/local/bin/cyberstrike-kb >> "$RESOLVED_FILE"
  printf 'workstation-kb\tpython-app-venv\tfastembed+sqlite-vec:%s\t%s\t%s\n' \
    "$KB_MODEL" "$KB_VENV" /usr/local/bin/workstation-kb >> "$RESOLVED_FILE"
}

install_step "CyberStrike local hybrid vector knowledge base" \
  "FastEmbed, sqlite-vec, and SQLite FTS5" install_cyberstrike_kb
finish_installer
