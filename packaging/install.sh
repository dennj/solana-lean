#!/usr/bin/env bash
#
# Latinum-Lean — one-step installer (Apple Silicon, macOS 13+)
#
# Installs a PREBUILT Lean -> Solana-SBF toolchain (skips the ~1-hour compile),
# fetches the SBF linker (Solana platform-tools v1.41), wires up PATH, and
# builds the formally-verified Colosseum vault to prove it all works.
#
#   ./install.sh            # install toolchain + build the vault (.so)
#   ./install.sh --deploy   # also deploy to devnet + run deposit/withdraw
#
# Override the install location with LATINUM_HOME=/path ./install.sh
# Override the toolchain download with LATINUM_TARBALL_URL=https://... ./install.sh

set -euo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${LATINUM_HOME:-$HOME/.latinum}"
TOOLCHAIN_DIR="$INSTALL_DIR/lean"

TARBALL_NAME="latinum-lean-arm64-macos.tar.gz"
LOCAL_TARBALL="$SCRIPT_DIR/$TARBALL_NAME"
# Default download if no local tarball is present and LATINUM_TARBALL_URL is unset.
DEFAULT_TARBALL_URL="https://github.com/MohammedImaad/latinum/releases/download/v0.1/${TARBALL_NAME}"

PT_VERSION="v1.41"
PT_TARBALL="platform-tools-osx-aarch64.tar.bz2"
PT_URL="https://github.com/anza-xyz/platform-tools/releases/download/${PT_VERSION}/${PT_TARBALL}"
PT_DEST="$HOME/.cache/solana/${PT_VERSION}/platform-tools"

# The Colosseum demo project — next to this script (dist/) or at the repo root
# (packaging/../Colosseum), whichever exists.
if [ -d "$SCRIPT_DIR/Colosseum" ]; then
  COLOSSEUM_SRC="$SCRIPT_DIR/Colosseum"
else
  COLOSSEUM_SRC="$SCRIPT_DIR/../Colosseum"
fi

DEPLOY=0
[ "${1:-}" = "--deploy" ] && DEPLOY=1

# ----------------------------------------------------------------------------
# Pretty output
# ----------------------------------------------------------------------------
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
die()   { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# 1. Platform guards
# ----------------------------------------------------------------------------
cyan "1/6  Checking platform"

[ "$(uname -s)" = "Darwin" ] || die "this installer is macOS-only (got $(uname -s))."

ARCH="$(uname -m)"
[ "$ARCH" = "arm64" ] || die "this build is Apple-Silicon (arm64) only; got '$ARCH'.
  Intel Macs need a separate build — see dist/README.md."

OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$OS_MAJOR" -ge 13 ] || die "macOS 13 or newer required (got $(sw_vers -productVersion))."

green "  macOS $(sw_vers -productVersion), arm64 — OK"

# ----------------------------------------------------------------------------
# 2. Homebrew runtime dylib deps (the binary links these at fixed paths)
# ----------------------------------------------------------------------------
cyan "2/6  Installing runtime libraries (gmp, libuv, openssl@3)"

command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install it first:
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

for pkg in gmp libuv openssl@3; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    green "  $pkg already installed"
  else
    yellow "  installing $pkg ..."
    brew install "$pkg"
  fi
done

# ----------------------------------------------------------------------------
# 3. Toolchain (prebuilt) — local tarball if present, else download
# ----------------------------------------------------------------------------
cyan "3/6  Installing Lean -> SBF toolchain"

mkdir -p "$INSTALL_DIR"
rm -rf "$TOOLCHAIN_DIR"

TARBALL=""
if [ -f "$LOCAL_TARBALL" ]; then
  green "  using bundled $TARBALL_NAME"
  TARBALL="$LOCAL_TARBALL"
else
  URL="${LATINUM_TARBALL_URL:-$DEFAULT_TARBALL_URL}"
  yellow "  downloading toolchain from $URL ..."
  TARBALL="$INSTALL_DIR/$TARBALL_NAME"
  curl -fL --progress-bar "$URL" -o "$TARBALL"
fi

yellow "  extracting (~2.3 GB) ..."
tar xzf "$TARBALL" -C "$INSTALL_DIR"
# The tarball unpacks to 'latinum-lean/'; normalize to "$TOOLCHAIN_DIR".
mv "$INSTALL_DIR/latinum-lean" "$TOOLCHAIN_DIR"
xattr -dr com.apple.quarantine "$TOOLCHAIN_DIR" 2>/dev/null || true

[ -x "$TOOLCHAIN_DIR/bin/lean" ] || die "toolchain missing after extract ($TOOLCHAIN_DIR/bin/lean)"

# ----------------------------------------------------------------------------
# 4. SBF linker — Solana platform-tools v1.41 (auto-discovered by the backend)
# ----------------------------------------------------------------------------
cyan "4/6  Installing SBF linker (platform-tools ${PT_VERSION})"

if [ -d "$PT_DEST/llvm/bin" ]; then
  green "  platform-tools ${PT_VERSION} already present"
else
  mkdir -p "$(dirname "$PT_DEST")"
  TMP_PT="$(mktemp -d)"
  yellow "  downloading platform-tools ${PT_VERSION} (~250 MB) ..."
  curl -fL --progress-bar "$PT_URL" -o "$TMP_PT/$PT_TARBALL"
  yellow "  extracting ..."
  mkdir -p "$PT_DEST"
  tar xjf "$TMP_PT/$PT_TARBALL" -C "$PT_DEST"
  xattr -dr com.apple.quarantine "$PT_DEST" 2>/dev/null || true
  rm -rf "$TMP_PT"
fi

[ -x "$PT_DEST/llvm/bin/llc" ] || die "platform-tools missing llc after extract"

# ----------------------------------------------------------------------------
# 5. PATH wiring (current session + shell profile)
# ----------------------------------------------------------------------------
cyan "5/6  Wiring PATH"

export PATH="$TOOLCHAIN_DIR/bin:$PATH"

PROFILE=""
case "${SHELL##*/}" in
  zsh)  PROFILE="$HOME/.zshrc" ;;
  bash) PROFILE="$HOME/.bash_profile" ;;
  *)    PROFILE="$HOME/.profile" ;;
