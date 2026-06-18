#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEAN4_DIR="${LEAN4_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LEAN4_DIR="$(cd "$LEAN4_DIR" && pwd)"
WORKSPACE_DIR="$(cd "$LEAN4_DIR/.." && pwd)"
LEAN4LEAN_DIR="${LEAN4LEAN_DIR:-$WORKSPACE_DIR/lean4lean}"
LEAN4LEAN_DIR="$(cd "$LEAN4LEAN_DIR" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/.build/lean4lean-typechecker}"

LEAN="$LEAN4_DIR/build/release/stage1/bin/lean"
LEANC="$LEAN4_DIR/build/release/stage1/bin/leanc"
LEAN4_LIB="$LEAN4_DIR/build/release/stage1/lib/lean"
LEAN4_TEMP="$LEAN4_DIR/build/release/stage1/lib/temp"
LEAN4_INCLUDE="$LEAN4_DIR/build/release/stage1/include"

if [[ ! -x "$LEAN" || ! -x "$LEANC" ]]; then
  echo "stage1 Lean toolchain not found under $LEAN4_DIR/build/release/stage1" >&2
  exit 1
fi

if [[ ! -f "$LEAN4LEAN_DIR/FreestandingTypeCheckerCore.lean" ]]; then
  echo "Lean4Lean freestanding checker not found under $LEAN4LEAN_DIR" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR/Lean4Lean" "$BUILD_DIR/support_c"
rm -rf "$BUILD_DIR/support_c"
mkdir -p "$BUILD_DIR/support_c"

export LEAN_PATH="$BUILD_DIR:$LEAN4_LIB"

module_from_olean() {
  local path="$1"
  case "$path" in
    "$LEAN4_LIB"/*.olean)
      local rel="${path#$LEAN4_LIB/}"
      rel="${rel%.olean}"
      echo "${rel//\//.}"
      ;;
  esac
}

copy_support_module() {
  local mod="$1"
  case "$mod" in
    Init|Init.Control|Init.Data|Init.System|Lean) return 0 ;;
  esac
  local rel="${mod//.//}.c"
  local src="$LEAN4_TEMP/$rel"
  local dst="$BUILD_DIR/support_c/${mod//./__}.c"
  [[ -f "$src" ]] || return 0
  cp "$src" "$dst"
}

support_seen="$BUILD_DIR/support_modules.seen"
support_queue="$BUILD_DIR/support_modules.queue"
: > "$support_seen"
: > "$support_queue"

enqueue_support_module() {
  local mod="$1"
  [[ -z "$mod" ]] && return 0
  if ! grep -Fxq "$mod" "$support_seen"; then
    echo "$mod" >> "$support_seen"
    echo "$mod" >> "$support_queue"
  fi
}

seed_support_from_source() {
  local root="$1"
  local src="$2"
  "$LEAN" --deps --root="$root" "$src" | while IFS= read -r dep; do
    local mod
    mod="$(module_from_olean "$dep" || true)"
    enqueue_support_module "$mod"
  done
}

compile_lean() {
  local src="$1"
  local base="${src%.lean}"
  local bc="$BUILD_DIR/$base.bc"
  mkdir -p "$(dirname "$bc")"
  "$LEAN" --target=wasm32-wasip1 --root="$LEAN4LEAN_DIR" \
    --bc="$bc" -o "$BUILD_DIR/$base.olean" "$LEAN4LEAN_DIR/$src"
}

compile_demo_lean() {
  local src="$1"
  local base="${src%.lean}"
  local bc="$BUILD_DIR/$base.bc"
  mkdir -p "$(dirname "$bc")"
  "$LEAN" --target=wasm32-wasip1 --root="$SCRIPT_DIR" \
    --bc="$bc" -o "$BUILD_DIR/$base.olean" "$SCRIPT_DIR/$src"
}

while IFS= read -r src; do
  [[ -z "$src" ]] && continue
  compile_lean "$src"
  seed_support_from_source "$LEAN4LEAN_DIR" "$LEAN4LEAN_DIR/$src"
done <<'MODULES'
Lean4Lean/Declaration.lean
Lean4Lean/List.lean
Lean4Lean/Level.lean
Lean4Lean/Environment/Basic.lean
Lean4Lean/Expr.lean
Lean4Lean/Instantiate.lean
Lean4Lean/LocalContext.lean
Lean4Lean/Quot.lean
Lean4Lean/Inductive/Reduce.lean
Lean4Lean/PtrEq.lean
Lean4Lean/EquivManager.lean
Lean4Lean/ForEachExprV.lean
Lean4Lean/TypeChecker.lean
FreestandingTypeCheckerCore.lean
MODULES

compile_demo_lean Lean4LeanTypeCheckerMain.lean
seed_support_from_source "$SCRIPT_DIR" "$SCRIPT_DIR/Lean4LeanTypeCheckerMain.lean"

enqueue_support_module Init.Syntax

queue_index=1
while true; do
  mod="$(sed -n "${queue_index}p" "$support_queue")"
  [[ -z "$mod" ]] && break
  queue_index=$((queue_index + 1))
  copy_support_module "$mod"
  src="$LEAN4_DIR/src/${mod//.//}.lean"
  [[ -f "$src" ]] || continue
  seed_support_from_source "$LEAN4_DIR/src" "$src"
done

find "$BUILD_DIR/support_c" -type f -name '*.c' -exec perl -0pi -e \
  's/lean_object\* (initialize_[A-Za-z0-9_]+)\(uint8_t builtin\);/lean_object* $1(uint8_t builtin, lean_object* lean_wasm_init_world);/g; s/LEAN_EXPORT lean_object\* (initialize_[A-Za-z0-9_]+)\(uint8_t builtin\) \{/LEAN_EXPORT lean_object* $1(uint8_t builtin, lean_object* lean_wasm_init_world) {/g; s/\b(initialize_[A-Za-z0-9_]+)\(builtin\)/$1(builtin, lean_wasm_init_world)/g' {} +

support_c="$(find "$BUILD_DIR/support_c" -maxdepth 1 -type f -name '*.c' | sort)"
lean4lean_bc="$(find "$BUILD_DIR/Lean4Lean" -type f -name '*.bc' | sort)"
out="$BUILD_DIR/lean4lean_typechecker.wasm"

"$LEANC" --target=wasm32-wasip1 -O2 -DLEAN_EMSCRIPTEN -I "$LEAN4_INCLUDE" \
  -o "$out" \
  -Wl,--export=lean_wasm_module_init \
  -Wl,--export=lean4lean_typechecker_main \
  -Wl,--export=lean4lean_check_text \
  -Wl,--export=lean4lean_alloc_bytes \
  "$BUILD_DIR/FreestandingTypeCheckerCore.bc" \
  "$BUILD_DIR/Lean4LeanTypeCheckerMain.bc" \
  $lean4lean_bc $support_c "$SCRIPT_DIR/lean4lean_typechecker_shims.c"

if [[ "${RUN_SMOKE:-1}" != "0" && -x "$(command -v node || true)" ]]; then
  node "$SCRIPT_DIR/smoke_lean4lean_typechecker.mjs" "$out"
fi

echo "$out"
