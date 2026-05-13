#!/usr/bin/env bash
# One-shot demo: build, deploy, deposit, withdraw — print all Explorer URLs.
#
# Usage:
#   ./demo.sh              # fresh deploy (new program id)
#   PROGRAM_ID=<id> ./demo.sh   # reuse an already-deployed program

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# Make sure the local lake is on PATH (the patched one with [[solana_program]]).
export PATH="$(cd ../lean4/build/release/stage1/bin && pwd):$PATH"

CLUSTER=devnet

cyan()  { printf '\033[36m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

cyan "==> 1/4  lake build"
lake build | tail -3

if [[ -z "${PROGRAM_ID:-}" ]]; then
  cyan "==> 2/4  solana program deploy (fresh)"
  rm -f vault.json   # new program → new vault state account
  DEPLOY_OUT=$(solana program deploy .lake/build/solana/Colosseum.so)
  echo "$DEPLOY_OUT"
  PROGRAM_ID=$(echo "$DEPLOY_OUT" | awk '/Program Id:/ {print $3}')
  DEPLOY_SIG=$(echo "$DEPLOY_OUT" | awk '/Signature:/ {print $2}')
  green "  Program: https://explorer.solana.com/address/${PROGRAM_ID}?cluster=${CLUSTER}"
  green "  Deploy:  https://explorer.solana.com/tx/${DEPLOY_SIG}?cluster=${CLUSTER}"
else
  cyan "==> 2/4  reusing PROGRAM_ID=$PROGRAM_ID"
  green "  Program: https://explorer.solana.com/address/${PROGRAM_ID}?cluster=${CLUSTER}"
fi

cyan "==> 3/4  bun demo.ts deposit 100"
PROGRAM_ID=$PROGRAM_ID bun demo.ts deposit 100

cyan "==> 4/4  bun demo.ts withdraw 30"
PROGRAM_ID=$PROGRAM_ID bun demo.ts withdraw 30

green ""
green "Done. Open the Explorer URLs printed above to show transactions on screen."
