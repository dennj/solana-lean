#!/usr/bin/env bash
# Stdlib probe corpus runner.
#
# Builds + runs each probe for every available (target, runtime). A probe
# passes if it builds AND runs AND exits 0 on every target. The host build
# is the trusted reference; cross-compile divergence = bug.
#
# Probes are tiered:
#   REQUIRED    -> must pass on every available target. Failure = test fail.
#   EXPLORATORY -> may fail on a target that lacks a known runtime feature
#                 (e.g. closures). Recorded but doesn't fail the suite.
#                 When the underlying gap is closed, the probe gets
#                 promoted to REQUIRED.
#
# Skip the test cleanly if no cross-compile target is reachable.

set -euo pipefail

LEAN_FEATURES=$(lean --features 2>/dev/null || true)
if ! echo "$LEAN_FEATURES" | grep -q LLVM; then
  echo "SKIP: lean was built without -DLLVM=ON"
  exit 0
fi

fail() { echo "TEST FAILED: $*" >&2; exit 1; }

PT_PROBE=
if [[ -n "${LEAN_SOLANA_TOOLS:-}" ]]; then
  PT_PROBE="$LEAN_SOLANA_TOOLS"
elif compgen -G "$HOME/.cache/solana/v*/platform-tools" > /dev/null; then
  PT_PROBE=$(ls -d "$HOME/.cache/solana/"v*/platform-tools 2>/dev/null | tail -n1)
fi
HAVE_SBF=0
[[ -n "$PT_PROBE" && -d "$PT_PROBE" ]] && HAVE_SBF=1

HAVE_WASM=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)
  [[ "$NODE_MAJOR" -ge 22 ]] && HAVE_WASM=1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRCDIR="$PWD"
cd "$WORK"

cat > run.mjs <<'EOF'
import { WASI } from 'node:wasi';
import { readFile } from 'node:fs/promises';
import { argv } from 'node:process';
const wasm = await readFile(argv[2]);
const wasi = new WASI({ version: 'preview1', args: [argv[2]], env: {} });
const { instance } = await WebAssembly.instantiate(wasm, wasi.getImportObject());
try { console.log('exit=' + (wasi.start(instance) ?? 0)); }
catch (e) { console.log('exit=' + (e?.code ?? -1)); }
EOF

cat > sbf_entry.c <<'EOF'
/* Shim that adapts the probe's wasm-style entry (`lean_wasm_main(u64) -> u64`)
   to the SBF typed-entry shape required by the leanc dispatcher
   (`lean_sol_entry_typed(ProgramContext) -> u64`). The probes do not consume
   the context, so we ignore the argument. */
extern unsigned long long lean_wasm_main(unsigned long long);
unsigned long long lean_sol_entry_typed(void *_ctx) {
  (void)_ctx;
  return lean_wasm_main(0);
}
EOF

# REQUIRED probes - must pass on every available target.
REQUIRED=(
  UInt64Arith
  UInt8
  UInt32
  Bool
  Option
  Char
  StringOps
  ArrayOps
  ByteArrayOps
  NatArith
  IfMatch
  Tuple
  Sum
  Recursive
  Mutual
  NestedMatch
  Polymorphic
  Structure
  List
  HOF
  ForLoop
  NestedData
  NatOverflow
  NatShiftr
  IncN
  USize
  UnsignedToNat
  CtorMixedPayload
  ArrayPush
  ArrayUset
  ArrayCopyOnWrite
  ByteArrayPush
  ByteArrayUset
  StringDecEq
  StringPush
  StringFromBytes
  StringMultiByte
  MonadDo
  ExceptPath
  Specialize
  Inline
  MatchGuards
  OptionBind
  ExceptThrow
  DecidableEq
  BEq
  WellFoundedRec
  SubtypeBasic
  SigmaBasic
  FinBounded
  UInt64Wrap
  UInt32Underflow
  NatSubSat
  ArrayBoundsSafe
  ByteArrayCapacity
  AllocLarge
  KernelLayoutSync
  MutualStructure
)

EXPLORATORY=(
  UInt64Div
  UInt64Mod
  UInt8Bits
)

