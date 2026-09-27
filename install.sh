#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_SRC="$ROOT_DIR/vast-llm"
UI_SRC="$ROOT_DIR/vast-llm-launcher"
ENTRY_SRC="$ROOT_DIR/vast-llm-entry"
BENCH_SRC="$ROOT_DIR/vast-llm-bench"
DOCTOR_SRC="$ROOT_DIR/vast-llm-doctor"
AUTO_SRC="$ROOT_DIR/vast-llm-auto"

for f in "$CORE_SRC" "$UI_SRC" "$ENTRY_SRC" "$BENCH_SRC" "$DOCTOR_SRC" "$AUTO_SRC"; do
  [[ -f "$f" ]] || { echo "ERROR: $f not found" >&2; exit 1; }
done

if [[ "$(id -u)" == 0 ]]; then
  DEST="${VAST_LLM_INSTALL_PATH:-/usr/local/bin/vast-llm}"
  LIB_DIR="${VAST_LLM_LIB_DIR:-/usr/local/lib/vast-llm}"
else
  DEST="${VAST_LLM_INSTALL_PATH:-$HOME/.local/bin/vast-llm}"
  LIB_DIR="${VAST_LLM_LIB_DIR:-$HOME/.local/lib/vast-llm}"
fi

if [[ -n "${VAST_LLM_STATE_DIR:-}" ]]; then
  STATE_DIR="$VAST_LLM_STATE_DIR"
  MODEL_DIR="${VAST_LLM_MODEL_DIR:-$STATE_DIR/models}"
  HF_HOME_DIR="${HF_HOME:-$STATE_DIR/huggingface}"
elif [[ -d /data && -w /data ]]; then
  STATE_DIR=/data/vast-llm
  MODEL_DIR="${VAST_LLM_MODEL_DIR:-/data/models}"
  HF_HOME_DIR="${HF_HOME:-/data/huggingface}"
else
  STATE_DIR="$HOME/.local/share/vast-llm"
  MODEL_DIR="${VAST_LLM_MODEL_DIR:-$STATE_DIR/models}"
  HF_HOME_DIR="${HF_HOME:-$HOME/.cache/huggingface}"
fi
HF_VENV="${VAST_LLM_HF_VENV:-$STATE_DIR/hf-venv}"

CORE_DEST="$LIB_DIR/vast-llm-core"
UI_DEST="$LIB_DIR/vast-llm-ui"
ENTRY_DEST="$LIB_DIR/vast-llm-entry"
BENCH_DEST="$LIB_DIR/vast-llm-bench"
DOCTOR_DEST="$LIB_DIR/vast-llm-doctor"
AUTO_DEST="$LIB_DIR/vast-llm-auto"
ENV_DEST="$LIB_DIR/environment"

mkdir -p "$LIB_DIR" "$(dirname "$DEST")"
install -m 0755 "$CORE_SRC" "$CORE_DEST"
install -m 0755 "$UI_SRC" "$UI_DEST"
install -m 0755 "$ENTRY_SRC" "$ENTRY_DEST"
install -m 0755 "$BENCH_SRC" "$BENCH_DEST"
install -m 0755 "$DOCTOR_SRC" "$DOCTOR_DEST"
install -m 0755 "$AUTO_SRC" "$AUTO_DEST"

mkdir -p "$STATE_DIR/profiles" "$STATE_DIR/logs" "$STATE_DIR/pids" "$STATE_DIR/benchmarks" "$STATE_DIR/runtime" "$MODEL_DIR" "$HF_HOME_DIR"

cat > "$ENV_DEST" <<EOF
export VAST_LLM_LIB_DIR=$(printf '%q' "$LIB_DIR")
export VAST_LLM_STATE_DIR=$(printf '%q' "$STATE_DIR")
export VAST_LLM_MODEL_DIR=$(printf '%q' "$MODEL_DIR")
export VAST_LLM_HF_VENV=$(printf '%q' "$HF_VENV")
export HF_HOME=$(printf '%q' "$HF_HOME_DIR")
EOF
chmod 0644 "$ENV_DEST"

cat > "$DEST" <<EOF
#!/usr/bin/env bash
export VAST_LLM_LIB_DIR=$(printf '%q' "$LIB_DIR")
if [[ -r $(printf '%q' "$ENV_DEST") ]]; then
  # shellcheck disable=SC1090
  source $(printf '%q' "$ENV_DEST")
fi
exec $(printf '%q' "$ENTRY_DEST") "\$@"
EOF
chmod 0755 "$DEST"

echo "Installed Vast LLM Manager (native CUDA / Docker not required):"
echo "  launcher:  $DEST"
echo "  core:      $CORE_DEST"
echo "  advisor:   $AUTO_DEST"
echo "  tuner UI:  $UI_DEST"
echo "  benchmark: $BENCH_DEST"
echo "  doctor:    $DOCTOR_DEST"
echo "  state:     $STATE_DIR"
echo "  models:    $MODEL_DIR"
echo
if [[ ":$PATH:" != *":$(dirname "$DEST"):"* ]]; then
  echo "NOTE: add $(dirname "$DEST") to PATH before using 'vast-llm'."
  echo
fi
echo "Recommended first run on a fresh NVIDIA Vast.ai server:"
echo "  vast-llm hardware"
echo "  vast-llm recommend"
echo "  vast-llm bootstrap"
echo
echo "Or manually:"
echo "  vast-llm doctor --fix"
echo "  vast-llm wizard default"
echo
echo "Optional for gated/private Hugging Face repos:"
echo '  export HF_TOKEN="hf_..."'
