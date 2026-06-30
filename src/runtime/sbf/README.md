# Lean SBF / Solana runtime adapter

This directory holds the permanent runtime support for `lean --target=sbf-solana-solana`
cross-compile builds. The files here are installed alongside the toolchain
(into `lib/lean/sbf/`) and compiled on demand by `leanc` when it sees an
SBF triple, using the platform-tools clang from
[anza-xyz/platform-tools](https://github.com/anza-xyz/platform-tools).

## Files

- `entrypoint.c` — the Solana program ABI adapter. Implements the loader-facing
  `entrypoint(const uint8_t *) -> uint64_t`, parses the input, and calls a
  Lean-defined function exported as
  `lean_sol_entry_typed(ProgramContext) -> UInt64` or
  `lean_sol_entry_status(ProgramContext) -> UInt64`. The leanc-generated glue
  parses the loader's input buffer into a `Std.Solana.ProgramContext` (account
  table, instruction data, program id) before invoking the Lean entry. Legacy
  `lean_sol_entry_typed` returns are logged as values and report Solana success;
  `lean_sol_entry_status` returns are propagated as the loader status code.

- `stubs.c` — the manifest of Lean runtime symbols referenced by code emitted
  for SBF, with trivial inline arithmetic helpers as real implementations and
  the rest as `__builtin_trap()` stubs that log a marker before aborting.

  To support a new Lean runtime feature on Solana:

  1. Identify which `LEAN_SBF_TRAP` entry blocks the feature (run the SBF
     program, observe the `lean-sbf: unsupported Lean runtime symbol: …`
     log line).
  2. Replace that stub with a real implementation.
  3. Update the SBF golden test in `tests/compiler/solana/`.

## Building Lean with SBF support

The SBF cross-compile path requires a Lean built with `-DLLVM=ON`. Use the
`release-with-llvm` CMake preset:

```bash
cmake --preset release-with-llvm    # adds -DLLVM=ON to release defaults
make -j$(nproc) -C build/release-with-llvm
```

Lean's LLVM backend bindings require `llvm-config` from LLVM 19 specifically
(stage0's bitcode reader cannot decode bitcode produced by Apple Clang 21+,
which adds attribute kinds the LLVM 19 reader doesn't know). On macOS:

```bash
brew install llvm@19
cmake --preset release-with-llvm \
  -DLLVM_CONFIG=/opt/homebrew/opt/llvm@19/bin/llvm-config \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm@19/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm@19/bin/clang++ \
  -DGIT_EXECUTABLE=/usr/bin/git
make -j$(sysctl -n hw.logicalcpu) -C build/release-with-llvm
```

(`-DGIT_EXECUTABLE=/usr/bin/git` works around a CMake 4.x quirk where
`ExternalProject_Add` fails to pick up the Apple-bundled git's version.)

The SBF runtime adapter sources here are staged into the build's
`lib/lean/sbf/` regardless of `-DLLVM`; they are inert C source files until
`leanc --target=sbf-*` calls into them at SBF link time.

## Out-of-scope here

- Compute-budget accounting, syscall wrappers beyond `sol_log_*`, account
  data parsing helpers — these belong in `Std.Solana`, not in the runtime
  adapter.
