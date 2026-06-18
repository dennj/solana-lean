#!/usr/bin/env sh

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRCDIR=$SCRIPT_DIR
ROOT=$(cd "$SRCDIR/../.." && pwd)
LEAN=${LEAN:-"$ROOT/build/release/stage1/bin/lean"}
LEANC=${LEANC:-"$ROOT/build/release/stage1/bin/leanc"}

if [ ! -x "$LEAN" ] || [ ! -x "$LEANC" ]; then
  echo "stage1 lean/leanc not found; build the stage1 target first" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$SRCDIR/Counter.lean" "$WORK/"
cp -R "$SRCDIR/Counter" "$WORK/"
cd "$WORK"
export LEAN_PATH="$WORK${LEAN_PATH:+:$LEAN_PATH}"

lean_module() {
  src=$1
  mod=${src%.lean}
  "$LEAN" --target=wasm32-unknown-unknown --root=. --bc="$mod.bc" -o "$mod.olean" "$src"
}

lean_module Counter/Common.lean
lean_module Counter/Targets.lean
lean_module Counter/Components/Index.lean
lean_module Counter/Components/Calendar.lean
lean_module Counter/Components/Todo.lean
lean_module Counter/Components/Plot.lean
lean_module Counter/Components/TypeChecker.lean
lean_module Counter/Page.lean
lean_module Counter.lean

"$LEANC" --target=wasm32-unknown-unknown \
  Counter/Common.bc \
  Counter/Targets.bc \
  Counter/Components/Index.bc \
  Counter/Components/Calendar.bc \
  Counter/Components/Todo.bc \
  Counter/Components/Plot.bc \
  Counter/Components/TypeChecker.bc \
  Counter/Page.bc \
  Counter.bc \
  -o "$SRCDIR/Counter.wasm"

typechecker_wasm=$(RUN_SMOKE=0 "$SRCDIR/build_lean4lean_typechecker.sh")
node "$SRCDIR/smoke_lean4lean_typechecker.mjs" "$typechecker_wasm" >/dev/null
cp "$typechecker_wasm" "$SRCDIR/lean4lean_typechecker.wasm"

echo "$SRCDIR/Counter.wasm"
echo "$SRCDIR/lean4lean_typechecker.wasm"
