# packaging/

Distribution tooling for **Latinum** — installing the Lean → Solana SBF
toolchain without the ~1-hour from-source compile.

| File | What it is |
|------|------------|
| `homebrew/latinum.rb` | Homebrew formula. Installs a prebuilt toolchain + bundles the SBF linker. |
| `install.sh` | Standalone installer (no Homebrew tap needed). Downloads/unpacks the prebuilt toolchain and builds the example. |
| `RELEASING.md` | Maintainer runbook for cutting a new version. |

## Install (Homebrew)

Apple Silicon, macOS 13+:

```bash
brew install MohammedImaad/latinum/latinum   # current host of the v0.1 release
lean --version
```

> The formula currently points at a release hosted on
> `github.com/MohammedImaad/latinum`. To move hosting onto this repo, cut a
> release here and update `url` + `sha256` in `homebrew/latinum.rb` — see
> `RELEASING.md`.

## Install (standalone script)

```bash
./install.sh            # toolchain + builds the Colosseum vault
./install.sh --deploy   # also deploys to devnet + runs deposit/withdraw
```

## Then build a contract

```bash
cd ../Colosseum
lake build              # checks the Lean proofs → emits the Solana .so
```

## Scope

Prebuilt toolchain is **Apple Silicon / macOS 13+** only. Intel Macs and older
macOS need a from-source build (see the repo root).
