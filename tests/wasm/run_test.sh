# WASM cross-compile golden test.
#
# Drives the full Lean -> freestanding wasm32-wasip1 .wasm pipeline:
#
#   lean --target=wasm32-wasip1 --bc=foo.bc Foo.lean
#   leanc --target=wasm32-wasip1 foo.bc -o foo.wasm
#
# and runs each .wasm under Node's built-in `node:wasi` preview1 host,
# asserting that the program produced the expected exit code and (where
# applicable) the expected log lines on stderr.
#
# Skips with a clear message when:
#   - Lean was built without LLVM (no bitcode emit)
#   - Node is unavailable or older than v22 (no built-in WASI)
#   - The system has no clang or wasm-ld (linkWasm can't run)

set -e

LEAN_FEATURES=$(lean --features 2>/dev/null || true)
if ! echo "$LEAN_FEATURES" | grep -q LLVM; then
  echo "SKIP: lean was built without -DLLVM=ON; WASM emit unavailable"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node not found in PATH"
  exit 0
fi
NODE_MAJOR=$(node -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  echo "SKIP: node $NODE_MAJOR is too old (need >= 22 for built-in node:wasi)"
  exit 0
fi

# Probe that linkWasm can find a clang and wasm-ld via its env-overridable
# search. We don't duplicate the search logic here; if linkWasm later
# fails, it surfaces a clear error message of its own.

fail() { echo "TEST FAILED: $*"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRCDIR=$PWD
cp run.mjs "$WORK/"
cd "$WORK"

# build_wasm <Foo.lean> -> produces Foo.wasm at $WORK/Foo.wasm.
build_wasm() {
  local src="$1"
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  lean --target=wasm32-wasip1 --bc="$stem.bc" "$src"
  leanc --target=wasm32-wasip1 "$stem.bc" -o "$stem.wasm" 2>"$stem.leanc.err" \
    || { echo "leanc failed:"; cat "$stem.leanc.err"; return 1; }
  [[ -s "$stem.wasm" ]] || fail "$src: empty .wasm output"
}

# run_wasm <Foo.wasm> -> echoes module's stderr + the `exit=<n>` line.
run_wasm() {
  node run.mjs "$1" 2>&1
}

# ---------------------------------------------------------------------------
# UsesCHelper - user C input receives compile-time flags (`-I`).
# ---------------------------------------------------------------------------
cp "$SRCDIR/UsesCHelper.lean" "$SRCDIR/UsesCHelper.c" .
lean --target=wasm32-wasip1 --bc=UsesCHelper.bc UsesCHelper.lean
leanc --target=wasm32-wasip1 UsesCHelper.bc UsesCHelper.c \
  -I "$SRCDIR/include" -o UsesCHelper.wasm 2>UsesCHelper.leanc.err \
  || { echo "leanc failed:"; cat UsesCHelper.leanc.err; fail "UsesCHelper.wasm build failed"; }
output=$(run_wasm UsesCHelper.wasm)
echo "$output" | grep -q '^exit=37$' \
  || fail "UsesCHelper.wasm: expected exit=37, got:\n$output"
echo "OK: UsesCHelper.wasm exits 37 (user C compile flags)"

# ---------------------------------------------------------------------------
# Denied - deny-list catches IO.FS.readFile at compile time.
# ---------------------------------------------------------------------------
cp "$SRCDIR/Denied.lean" .
if lean --target=wasm32-wasip1 --bc=denied.bc Denied.lean 2>denied.err; then
  fail "lean --target=wasm32-wasip1 accepted Denied.lean despite deny-listed reference"
fi
grep -q 'wasm32-wasip1' denied.err \
  || fail "deny-list: expected wasm32-wasip1 in diagnostic, got:\n$(cat denied.err)"
grep -q 'IO.FS.readFile' denied.err \
  || fail "deny-list: expected decl name in diagnostic, got:\n$(cat denied.err)"
echo "OK: Denied.lean correctly rejected at lean --target=wasm32-wasip1 time"

# ---------------------------------------------------------------------------
# LogMany - 8 BaseIO log calls, all 8 lines on stderr, exit=42.
# ---------------------------------------------------------------------------
build_wasm LogMany.lean
output=$(run_wasm LogMany.wasm)
hits=0
for n in 1 2 3 4 5 6 7 8; do
  if echo "$output" | grep -q "^log line $n$"; then
    hits=$((hits+1))
  fi
done
[[ "$hits" == 8 ]] \
  || fail "LogMany.wasm: only $hits/8 log lines on stderr:\n$output"
echo "$output" | grep -q '^exit=42$' \
  || fail "LogMany.wasm: expected exit=42, got:\n$output"
echo "OK: LogMany.wasm emits all 8 log lines + exits 42"

# ---------------------------------------------------------------------------
# HeapStress - 64 array_push iterations + 32-char string concat;
# exits with array.size XOR string.length = 64 XOR 32 = 96.
# ---------------------------------------------------------------------------
build_wasm HeapStress.lean
output=$(run_wasm HeapStress.wasm)
echo "$output" | grep -q '^exit=96$' \
  || fail "HeapStress.wasm: expected exit=96, got:\n$output"
echo "OK: HeapStress.wasm survives bump-allocator stress (64-array push + 32 string concat)"

# ---------------------------------------------------------------------------
# Multi-runtime smoke (optional). If wasmtime/wasmer happen to be on
# PATH, run LogMany under each one to confirm the .wasm is portable
# across WASI implementations, not a node:wasi quirk.
# ---------------------------------------------------------------------------
for runtime in wasmtime wasmer; do
  if command -v "$runtime" >/dev/null 2>&1; then
    if "$runtime" run LogMany.wasm 2>/dev/null; rc=$?; then :; fi
    [[ "$rc" == 42 ]] \
      || fail "$runtime: expected exit 42 for LogMany.wasm, got $rc"
    echo "OK: LogMany.wasm runs under $runtime and exits 42"
  fi
done

echo "PASS: wasm cross-compile golden test (LogMany + HeapStress + UsesCHelper + Denied)"
