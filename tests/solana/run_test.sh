# SBF / Solana cross-compile golden test.
#
# Drives the full Lean -> SBF .so pipeline:
#
#   lean --target=sbf-solana-solana --bc=foo.bc Foo.lean
#   leanc --target=sbf-solana-solana foo.bc -o foo.so
#
# and asserts structural invariants on the output rather than pinning a
# byte-exact disassembly. The exact codegen depends on platform-tools
# version, llc/clang optimization, and minor stack-frame layout - all of
# which can drift across environments without changing what the program
# does. The invariants checked here are what actually has to hold for a
# program to be deployable on the Solana VM.
#
# Skips with a clear message (rather than failing) when LLVM was not
# enabled in the Lean build or when platform-tools cannot be located.

set -eo pipefail

# Fall back to local definitions when this script is invoked directly
# (without `tests/with_stage1_test_env.sh`, which sources tests/util.sh).
type fail >/dev/null 2>&1 || fail() { echo "TEST FAILED: $1" >&2; exit 1; }
type run  >/dev/null 2>&1 || run()  { (set -x; "$@") || fail "command failed: $*"; }

LEAN_FEATURES=$(lean --features 2>/dev/null || true)
if ! echo "$LEAN_FEATURES" | grep -q LLVM; then
  echo "SKIP: lean was built without -DLLVM=ON; SBF emit unavailable"
  exit 0
fi

PT_PROBE=
if [[ -n "${LEAN_SOLANA_TOOLS:-}" ]]; then
  PT_PROBE="$LEAN_SOLANA_TOOLS"
elif compgen -G "$HOME/.cache/solana/v*/platform-tools" > /dev/null; then
  PT_PROBE=$(ls -d "$HOME/.cache/solana/"v*/platform-tools 2>/dev/null | tail -n1)
fi
if [[ -z "$PT_PROBE" || ! -d "$PT_PROBE" ]]; then
  echo "SKIP: platform-tools not found (set LEAN_SOLANA_TOOLS or run 'agave-install init')"
  exit 0
fi

READELF="$PT_PROBE/llvm/bin/llvm-readelf"
OBJDUMP="$PT_PROBE/llvm/bin/llvm-objdump"
[[ -x "$READELF" && -x "$OBJDUMP" ]] || fail "missing readelf/objdump in platform-tools"

# Sandbox the build artefacts in a temp dir so test repeats are clean.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRCDIR=$PWD
cd "$WORK"

run lean "$SRCDIR/StdSolanaLibrary.lean"

# Run leanc with the standard SBF args, but additionally fail fast if
# the SBF backend prints any "Stack offset of N exceeded max offset"
# warning. clang/llc emit those when a function's stack frame would
# overflow the SBF VM's 4 KB per-frame budget; the .so still links but
# would trigger UB on chain. This guard keeps that class of bug from
# regressing (it has caught a CPI `SolAccountInfo infos[256]` instance
# in the past).
leanc_check_stack() {
  local stem="$1"
  shift
  local err="$WORK/$stem.leanc.stderr"
  if ! leanc "$@" 2>"$err"; then
    cat "$err" >&2
    fail "leanc failed for $stem"
  fi
  if grep -q 'Stack offset of [0-9]\+ exceeded max offset' "$err"; then
    cat "$err" >&2
    fail "$stem: SBF function stack frame exceeds 4 KB (on-chain UB). \
Move the offending stack allocation to bump_alloc."
  fi
}

