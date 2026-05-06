# Lean freestanding runtime

This directory holds the libc-free, host-runtime-free subset of the Lean
runtime that is shared across every freestanding cross-compile target
(SBF, WebAssembly, RISC-V kernel, embedded MCU, etc.). The files here are
installed alongside the toolchain (into `lib/lean/freestanding/`) and
compiled on demand by `leanc` whenever a target driver under
`src/Leanc/CrossTarget/<Target>.lean` selects them.

## Files

- `runtime.c` — the runtime itself: bump allocator, refcount no-ops,
  boxing primitives, ctor allocation/accessors, IO-result wrappers,
  strings, arrays, scalar arrays, closure machinery (arity 1..8), and a
  bounded small-Nat / Int subset capped at `(uintptr_t)-1 >> 1`.

- `lean_freestanding.h` — the public header. Declares the `lean_object`
  layout (which must match the inline `lean.h` ABI exactly) plus the two
  embedder-provided externs `lean_freestanding_log` and
  `lean_freestanding_panic`.

- `CMakeLists.txt` — installs the sources into `lib/lean/freestanding/`.

## How it composes with target adapters

Per-target embedder code lives one directory up under
`src/runtime/<target>/`. Each adapter:

1. Compiles `runtime.c` with three macros defining the heap layout
   (`LEAN_FREESTANDING_HEAP_BASE`, `_BYTES`, `_PREFIX`) — or
   `LEAN_FREESTANDING_HEAP_SYMBOLS` to use linker-defined
   `__lean_heap_start` / `__lean_heap_end`.
2. Implements `lean_freestanding_log(const char *, uint64_t)` and
   `lean_freestanding_panic(const char *, uint64_t, uint64_t)` against the
   target's I/O and abort facilities.
3. Provides any target-specific syscall wrappers in its own `runtime.c`
   (and a target-specific `entrypoint.c` if the target has a fixed
   loader-facing ABI).

## Adding a new freestanding target

1. Create `src/runtime/<target>/` with at minimum a `runtime.c` that
   defines `lean_freestanding_log` and `lean_freestanding_panic`, plus an
   `entrypoint.c` if the target loader expects a fixed entry symbol.
2. Add `src/Leanc/CrossTarget/<Target>.lean` registering the target's
   triple prefix, locating its toolchain, and invoking `clang
   --target=<triple>` with the required `-D` defines plus
   `freestanding/runtime.c`.
3. Append `<Target>.target` to `crossTargets` in `src/Leanc.lean`.
4. Add a CI matrix entry exercising `tests/<target>/run_test.sh`.

## Verifying the runtime

The probe corpus under `tests/stdlib_probes/` exercises every runtime
symbol against host, SBF, and WebAssembly. A new target should run the
same probes and either match host behaviour bit-for-bit or surface a
specific gap. See `tests/stdlib_probes/run_test.sh`.

## Out-of-scope here

- Per-target syscalls — they belong under `src/runtime/<target>/`.
- The host's task manager, panic-message handling, large-Nat arithmetic
  (GMP), Float, and threading runtime — none of these are part of the
  freestanding subset; consumers requiring them should link against the
  full host runtime instead.
</content>
