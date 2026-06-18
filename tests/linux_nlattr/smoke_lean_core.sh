#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
LEAN=${LEAN:-"$ROOT/build/release/stage1/bin/lean"}
LEANC=${LEANC:-"$ROOT/build/release/stage1/bin/leanc"}

if [ ! -x "$LEAN" ] || [ ! -x "$LEANC" ]; then
  echo "SKIP: stage1 lean/leanc not found"
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$LEAN" --root="$SCRIPT_DIR" --bc="$WORK/NlAttrMemory.bc" \
  -o "$WORK/NlAttrMemory.olean" "$SCRIPT_DIR/NlAttrMemory.lean"
LEAN_PATH="$WORK${LEAN_PATH:+:$LEAN_PATH}" "$LEAN" --root="$SCRIPT_DIR" --bc="$WORK/NlAttrCore.bc" \
  -o "$WORK/NlAttrCore.olean" "$SCRIPT_DIR/NlAttrCore.lean"
"$LEANC" -c "$WORK/NlAttrCore.bc" -o "$WORK/NlAttrCore.o"
if command -v nm >/dev/null 2>&1; then
  nm "$WORK/NlAttrCore.o" | grep lean_nlattr_array_index_nospec >/dev/null
fi
"$LEANC" "$WORK/NlAttrCore.bc" "$WORK/NlAttrMemory.bc" "$SCRIPT_DIR/nlattr_raw.c" \
  "$SCRIPT_DIR/lean_core_host_smoke.c" -o "$WORK/lean_core_host"
"$WORK/lean_core_host"