# check_program <src.lean> <expected-immediate-hex> [entry-symbol]
#   Asserts that the program lowers to a deployable Solana .so whose
#   entry function mentions the given immediate (`0x77` etc.).
#   Default entry-symbol is `lean_sol_entry_typed`, the canonical typed
#   entrypoint shape `(ProgramContext) -> UInt64`.
check_program() {
  local src="$1"
  local imm="$2"
  local entry_sym="${3:-lean_sol_entry_typed}"
  # The .bc filename's stem must match the Lean module name (matching the
  # `source_filename` in the emitted bitcode), because leanc derives
  # `initialize_<UserMod>` from it when generating the per-build init
  # wrapper.
  local stem="${src%.lean}"
  local bc="$stem.bc"
  local so="$stem.so"

  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$bc" "$src"
  [[ -s "$bc" ]] || fail "lean did not produce $bc"

  local sz
  sz=$(wc -c < "$bc")
  [[ "$sz" -lt 51200 ]] \
    || fail "SBF bitcode for $src is unexpectedly large ($sz bytes); host runtime may have been linked in"

  leanc_check_stack "$stem" --target=sbf-solana-solana "$bc" -o "$so"
  [[ -s "$so" ]] || fail "leanc did not produce $so"

  local hdr; hdr=$("$READELF" -h "$so")
  echo "$hdr" | grep -q 'EM_BPF' || fail "$so is not an EM_BPF object\n$hdr"
  echo "$hdr" | grep -q 'DYN'    || fail "$so is not a DYN shared object\n$hdr"

  local dynsyms; dynsyms=$("$READELF" --dyn-syms "$so")
  echo "$dynsyms" | grep -q " ${entry_sym}\$" || fail "$entry_sym not exported in $so\n$dynsyms"
  echo "$dynsyms" | grep -q ' entrypoint$'    || fail "entrypoint not exported in $so\n$dynsyms"

  local und_non_sol
  und_non_sol=$(echo "$dynsyms" | awk '$1 ~ /^[0-9]+:$/ && NF == 8 && $7 == "UND" && $NF !~ /^sol_/ {print $NF}' | tr '\n' ' ')
  [[ -z "$und_non_sol" ]] || fail "non-syscall UND symbols leaked into $so: $und_non_sol"

  local disasm; disasm=$("$OBJDUMP" -d --disassemble-symbols="$entry_sym" "$so")
  echo "$disasm" | grep -q "$imm" \
    || fail "$so $entry_sym disassembly is missing immediate $imm\n$disasm"
  echo "$disasm" | tail -n 6 | grep -q '\bexit\b' \
    || fail "$so $entry_sym does not end in exit\n$disasm"

  echo "OK: $so is a deployable Solana program ($(wc -c < "$so") bytes)"
}

# Typed exercises the typed-entrypoint shape:
# `def entry (ctx : ProgramContext) : UInt64`.  The 0x77 marker
# constant is the dominant immediate.
check_program Typed.lean       0x77

# DupAccounts exercises the `dup_info != 0xFF` path of the typed
# entrypoint deserialiser (`lean_sbf_make_program_context`). 0x55 is
# the program's marker constant.
check_program DupAccounts.lean 0x55

# EntrypointSugar checks that `@[solana_entrypoint]` expands to the canonical
# `lean_sol_entry_typed` export consumed by the SBF runtime adapter.
check_program EntrypointSugar.lean 0x66

# LibraryHelpers exercises reusable Std.Solana Bytes/Borsh helpers through
# the typed SBF entrypoint. Its generated entrypoint is large enough that
# `check_program`'s simple tail-disassembly heuristic is too brittle, so keep
# this as a structural link check.
check_library_helpers_program() {
  local src=LibraryHelpers.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  echo "$syms" | grep -q ' lean_sol_entry_typed$' \
    || fail "$stem.so missing lean_sol_entry_typed\n$syms"
  local und_non_sol
  und_non_sol=$(echo "$syms" | awk '$1 ~ /^[0-9]+:$/ && NF == 8 && $7 == "UND" && $NF !~ /^sol_/ {print $NF}' | tr '\n' ' ')
  [[ -z "$und_non_sol" ]] || fail "non-syscall UND symbols leaked into $stem.so: $und_non_sol"
  echo "OK: $stem.so links reusable Std.Solana helper code without runtime leaks"
}
check_library_helpers_program

# LogMany emits 8 sequential `msg!` calls. The `@[never_extract]`
# semantics require Lean's IR optimizer to keep every call alive even
# though the result is unused. The test pins both contracts:
#   (a) lean_sol_log is referenced from the .so's dynsyms,
#   (b) all 8 distinct literal strings reach .rodata.
check_log_many() {
  local src=LogMany.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  grep -Fq 'lean_sol_log' <<<"$syms" \
    || fail "$stem.so does not reference lean_sol_log:\n$syms"
  grep -Fq 'lean_sol_entry_typed' <<<"$syms" \
    || fail "$stem.so does not export lean_sol_entry_typed:\n$syms"
  local hits=0
  for n in 1 2 3 4 5 6 7 8; do
    if strings "$stem.so" | grep -q "^log line $n$"; then
      hits=$((hits+1))
    fi
  done
  [[ "$hits" == 8 ]] \
    || fail "$stem.so retained $hits/8 log strings; never_extract DCE guard regressed"
  echo "OK: $stem.so retains all 8 msg! call sites (never_extract DCE guard)"
}
check_log_many

