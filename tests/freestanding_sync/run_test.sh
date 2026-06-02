#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_NAME="$(basename "$REPO_DIR")"

if [[ -n "${FREESTANDING_SYNC_PEER:-}" ]]; then
  PEER_DIR="$FREESTANDING_SYNC_PEER"
else
  case "$REPO_NAME" in
    lean4)
      PEER_DIR="$REPO_DIR/../lean4-freestanding"
      ;;
    lean4-freestanding)
      PEER_DIR="$REPO_DIR/../lean4"
      ;;
    *)
      echo "SKIP: unknown checkout name '$REPO_NAME' and FREESTANDING_SYNC_PEER is unset"
      exit 0
      ;;
  esac
fi

if [[ ! -d "$PEER_DIR" ]]; then
  echo "SKIP: freestanding sync peer not found at $PEER_DIR"
  exit 0
fi

PEER_DIR="$(cd "$PEER_DIR" && pwd)"

if [[ "$REPO_NAME" == "lean4-freestanding" ]]; then
  CANONICAL_DIR="$PEER_DIR"
  OTHER_DIR="$REPO_DIR"
else
  CANONICAL_DIR="$REPO_DIR"
  OTHER_DIR="$PEER_DIR"
fi

SYNC_FILES=(
  "src/Lean/Compiler/IR/EmitLLVM.lean"
  "src/Lean/Compiler/UnsupportedOnTargetCmd.lean"
  "src/Std/Freestanding/Unsupported.lean"
  "src/runtime/freestanding/AUDIT.md"
  "src/runtime/freestanding/CMakeLists.txt"
  "src/runtime/freestanding/README.md"
  "src/runtime/freestanding/lean_freestanding.h"
  "src/runtime/freestanding/runtime.c"
  "tests/cross_target/NatLiteralFits64.lean"
  "tests/cross_target/NatLiteralOver64.lean"
  "tests/cross_target/UnsupportedRuntimeFamilies.lean"
  "tests/cross_target/run_test.sh"
  "tests/freestanding_runtime/run_test.sh"
  "tests/freestanding_runtime/runtime_host.c"
  "tests/freestanding_runtime/test_cow.c"
  "tests/freestanding_sync/run_test.sh"
)

missing=0
for file in "${SYNC_FILES[@]}"; do
  if [[ ! -f "$CANONICAL_DIR/$file" ]]; then
    echo "MISSING canonical file: $CANONICAL_DIR/$file"
    missing=1
  fi
  if [[ ! -f "$OTHER_DIR/$file" ]]; then
    echo "MISSING synced file: $OTHER_DIR/$file"
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

failed=0
for file in "${SYNC_FILES[@]}"; do
  if ! diff -u "$CANONICAL_DIR/$file" "$OTHER_DIR/$file"; then
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "Freestanding runtime copies are out of sync."
  echo "Canonical checkout: $CANONICAL_DIR"
  echo "Synced checkout:    $OTHER_DIR"
  exit 1
fi

echo "OK: freestanding runtime and policy files match $OTHER_DIR"