esac

LINE="export PATH=\"$TOOLCHAIN_DIR/bin:\$PATH\"  # latinum-lean"
if [ -n "$PROFILE" ] && ! grep -qF "# latinum-lean" "$PROFILE" 2>/dev/null; then
  printf '\n%s\n' "$LINE" >> "$PROFILE"
  green "  added toolchain to $PROFILE"
else
  green "  PATH already configured (or no profile) — set for this session"
fi

bold "  $(lean --version)"

# ----------------------------------------------------------------------------
# 6. Build the formally-verified vault (proof of life)
# ----------------------------------------------------------------------------
cyan "6/6  Building the Colosseum vault (re-checks the Lean proofs)"

[ -d "$COLOSSEUM_SRC" ] || die "Colosseum demo not found next to installer ($COLOSSEUM_SRC)"

BUILD_DIR="$INSTALL_DIR/Colosseum"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
# Copy sources only — skip any stale .lake build cache / node_modules.
( cd "$COLOSSEUM_SRC" && \
  find . -maxdepth 1 ! -name . ! -name .lake ! -name node_modules \
    -exec cp -R {} "$BUILD_DIR/" \; )

( cd "$BUILD_DIR" && lake build )

SO="$BUILD_DIR/.lake/build/solana/Colosseum.so"
[ -f "$SO" ] || die "build did not produce $SO"

green ""
green "Success — formally-verified vault compiled to Solana SBF:"
green "  $SO"
file "$SO" | sed 's/^/  /'

# ----------------------------------------------------------------------------
# Optional: deploy to devnet + run the demo
# ----------------------------------------------------------------------------
if [ "$DEPLOY" -eq 1 ]; then
  cyan "Deploying to devnet + running deposit/withdraw"
  command -v solana >/dev/null 2>&1 || die "solana CLI not found on PATH.
  Install: sh -c \"\$(curl -sSfL https://release.anza.xyz/stable/install)\""
  command -v bun >/dev/null 2>&1 || die "bun not found on PATH. Install: curl -fsSL https://bun.sh/install | bash"
  ( cd "$BUILD_DIR" && bun install && ./demo.sh )
else
  bold ""
  bold "Next steps (deploy + run on devnet):"
  echo "  cd $BUILD_DIR"
  echo "  bun install"
  echo "  ./demo.sh            # build + deploy + deposit(100) + withdraw(30)"
  echo ""
  echo "Or re-run this installer with --deploy to do it automatically."
  echo "Open a new terminal (or 'source $PROFILE') so 'lean'/'lake' are on PATH."
fi
