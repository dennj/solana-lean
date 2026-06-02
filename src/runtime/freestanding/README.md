# Lean freestanding runtime

This directory holds the libc-free, host-runtime-free subset of the Lean
runtime that is shared across every freestanding cross-compile target
(SBF, WebAssembly, RISC-V kernel, embedded MCU, etc.). The files here are
installed alongside the toolchain (into `lib/lean/freestanding/`) and
compiled on demand by `leanc` whenever a target driver under
`src/Leanc/CrossTarget/<Target>.lean` selects them.

## Files

- `runtime.c` — the runtime itself: freestanding reclaiming heap
  allocator, single-threaded reference-count metadata, boxing
  primitives, ctor allocation/accessors including reset/reuse release
  support, IO-result wrappers, strings, arrays, scalar arrays,
  pointer-address and mix-hash helpers, single-threaded `ST.Ref` cells,
  closure machinery (`lean_apply_1`..`16` plus `lean_apply_n`/`m`),
  and bounded small-Nat/small-Int arithmetic. Freestanding Nat is capped
  at `(uintptr_t)-1 >> 1`; freestanding Int uses the scalar small-Int
  range and traps when an operation would require an MPZ-backed value.
  The LLVM freestanding backend rejects executable Nat literals above
  the active target cap before emitting bitcode; runtime
  conversion/arithmetic checks trap dynamic overflow.

- `lean_freestanding.h` — the public header. Declares the `lean_object`
  layout (which must match the inline `lean.h` ABI exactly) plus the two
  embedder-provided externs `lean_freestanding_log` and
  `lean_freestanding_panic`.

- `AUDIT.md` — ABI and ownership audit against host `lean.h`,
  `object.cpp`, and `apply.cpp`, including target-policy coverage for runtime
  families that are intentionally not implemented here.

- `CMakeLists.txt` — installs the sources into `lib/lean/freestanding/`.

## Memory model

The freestanding runtime uses one Lean-style memory policy: deterministic
single-threaded reference counting plus a small reclaiming allocator over
the embedder-provided heap. It does not call libc `malloc`/`free`, but it
does return dead Lean objects to its own heap when `m_rc` reaches zero.

This preserves the host invariants that generated code depends on:

1. **Exclusivity** — `lean_is_exclusive(o)` is true iff `o` is a live
   heap object with `m_rc == 1`. The compiler emits this check before
   mutating in place; the freestanding runtime must answer it
   truthfully so that copy-on-write fires when an aliased value is
   updated.
2. **Persistence** — objects with `m_rc == 0` are persistent; they are
   never considered exclusive and are skipped by `inc`/`dec`.
   `lean_mark_persistent` walks an object graph and zeroes the count.
3. **Reclamation** — when a non-persistent object's RC reaches zero, the
   runtime recursively releases owned Lean object fields, then frees the
   object's heap block for reuse by later allocations.
4. **Constructor reset/reuse** — generated reset code may release individual
   constructor fields before reusing or deleting the old cell.
   `lean_ctor_release` therefore decrements the field and clears the slot to
   `lean_box(0)`, matching host `lean.h` and preventing stale fields from being
   decremented again on fallback paths.

Array and scalar-array updates (`lean_array_push`, `lean_array_uset`,
`lean_byte_array_push`, `lean_byte_array_uset`, `swap`, `pop`, ...)
follow host copy-on-write structure: mutate in place when exclusive,
otherwise allocate a copy first. Without this discipline, programs
that use arrays non-linearly (`let a := ...; let b := a.push x; ...a...`)
would observe mutations through the old alias — a semantic miscompile.

The allocator stores block metadata inside the supplied heap and scans
for reusable free blocks before extending the high-water cursor. Freeing
coalesces adjacent free blocks. Embedders may still reset or replace the
whole heap between invocations, but that is startup policy, not an
alternative memory model.

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

Two layers of test:

1. **Host-side differential harness** under `tests/freestanding_runtime/`.
   Compiles this directory as a plain host library and links a C driver
   that exercises copy-on-write and reclamation invariants directly — no
   Lean compiler, no cross-target backend required. Run via `ctest -R
   '^freestanding_runtime$'`. Catches regressions in the RC,
   exclusivity, and allocator contract regardless of whether any target
   backend is present.

2. **Downstream target probes**. Each concrete target repo (SBF,
   WebAssembly, RISC-V kernel, ...) is expected to compile and run the
   stdlib probe corpus end-to-end against its own toolchain. A new
   target should match host behaviour bit-for-bit or surface a
   specific gap.

## Out-of-scope here

- Per-target syscalls — they belong under `src/runtime/<target>/`.
- The host's task manager, full panic-message formatting, GMP/MPZ-backed
  large Nat/Int arithmetic, full Float arithmetic/string-conversion
  runtime, and threading runtime — none of these are part of the
  freestanding subset; consumers requiring them should link against the
  full host runtime instead. The freestanding runtime does provide
  FloatArray storage helpers so the scalar-array ABI remains coherent.
