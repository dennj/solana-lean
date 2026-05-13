# Lean 4 → Solana

**Submission to the [Colosseum Solana Hackathon](https://arena.colosseum.org/projects/explore/latinum)** by [Latinum](https://latinum.ai/).

This is a fork of [Lean 4](https://lean-lang.org/) that turns it into a cross-compiler for Solana. You write a Solana program in Lean 4, prove properties about it with Lean's theorem prover, and the same source elaborates to a Solana SBF `.so` deployable to mainnet — no Rust in the loop.

| | |
|---|---|
| Business pitch | <https://youtu.be/MCIl858wQUE> |
| Tech demo      | <https://youtu.be/4HrUTtvsRHo> |
| Hackathon page | <https://arena.colosseum.org/projects/explore/latinum> |
| Company        | <https://latinum.ai/> |

---

## Showcases

Two end-to-end demos built on top of the cross-compile backend, both in this repo:

### 🏛️ Colosseum vault — a proof-carrying Solana program

[Colosseum/Colosseum.lean](Colosseum/Colosseum.lean) — the headline submission. A deposit/withdraw vault whose **safety theorems are part of the source file**, proven by Lean's kernel and re-checked on every `lake build`.

The safety invariant is one line:

```lean
def Vault.ok (v : Vault) : Bool :=
  v.balance.toNat + v.totalOut.toNat == v.totalIn.toNat
```

*"The vault never owes more than it took in."*

The theorems sitting next to the program code are **universally quantified** — they hold for every starting state, every amount, every account:

```lean
theorem withdraw_preserves_ok
    (v : Vault) (amount : UInt64)
    (h_ok  : v.ok = true)
    (h_pre : amount ≤ v.balance)
    (h_out : v.totalOut.toNat + amount.toNat < UInt64.size) :
    (v.withdraw amount).ok = true := by
  have h_pre_nat : amount.toNat ≤ v.balance.toNat := UInt64.le_iff_toNat_le.mp h_pre
  simp only [Vault.ok, Vault.withdraw, UInt64.toNat_add, beq_iff_eq] at *
  rw [UInt64.toNat_sub_of_le _ _ h_pre, Nat.mod_eq_of_lt h_out]
  omega
```

The hypotheses are real: `h_pre` rules out underflow (you can't withdraw more than the balance), `h_out` rules out `UInt64` overflow on `totalOut`. A companion `deposit_preserves_ok` proves the same for deposits.

**Delete the `balance := v.balance - amount` line in `Vault.withdraw`** — the canonical "balance leak" exploit — and `withdraw_preserves_ok` becomes unprovable. The file fails to elaborate. `lake build` refuses to emit a `.so`. **The bug cannot ship.** Same source, same compile pass, no separate audit step.

One command does the whole devnet round-trip:

```bash
cd Colosseum
./demo.sh
```

`demo.sh` runs `lake build` (proofs check, `.so` is emitted), `solana program deploy`, then a `bun demo.ts` client that submits a deposit and a withdraw, printing Solana Explorer URLs for every transaction. See the [tech demo video](https://youtu.be/4HrUTtvsRHo) for the live run.

### ⚙️ RISC-V64 kernel that boots under QEMU

[tests/kernel_riscv64/](tests/kernel_riscv64/) — a full bare-metal kernel built from Lean source through the same cross-compile pipeline. ~3500 lines of Lean covering:

- [Kernel/Core.lean](tests/kernel_riscv64/Kernel/Core.lean) — scheduler, trap handler, syscall dispatch (2872 lines)
- [Kernel/Memory.lean](tests/kernel_riscv64/Kernel/Memory.lean) — frame allocator
- [Kernel/Sv39.lean](tests/kernel_riscv64/Kernel/Sv39.lean) — Sv39 paging
- [Kernel/Hardware.lean](tests/kernel_riscv64/Kernel/Hardware.lean) — UART, CLINT, SATP, SFENCE
- [Main.lean](tests/kernel_riscv64/Main.lean), [boot.S](tests/kernel_riscv64/boot.S), [kernel.c](tests/kernel_riscv64/kernel.c), [kernel.ld](tests/kernel_riscv64/kernel.ld) — entry, trap vector, linker script

The kernel reasons in Lean about its own actions (`Kernel.step`, `Kernel.trapStep?`) and emits each step as a tagged `Action` the C glue executes. Every syscall trap logs a `"Lean theorem: …"` proof obligation as it runs, so the QEMU serial output reads as the kernel justifying itself live.

One command boots it:

```bash
cd tests/kernel_riscv64
./demo.sh          # cross-compiles → links → boots in qemu-system-riscv64
```

This is the stress test that proves the freestanding runtime is real — no stdlib, no allocator, no host syscalls, just bitcode + a linker script + a serial port.

---

## Why

Solana programs hold real money and run inside a strict sandbox. Today they are written in Rust, where correctness lives in tests and audits. Lean 4 is one of the few production-grade languages where you can write a program *and a machine-checked proof about it* in the same file. The proof, the spec, and the deployed bytecode are all derived from the same source — there is no gap to bridge by hand.

This work makes that pipeline real:

```
   Foo.lean  ──►  lean --target=sbf-solana-solana  ──►  Foo.bc
                          │                                │
                          ▼                                ▼
                  proofs checked by                leanc --target=…
                    Lean's kernel                          │
                                                           ▼
                                                        Foo.so  ──►  solana program deploy
```

## What I built

A complete cross-compilation backend in the Lean 4 compiler, three runtime adapters, a Solana SDK in Lean, and the Lake build integration to drive it.

### 1. Triple-aware LLVM backend

The Lean LLVM backend was host-only — it hardcoded `i64` for `size_t`, never stamped a data layout, and exposed every internal symbol. I rewrote it to be target-driven:

- New compiler options `compiler.target`, `compiler.runtime`, `compiler.crossImports` ([src/Lean/Compiler/Options.lean](src/Lean/Compiler/Options.lean))
- `--target=<triple>` flag end-to-end through `lean` and `leanc` ([src/Lean/Shell.lean](src/Lean/Shell.lean), [src/Leanc.lean](src/Leanc.lean))
- Canonical LLVM data layouts pre-extracted for `sbf-solana-solana`, `wasm32-*`, `riscv64-unknown-none` ([src/Lean/Compiler/IR/EmitLLVM.lean](src/Lean/Compiler/IR/EmitLLVM.lean#L52-L73)). The host's LLVM doesn't know these triples, so we ship the layouts.
- `size_t` / `usize` / `unsigned` types now plumbed through the emitter context — wasm32 gets `i32`, SBF gets `i64`, host stays as-is.
- Zero-arg decls compile to `_init_<name>()` calls instead of writable globals on cross targets — Solana's BPF loader rejects writable segments.
- Symbol visibility tightened: only `@[export]`-annotated decls reach `.dynsym`.

### 2. Compile-time deny list

A Solana program that calls `IO.FS.readFile` is a link-time disaster waiting to happen. New machinery surfaces those errors at *compile* time with the right source location:

- `register_unsupported_on_target <decl> <triple-glob> <reason>` command ([src/Lean/Compiler/UnsupportedOnTargetCmd.lean](src/Lean/Compiler/UnsupportedOnTargetCmd.lean))
- Persistent env extension stores the deny list across modules ([src/Lean/Compiler/UnsupportedOnTarget.lean](src/Lean/Compiler/UnsupportedOnTarget.lean))
- Reachability check intersects the deny list with `collectUsedDecls`, then walks IR with new `collectDirectCallersOf` ([src/Lean/Compiler/IR/EmitUtil.lean](src/Lean/Compiler/IR/EmitUtil.lean)) to print the user-side callers with file:line ([src/Lean/Compiler/IR/EmitLLVM.lean — `checkUnsupportedOnTarget`](src/Lean/Compiler/IR/EmitLLVM.lean))
- Default deny list for every cross target — filesystem, processes, real-time clock, env, threads, stdin — in [src/Std/Freestanding/Unsupported.lean](src/Std/Freestanding/Unsupported.lean), auto-imported through `compiler.crossImports`.

### 3. `@[never_extract]` survives DCE

The Solana log syscall is *only* useful for its side effect. The LCNF pure-mode passes happily deleted it. Fixed in [src/Lean/Compiler/LCNF/ElimDead.lean](src/Lean/Compiler/LCNF/ElimDead.lean) and [src/Lean/Compiler/LCNF/Simp/Main.lean](src/Lean/Compiler/LCNF/Simp/Main.lean): `@[never_extract]`-tagged calls are pinned through both dead-let elimination passes.

### 4. Freestanding Lean runtime

A libc-free, host-runtime-free runtime that every cross target shares ([src/runtime/freestanding/](src/runtime/freestanding/)):

- Bump allocator (refcount no-ops, since the program runs once and exits)
- Boxing, ctor alloc/accessors, IO-result wrappers
- Strings, arrays, scalar arrays
- Closure machinery for arities 1–8
- Small-Nat / Int subset capped at `(uintptr_t)-1 >> 1`
- **ABI mirrors host `lean.h` exactly** — silent miscompute lurks here if it drifts

Per-target adapters layer on top:

| Adapter | Entry point / loader contract |
|---|---|
| [src/runtime/sbf/](src/runtime/sbf/)  | `entrypoint(const uint8_t *) -> uint64_t` parses the loader buffer into a `Std.Solana.ProgramContext` and calls `lean_sol_entry_typed` |
| [src/runtime/wasm/](src/runtime/wasm/) | `_start` over WASI imports (`fd_write`, `proc_exit`) |
| [src/runtime/freestanding/](src/runtime/freestanding/) | bare-metal; embedder provides `lean_freestanding_log` and `lean_freestanding_panic` |

Each adapter ships a `stubs.c` listing every host-runtime symbol it cannot provide. Calls to those symbols fall through `__builtin_trap()` after logging a `lean-<target>: unsupported Lean runtime symbol: <name>` line, so omissions fail loudly with grep-able output.

### 5. `Std.Solana` — the Solana SDK in Lean

A user-facing Solana programming surface in [src/Std/Solana.lean](src/Std/Solana.lean) (~2400 lines). Highlights:

- `Pubkey` as a length-refined `ByteArray` (`size_eq : bytes.size = 32`) — the proof obligation prevents constructing an invalid key
- `AccountInfo`, `ProgramContext`, `Instruction` mirroring the SBF ABI
- `@[solana_entrypoint]` attribute shorthand that exports `lean_sol_entry_typed`
- `msg` / `msg!` logging via `sol_log_` syscall
- PDA derivation, CPI invocation helpers

A user program is just:

```lean
import Std.Solana
open Std.Solana

@[solana_entrypoint]
def entry (ctx : ProgramContext) : UInt64 :=
  msg! s!"hello from lean: {ctx.accounts.size} accounts"
  0
```

### 6. Lake integration

Three new build kinds — `solana_program`, `wasm_program`, `freestanding_program` — all thin wrappers over a shared `CrossProgram` pipeline in [src/lake/Lake/Build/CrossProgram.lean](src/lake/Lake/Build/CrossProgram.lean) so the cross-build logic lives in one place. `lake init … solana` scaffolds a deployable Solana program.

```toml
# lakefile.toml
[[solana_program]]
name = "my_program"
```

```
$ lake build
$ solana program deploy build/bin/my_program.so
```

### 7. Tests

- [tests/stdlib_probes/](tests/stdlib_probes/) — ~50 probes (one per stdlib feature: arrays, strings, Nat overflow, monads, well-founded recursion, structures, …) that run identically on host, SBF, and wasm to catch ABI drift before it ships.
- [tests/solana/](tests/solana/) — Counter, AddressBook, PDA, CPI shape, Borsh round-trip — plus the Colosseum vault — with a deploy harness + TS client (`run_test.sh`, `deploy_client.ts`).
- [tests/wasm/](tests/wasm/) — WASI execution via Node / wasmtime.
- [tests/cross_target/](tests/cross_target/) — golden tests for the diagnostic output of the deny list.
- [.github/workflows/cross-compile.yml](.github/workflows/cross-compile.yml) — CI matrix exercising every target on every PR.

---

## Try it

Build a Lean toolchain with the LLVM backend turned on:

```bash
cmake --preset release-with-llvm
make -j$(sysctl -n hw.logicalcpu) -C build/release-with-llvm   # use $(nproc) on Linux
```

Then run either showcase:

```bash
# Colosseum vault: build → deploy to devnet → deposit → withdraw
cd Colosseum && ./demo.sh

# RISC-V kernel boots in QEMU (Ctrl-A then X to exit)
cd tests/kernel_riscv64 && ./demo.sh
```

---

## Repo layout

```
src/
  Lean/Compiler/
    Options.lean                  ← target/runtime/crossImports options
    UnsupportedOnTarget.lean      ← deny-list machinery
    UnsupportedOnTargetCmd.lean   ← `register_unsupported_on_target`
    IR/EmitLLVM.lean              ← triple-aware codegen
  Leanc/CrossTarget/
    SBF.lean                      ← Solana driver
    Wasm.lean                     ← WebAssembly driver
    RiscV64Freestanding.lean      ← bare-metal RISC-V driver
  Std/
    Solana.lean                   ← user-facing Solana SDK
    Wasm.lean                     ← WASI surface
    Freestanding/Unsupported.lean ← deny list
  runtime/
    freestanding/                 ← shared libc-free runtime
    sbf/                          ← Solana adapter + entrypoint
    wasm/                         ← WASI adapter + entrypoint
  lake/Lake/Build/
    CrossProgram.lean             ← shared cross-build pipeline
    SolanaProgram.lean
    WasmProgram.lean
    FreestandingProgram.lean
Colosseum/                        ← 🏛️ headline showcase: vault + proofs + devnet demo
tests/
  stdlib_probes/                  ← cross-target conformance suite
  solana/                         ← deployable program tests + TS client
  wasm/                           ← WASI tests
  kernel_riscv64/                 ← ⚙️ bare-metal RISC-V kernel demo
```

---

## License

Apache 2.0, same as upstream Lean 4. See [LICENSE](LICENSE).