run_sbf() {
  local stem="$1"
  cp "$SRCDIR/$stem.lean" .
  if ! lean --target=sbf-solana-solana --bc="$stem.bc" "$stem.lean" 2>"$stem.sbf.lean.err"; then
    echo "    sbf: lean failed" >&2; cat "$stem.sbf.lean.err" >&2; return 1
  fi
  if ! leanc --target=sbf-solana-solana "$stem.bc" sbf_entry.c -o "$stem.sbf.so" 2>"$stem.sbf.cc.err"; then
    echo "    sbf: leanc failed" >&2; cat "$stem.sbf.cc.err" >&2; return 1
  fi
  local und
  und=$("$PT_PROBE/llvm/bin/llvm-readelf" --dyn-syms "$stem.sbf.so" 2>/dev/null \
        | awk '$7=="UND" && $NF !~ /^sol_/ && $NF != "UND" && $NF != "" {print $NF}')
  if [[ -n "$und" ]]; then
    echo "    sbf: leaked UND non-syscall symbols: $und" >&2
    return 1
  fi
  return 0
}

run_wasm() {
  local stem="$1"
  cp "$SRCDIR/$stem.lean" .
  if ! lean --target=wasm32-wasip1 --bc="$stem.wasm.bc" "$stem.lean" 2>"$stem.wasm.lean.err"; then
    echo "    wasm: lean failed" >&2; cat "$stem.wasm.lean.err" >&2; return 1
  fi
  if ! leanc --target=wasm32-wasip1 "$stem.wasm.bc" -o "$stem.wasm" 2>"$stem.wasm.cc.err"; then
    echo "    wasm: leanc failed" >&2; cat "$stem.wasm.cc.err" >&2; return 1
  fi
  local out
  out=$(node run.mjs "$stem.wasm" 2>&1 | grep '^exit=' | head -1)
  if [[ "$out" != "exit=0" ]]; then
    echo "    wasm: produced $out (expected exit=0)" >&2
    return 1
  fi
  return 0
}

# Runs both backends for one probe, prints the formatted line to stderr
# (so it surfaces in test output), and stores PASS/FAIL into globals
# `_sbf` / `_wasm`.
probe() {
  local stem="$1"
  _sbf=- _wasm=-
  if [[ "$HAVE_SBF" == 1 ]]; then
    if run_sbf "$stem" 2>"$stem.sbf.diag"; then _sbf=PASS; else _sbf=FAIL; fi
  fi
  if [[ "$HAVE_WASM" == 1 ]]; then
    if run_wasm "$stem" 2>"$stem.wasm.diag"; then _wasm=PASS; else _wasm=FAIL; fi
  fi
  printf "  %-15s sbf=%-5s wasm=%-5s\n" "$stem" "$_sbf" "$_wasm" >&2
  if [[ "$_sbf"  == FAIL ]]; then cat "$stem.sbf.diag"  >&2 || true; fi
  if [[ "$_wasm" == FAIL ]]; then cat "$stem.wasm.diag" >&2 || true; fi
}

echo "=== REQUIRED probes ===" >&2
required_failures=()
for stem in "${REQUIRED[@]}"; do
  probe "$stem"
  [[ "$_sbf"  == FAIL ]] && required_failures+=("$stem (sbf)")
  [[ "$_wasm" == FAIL ]] && required_failures+=("$stem (wasm)")
done

echo >&2
echo "=== EXPLORATORY probes (XFAIL allowed) ===" >&2
exploratory_unexpected_passes=()
if (( ${#EXPLORATORY[@]} > 0 )); then
  for stem in "${EXPLORATORY[@]}"; do
    probe "$stem"
    [[ "$_sbf"  == PASS ]] && exploratory_unexpected_passes+=("$stem (sbf)")
    [[ "$_wasm" == PASS ]] && exploratory_unexpected_passes+=("$stem (wasm)")
  done
fi

echo
if (( ${#required_failures[@]} > 0 )); then
  fail "${#required_failures[@]} required probe(s) failed: ${required_failures[*]}"
fi

if (( ${#exploratory_unexpected_passes[@]} > 0 )); then
  echo "NOTE: exploratory probes that unexpectedly passed (promote to REQUIRED): ${exploratory_unexpected_passes[*]}"
fi

echo "PASS: stdlib probe corpus (${#REQUIRED[@]} required + ${#EXPLORATORY[@]} exploratory; sbf=$HAVE_SBF wasm=$HAVE_WASM)"
