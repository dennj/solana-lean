#!/usr/bin/env bash
# Host-side differential harness for the freestanding runtime's
# copy-on-write and reclamation invariants. See test_cow.c for the probes.
#
# Builds two TUs:
#   - runtime_host.c       hermetic shim; #include's runtime.c with a static
#                          heap and stub embedder hooks (no libc headers, so the
#                          runtime's own memcpy/memset/memmove don't clash with
#                          the host SDK's fortified versions).
#   - test_cow.c           the harness driver. Plain stdio; extern-declares the
#                          runtime API symbols and asserts COW invariants.
#
# Invoked by ctest via add_test_dir() in tests/CMakeLists.txt.

set -euo pipefail

CC="${LEAN_CC:-cc}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRCDIR="${SRC_DIR:-$REPO_ROOT/src}"
RUNTIME_DIR="$SRCDIR/runtime/freestanding"

if [[ ! -f "$RUNTIME_DIR/runtime.c" ]]; then
  echo "SKIP: freestanding runtime not found at $RUNTIME_DIR" >&2
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$CC" -std=c11 -O2 -Wall -Wextra -Wno-unused-function \
  -I"$RUNTIME_DIR" \
  -c -o "$WORK/runtime_host.o" "$SCRIPT_DIR/runtime_host.c"

"$CC" -std=c11 -O2 -Wall -Wextra \
  -c -o "$WORK/test_cow.o" "$SCRIPT_DIR/test_cow.c"

"$CC" -o "$WORK/test_cow" "$WORK/runtime_host.o" "$WORK/test_cow.o"

"$WORK/test_cow"