# InvokeShape exercises Std.Solana.invokeSigned. The structural check
# (next block) asserts that the linked .so retains references to
# both the runtime helper and the SBF syscall, proving the CPI
# pipeline links cleanly. Behavioural verification (does invoking the
# System Program actually transfer lamports?) lives in deploy_test.sh
# under LEAN_SBF_DEPLOY_TEST, since it requires a running validator.
check_invoke_program() {
  local src=InvokeShape.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  echo "$syms" | grep -q ' lean_sbf_invoke_signed$' \
    || fail "$stem.so missing lean_sbf_invoke_signed (CPI runtime)\n$syms"
  echo "$syms" | grep -q ' sol_invoke_signed_c$' \
    || fail "$stem.so missing sol_invoke_signed_c (CPI syscall)\n$syms"
  echo "OK: $stem.so retains the CPI runtime + syscall references"
}
check_invoke_program

# Pda exercises Std.Solana.findProgramAddress. Structural check
# asserts the runtime helper and SBF syscall both reach the .so.
check_pda_program() {
  local src=Pda.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  echo "$syms" | grep -q ' lean_sbf_find_program_address$' \
    || fail "$stem.so missing lean_sbf_find_program_address\n$syms"
  echo "$syms" | grep -q ' sol_try_find_program_address$' \
    || fail "$stem.so missing sol_try_find_program_address syscall\n$syms"
  echo "OK: $stem.so retains the PDA runtime + syscall references"
}
check_pda_program

# AddressBook is a non-toy program touching the typed entrypoint,
# msg! logging, ByteArray, and PDA derivation in one piece of code.
# Structural test asserts the .so retains every runtime helper it touches.
check_addressbook_program() {
  local src=AddressBook.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  for needle in lean_sol_log lean_sbf_find_program_address sol_try_find_program_address; do
    echo "$syms" | grep -q " $needle\$" \
      || fail "$stem.so missing required symbol: $needle\n$syms"
  done
  echo "OK: $stem.so retains all required runtime + syscall references"
}
check_addressbook_program

# Counter is a state-changing program that reads a counter from
# accounts[0].data, adds an increment from instruction data, and writes
# the result back. Structural test asserts the .so retains the mutator
# runtime helpers - proves the mutable-account-state pipeline links cleanly.
check_counter_program() {
  local src=Counter.lean
  local stem="${src%.lean}"
  cp "$SRCDIR/$src" .
  run lean --target=sbf-solana-solana --bc="$stem.bc" "$src"
  leanc_check_stack "$stem" --target=sbf-solana-solana "$stem.bc" -o "$stem.so"
  local syms; syms=$("$READELF" --dyn-syms "$stem.so")
  for needle in lean_sbf_read_data lean_sbf_write_data lean_sol_log; do
    echo "$syms" | grep -q " $needle\$" \
      || fail "$stem.so missing required mutator symbol: $needle\n$syms"
  done
  echo "OK: $stem.so retains the mutable-account-state runtime helpers"
}
check_counter_program

# Negative test. Denied.lean references IO.FS.readFile, which is on the
# SBF deny-list, so `lean --target=sbf-solana-solana` must REJECT it at
# emit time with a diagnostic naming the offending decl. We exercise the
# raw lean invocation here (not check_program, which expects success).
check_denied() {
  local src="$1"
  local needle="$2"
  cp "$SRCDIR/$src" .
  local stderr_file="$WORK/${src%.lean}.stderr"
  if lean --target=sbf-solana-solana --bc=/tmp/should-not-be-produced.bc "$src" 2>"$stderr_file"; then
    fail "lean --target=sbf-solana-solana accepted $src despite deny-listed reference"
  fi
  grep -q "$needle" "$stderr_file" \
    || fail "expected '$needle' in lean error, got:\n$(cat "$stderr_file")"
  echo "OK: $src correctly rejected at lean --target=sbf-solana-solana time"
}
check_denied Denied.lean       "not supported on the sbf-solana-solana target"
