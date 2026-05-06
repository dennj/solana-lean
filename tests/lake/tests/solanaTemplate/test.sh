#!/usr/bin/env bash
source ../common.sh

./clean.sh

# Ensure that Lake is run without a toolchain name.
export ELAN_TOOLCHAIN=

echo "# Check if LLVM enabled"
if [[ ! $($LAKE env lean --features) =~ LLVM ]]; then
  echo "Skipping test: 'lean' does not have LLVM backend enabled"
  exit 0
fi

PT_PROBE=
if [[ -n "${LEAN_SOLANA_TOOLS:-}" ]]; then
  PT_PROBE="$LEAN_SOLANA_TOOLS"
elif compgen -G "$HOME/.cache/solana/v*/platform-tools" > /dev/null; then
  PT_PROBE=$(ls -d "$HOME/.cache/solana/"v*/platform-tools 2>/dev/null | tail -n1)
fi
if [[ -z "$PT_PROBE" || ! -d "$PT_PROBE" ]]; then
  echo "Skipping test: platform-tools not found"
  exit 0
fi

READELF="$PT_PROBE/llvm/bin/llvm-readelf"
test -x "$READELF"

echo "# TEST: solana template"
test_run new m8template solana
test -f m8template/lakefile.lean
test ! -f m8template/build-solana.sh
match_text "target solana" m8template/lakefile.lean
match_text "lake build solana" m8template/README.md

test_run -d m8template build solana
test -f m8template/.lake/build/solana/m8template.so
"$READELF" -h m8template/.lake/build/solana/m8template.so > produced.elf
match_text "Type:                              DYN" produced.elf
match_text "Machine:                           EM_BPF" produced.elf

./clean.sh
