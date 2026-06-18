# Lean WebAssembly runtime adapter

This directory holds the runtime support for `lean
--target=wasm32-wasip1` cross-compile builds. The files here are
installed into `lib/lean/wasm/` and compiled on demand by `leanc` when it
sees a `wasm32-*` triple, using the system clang plus a `wasm-ld` taken
from any available LLVM 18+ toolchain (Homebrew, system, or the Anza
platform-tools fork).

## Files

- `entrypoint.c` — the WASI program ABI adapter. Implements `_start` and
  the export wrapper that calls a Lean-defined function exported as
  `lean_wasm_main(uint64_t) -> uint64_t` (or
  `lean_wasm_main_io : BaseIO UInt64`).

- `runtime.c` — embedder hooks: `lean_freestanding_log` / `_panic` over
  raw WASI imports (`fd_write` to stderr, `proc_exit`), plus
  `initialize_Std_Wasm` and `lean_wasm_log`.

- `stubs.c` — manifest of host-runtime symbols that wasm32 cannot
  provide; each is a `__builtin_trap` with a diagnostic so any program
  reaching one fails loudly.

  To support a new Lean runtime feature on wasm32:

  1. Identify which `LEAN_WASM_TRAP` entry blocks the feature (run the
     failing test and observe the `lean-wasm: unsupported Lean runtime symbol: …`
     diagnostic).
  2. Replace that stub with a real implementation, either here or as a
     shared piece of `runtime/freestanding/runtime.c`.
  3. Add a corresponding entry to `tests/stdlib_probes/` and confirm it
     passes on `wasm` as well as `host` and `sbf`.

## Heap layout

Wasm32 builds reserve an 8 MiB initial linear memory and give the
freestanding bump allocator a 4 MiB heap by default. The allocator is
configured by passing
`-DLEAN_FREESTANDING_HEAP_BASE=0x100000U
-DLEAN_FREESTANDING_HEAP_BYTES=4194304U
-DLEAN_FREESTANDING_HEAP_PREFIX=8U` from
`src/Leanc/CrossTarget/Wasm.lean`.

## Running a wasm32 build

```bash
lean  --target=wasm32-wasip1 --bc=Foo.bc Foo.lean
leanc --target=wasm32-wasip1 Foo.bc -o Foo.wasm
```

The result runs under any WASI host:

```bash
node --experimental-wasi-unstable-preview1 tests/wasm/run.mjs Foo.wasm
# or wasmtime / wasmer
```

Tests under `tests/wasm/` and the cross-target checks under
`tests/stdlib_probes/` exercise the wasm32 path automatically when Node
22+ is on the `PATH`.

## Out-of-scope here

- Browser DOM / fetch / WebGL bindings — this runtime targets WASI host
  embeddings (Node, wasmtime, wasmer, Spin, etc.), not the Web platform.
- Threads, atomics, SIMD — wasm32-wasip1 is single-threaded; SIMD/threads
  would require a different target triple and additional runtime work.
</content>
