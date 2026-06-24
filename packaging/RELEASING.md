# Releasing a new Latinum version

This is the runbook for shipping a new prebuilt **Latinum** toolchain over
Homebrew, so users get `brew install <tap>/latinum` instead of a ~1-hour
from-source compile.

There are two moving parts:

1. **The toolchain tarball** — a prebuilt `lean`/`lake` + stdlib, attached as a
   GitHub **release asset**.
2. **The Homebrew formula** — `packaging/homebrew/latinum.rb`, which points at
   that asset by URL + `sha256` and bundles the SBF linker.

A release = build a new tarball, upload it, and bump three lines in the formula.

> **Scope:** the prebuilt is **Apple Silicon (arm64), macOS 13+** only. The
> binary is arm64 and links Homebrew dylibs at fixed paths. Intel / older macOS
> still need a from-source build.

---

## Prerequisites (one-time)

- A completed from-source build of this repo in `build/release-with-llvm`
  (see the root `README.md` / build docs). You need a working
  `build/release-with-llvm/stage1` to package from.
- Homebrew, with `gmp`, `libuv`, `openssl@3` installed.
- The Solana **platform-tools v1.41** linker available locally (the build/test
  step needs it): `~/.cache/solana/v1.41/platform-tools`.
- `gh` (GitHub CLI) authenticated with push access to the repos you publish to.

---

## 1. Build the distributable tree

`make install` emits a clean install tree (no build scratch) in seconds — it
does **not** recompile:

```bash
cd build/release-with-llvm/stage1
rm -rf /tmp/lean-dist
make install DESTDIR=/tmp/lean-dist        # ~8s, copies only
```

The toolchain lands at `/tmp/lean-dist/usr/local`.

## 2. Slim it down

Strip **only** IDE data (`*.ilean`) and host static libs (`*.a`). Everything
else is required by this fork's module system at compile time — do **not** strip
`*.olean.private`, `*.olean.server`, or `*.ir`, or `lake build` breaks.

```bash
rm -rf /tmp/latinum-lean
cp -R /tmp/lean-dist/usr/local /tmp/latinum-lean
cd /tmp/latinum-lean/lib/lean
find . \( -name "*.ilean" -o -name "*.a" \) -delete
```

This takes the tree from ~2.6 GB to ~2.3 GB.

## 3. Pack the tarball

The top-level dir inside the tarball **must** be `latinum-lean/` (the formula
and installer expect it):

```bash
cd /tmp
tar czf latinum-lean-arm64-macos.tar.gz latinum-lean
shasum -a 256 latinum-lean-arm64-macos.tar.gz   # <-- note this; it's TOOLCHAIN_SHA
```

Compressed size is ~657 MB.

## 4. Smoke-test the tarball before publishing

Extract to a throwaway location, put it on `PATH`, and build the example. This
catches a broken package before anyone downloads it:

```bash
rm -rf /tmp/tc && mkdir /tmp/tc && tar xzf /tmp/latinum-lean-arm64-macos.tar.gz -C /tmp/tc
rm -rf /tmp/vault && cp -R Colosseum /tmp/vault && cd /tmp/vault && rm -rf .lake node_modules
PATH="/tmp/tc/latinum-lean/bin:$PATH" lake build
file .lake/build/solana/*.so        # expect: ELF 64-bit ... eBPF
```

## 5. Publish the release asset

Pick the next version (e.g. `v0.2`) and upload:

```bash
gh release create v0.2 \
  /tmp/latinum-lean-arm64-macos.tar.gz \
  --repo <OWNER>/<REPO> \
  --title "Latinum v0.2 — prebuilt toolchain (arm64 macOS)" \
  --notes "Prebuilt Lean→Solana-SBF toolchain, Apple Silicon / macOS 13+."
```

Copy the resulting asset URL — it looks like:
`https://github.com/<OWNER>/<REPO>/releases/download/v0.2/latinum-lean-arm64-macos.tar.gz`

## 6. Bump the formula

Edit `packaging/homebrew/latinum.rb` and change **three** lines:

```ruby
url     "https://github.com/<OWNER>/<REPO>/releases/download/v0.2/latinum-lean-arm64-macos.tar.gz"
sha256  "<TOOLCHAIN_SHA from step 3>"
version "0.2"
```

The `platform-tools` resource only changes if you move to a newer
platform-tools — if so, update its `url` + `sha256` too (download the new
tarball and `shasum -a 256` it). Keep v1.41 for macOS 13 support: v1.53+ are
macOS-15 builds and crash on macOS 13.

## 7. Push the tap

The formula must live in a tap repo named `homebrew-<tap>` (the `homebrew-`
prefix is mandatory). Copy the updated formula there and push:

```bash
cp packaging/homebrew/latinum.rb <path-to>/homebrew-latinum/Formula/latinum.rb
cd <path-to>/homebrew-latinum
git commit -am "latinum 0.2" && git push
```

## 8. Verify the published install

```bash
brew update
brew uninstall latinum 2>/dev/null; brew untap <OWNER>/latinum 2>/dev/null
brew install <OWNER>/latinum/latinum
lean --version
brew test latinum
```

Then a real build:

```bash
cd Colosseum && lake build && file .lake/build/solana/*.so
```

---

## How the formula works (so you can debug it)

- The toolchain is installed into `libexec` (not `bin`) so the binaries'
  relative `@rpath` (`@executable_path/../lib`) keeps resolving.
- `platform-tools` (the SBF linker, ~932 MB) is **not** hosted by us — it's a
  Homebrew `resource` pulled straight from the `anza-xyz/platform-tools`
  release, then staged into `libexec/platform-tools`.
- `bin/` holds tiny **wrapper scripts** that `export
  LEAN_SOLANA_TOOLS=<libexec>/platform-tools` and then `exec` the real binary.
  The env var is inherited by `lake`'s child `lean`/`leanc` processes, so the
  whole SBF build finds the linker with zero post-install setup. The backend's
  discovery logic lives in `src/Leanc/CrossTarget/SBF.lean`.

## Checksums for the current (v0.1) release

| Artifact | sha256 |
|----------|--------|
| `latinum-lean-arm64-macos.tar.gz` | `75d7ed95aae972634ceeb2e587fa93033f70354999ab2ecc26d5ac3ea54a9c0e` |
| `platform-tools-osx-aarch64.tar.bz2` (v1.41) | `52e66ad46156933b5811b817c8d3b9bfce7ad388d35119b117dbfbcdc747a566` |
