#!/usr/bin/env sh

# Browser-reactor WASM cross-compile smoke test.

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRCDIR=$SCRIPT_DIR
ROOT=$(cd "$SRCDIR/../.." && pwd)
LEAN=${LEAN:-"$ROOT/build/release/stage1/bin/lean"}
LEANC=${LEANC:-"$ROOT/build/release/stage1/bin/leanc"}

if [ ! -x "$LEAN" ] || [ ! -x "$LEANC" ]; then
  echo "SKIP: stage1 lean/leanc not found; build the stage1 target first"
  exit 0
fi

LEAN_FEATURES=$("$LEAN" --features 2>/dev/null || true)
if ! echo "$LEAN_FEATURES" | grep -q LLVM; then
  echo "SKIP: lean was built without -DLLVM=ON; WASM emit unavailable"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node not found in PATH"
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$SRCDIR/Counter.lean" "$SRCDIR/run.mjs" "$WORK/"
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
  -o Counter.wasm

output=$(node run.mjs Counter.wasm)
echo "$output" | grep -q '^counter=Lean4Wasm reactor handled browser event #1$'

echo "PASS: web wasm reactor smoke"
