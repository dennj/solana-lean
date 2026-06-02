# Freestanding Runtime ABI and Ownership Audit

Status date: 2026-05-23

This audit compares the freestanding runtime in `runtime.c` against the host
runtime contracts in:

- `src/include/lean/lean.h`
- `src/runtime/object.cpp`
- `src/runtime/apply.cpp`

The audit is about ABI shape, Lean ownership conventions (`obj_arg` versus
`b_obj_arg`), copy-on-write behavior, and whether consumed heap objects are
eventually reclaimable by the freestanding allocator.

## Summary

The old global leak policy is gone. The freestanding runtime now has one memory
policy: single-threaded Lean RC plus a reclaiming heap allocator over the
embedder-provided heap.

After this audit, the implemented owned-object paths that were checked have no
known systematic leak. The main new bug found during the audit was in closure
application: `lean_apply_*` consumed closures and arguments on the host, but the
freestanding implementation did not release consumed closure objects, did not
handle scalar erased functions, and only exported `lean_apply_1` through
`lean_apply_8`. That is fixed. A second ABI gap was found in constructor
reset/reuse support: generated reset code may call `lean_ctor_release`, but the
freestanding runtime did not export it. That is also fixed.

This is not yet a claim that the freestanding target supports the entire Lean
host runtime. Several host runtime families remain intentionally unsupported or
incomplete and must be covered by target policy deny-lists or implemented before
they can be considered safe for arbitrary Lean programs.

The kernel-facing runtime gaps found after the audit were also filled for the
small-runtime subset: panic shims, pointer-address support, hash mixing,
single-threaded `ST.Ref`, and bounded small-Int arithmetic. The Int support is
deliberately scalar-only; operations that would require MPZ-backed values trap
instead of allocating host big integers.

## Fixed During This Audit

### Closure application

Host contract:

- `lean_apply_1` through `lean_apply_16`, `lean_apply_n`, and `lean_apply_m`
  consume the function closure and the supplied arguments.
- If the function value is a scalar erased proof, all supplied arguments are
  decremented and the scalar is returned.
- Exact application of an exclusive closure transfers fixed arguments directly
  to the callee and frees the closure object itself.
- Exact application of a shared closure increments fixed arguments before the
  call and decrements the consumed closure reference.
- Partial application consumes the old closure and returns a new closure
  containing the old fixed fields plus the new owned arguments.

Freestanding status:

- `lean_apply_1` through `lean_apply_16` are now exported.
- `lean_apply_n` and `lean_apply_m` are now exported.
- Scalar erased-function application now decrements all supplied arguments.
- Partial application now consumes the old closure.
- Exact application now frees or decrements the consumed closure according to
  exclusivity.
- Arity 1 through 16 use direct C function signatures.
- Arity greater than 16 uses the host-style `void **` FNN convention.

Regression coverage:

- Exact closure application reclamation.
- Partial closure application reclamation.
- Shared fixed-field closure application reclamation.
- Scalar erased `apply_n` argument reclamation.
- Arity-9 `apply_n`.
- Arity-17 `apply_m` / FNN path.

### Constructor reset/reuse

Host contract:

- The reset/reuse optimization is gated by `lean_is_exclusive` /
  `lean_is_shared`; shared constructor cells must not be reused in place.
- The C and LLVM emitters lower reset fast paths to `lean_ctor_release` calls
  for released object fields.
- `lean_ctor_release` must decrement the released field and then overwrite that
  slot with `lean_box(0)`. Host `lean.h` documents this field clear as
  crucial: if a later control path fails to reuse the object and only deletes
  or decrements the old allocation, stale child pointers must not be decremented
  again.
- When a reset token is abandoned, generated code may use `lean_del_object`.
  That operation must free only the constructor cell, because released fields
  have already been dealt with by `lean_ctor_release`.

Freestanding status:

- `lean_is_exclusive` is backed by real RC metadata, so the compiler's reuse
  gate is meaningful.
- `lean_ctor_release` is now exported and matches the host invariant: decrement
  the field, then store `lean_box(0)` into the slot.
- `lean_del_object` frees only the object block and does not traverse child
  fields, which is the right behavior for the reset fast path after fields have
  been released.

Regression coverage:

- The host-side runtime harness now checks that `lean_ctor_release` clears the
  released field and that repeated release/delete cycles are reclaimable.

### Kernel-facing runtime gaps

Host contract:

- `panicCore` lowers to `lean_panic_fn` / `lean_panic_fn_borrowed`; these
  symbols must exist even when the target handles the actual abort path.
- `ptrAddrUnsafe` lowers to `lean_ptr_addr` and must return a stable address
  value for heap objects.
- `mixHash` lowers to `lean_uint64_mix_hash` and is used by hash-map based
  caches.
- `ST.Prim.Ref` lowers to `lean_st_mk_ref`, `lean_st_ref_get`,
  `lean_st_ref_set`, `lean_st_ref_take`, `lean_st_ref_swap`, and
  `lean_st_ref_ptr_eq`.
- Lean `Int` operations lower to `lean_int_*` helpers. Host Lean can allocate
  MPZ-backed Int values; freestanding currently supports only the scalar
  small-Int range.

Freestanding status:

- `lean_panic`, `lean_panic_fn`, `lean_panic_fn_borrowed`, and
  `lean_internal_panic_unreachable` route into `lean_freestanding_panic`.
- `lean_ptr_addr` returns the object pointer value cast to `size_t`.
- `lean_uint64_mix_hash` is implemented without host dependencies.
- Single-threaded `ST.Ref` cells are heap objects with normal RC traversal and
  persistence marking.
- Bounded Int constructors, arithmetic, comparisons, truncating division/mod,
  Euclidean division/mod, and `natAbs` are implemented for scalar Int values.
  Overflow, parse overflow, or Nat-to-Int conversion outside the scalar range
  traps through `lean_freestanding_panic`.

Regression coverage:

- Pointer-address and `mixHash` fixed-vector checks.
- `ST.Ref` get/set/take/swap/ptrEq plus reclamation.
- Bounded Int construction, arithmetic, comparisons, division/mod, and
  `natAbs`.

## Implemented Symbol Families Audited

### Allocator and RC

Audited symbols include:

- `lean_alloc_object`, `lean_free_object`
- `lean_alloc_small`, `lean_free_small`, `lean_small_mem_size`
- `lean_inc`, `lean_inc_ref`, `lean_inc_n`, `lean_inc_ref_n`
- `lean_dec`, `lean_dec_ref`, `lean_del_object`
- `lean_is_exclusive`, `lean_is_exclusive_obj`, `lean_is_shared`
- `lean_mark_persistent`

Status:

- RC metadata is maintained for heap objects.
- Persistent objects (`m_rc == 0`) are not freed, matching Lean's persistent
  object convention.
- `lean_dec` recursively releases children for ctors, arrays, and closures.
- Strings and scalar arrays have no object children and are freed directly.
- The allocator reuses freed blocks, coalesces neighbors, and can shrink the
  high-water cursor when the tail is free.

### Constructors and boxed scalars

Audited symbols include:

- `lean_alloc_ctor`
- `lean_ctor_get`, `lean_ctor_set`, `lean_ctor_release`
- `lean_ctor_set_tag`
- `lean_ctor_get_uint8`, `lean_ctor_get_uint16`, `lean_ctor_get_uint32`,
  `lean_ctor_get_uint64`
- `lean_ctor_set_uint8`, `lean_ctor_set_uint16`, `lean_ctor_set_uint32`,
  `lean_ctor_set_uint64`
- `lean_box`, `lean_unbox`
- `lean_box_uint32`, `lean_unbox_uint32`
- `lean_box_uint64`, `lean_unbox_uint64`
- `lean_box_usize`, `lean_unbox_usize`
- `lean_box_float`, `lean_unbox_float`

Status:

- Constructor object-field ownership is caller-controlled, as in `lean.h`.
- Constructor finalization decrements object fields according to `m_other`.
- `lean_ctor_release` decrements a field and clears it to `lean_box(0)`, which
  preserves reset/reuse fallback safety.
- Scalar fields are raw payload bytes and are not traversed by RC.

Freestanding policy deviation:

- `lean_box_uint32` and `lean_box_usize` use tagged scalar payloads with the
  freestanding small-Nat cap. On 32-bit host Lean, boxed `UInt32` uses a ctor
  for full-range values. Freestanding currently rejects values above the tagged
  scalar cap instead of implementing full boxed-UInt32 object layout.
- This must remain an explicit target policy. Programs needing full-range boxed
  `UInt32`/`USize` values require either a wider object representation or a
  compile-time/runtime rejection.

### Arrays

Audited symbols include:

- `lean_alloc_array`
- `lean_mk_array`
- `lean_mk_empty_array`
- `lean_mk_empty_array_with_capacity`
- `lean_array_size`, `lean_array_capacity`, `lean_array_get_size`
- `lean_array_uget`, `lean_array_uget_borrowed`
- `lean_array_fget`, `lean_array_fget_borrowed`
- `lean_array_get`, `lean_array_get_borrowed`
- `lean_copy_expand_array`, `lean_copy_expand_array_nonlinear`
- `lean_array_uset`, `lean_array_fset`, `lean_array_set`
- `lean_array_pop`
- `lean_array_uswap`, `lean_array_fswap`, `lean_array_swap`
- `lean_array_push`

Status:

- Shared arrays are copied before mutation.
- Exclusive arrays mutate in place when capacity permits.
- Copying a shared array increments copied element references and decrements
  the consumed source array reference.
- Copying an exclusive array transfers element ownership and frees only the
  source array object.
- Replaced elements and popped elements are decremented.

Behavior deviation:

- The host out-of-bounds `lean_array_set` path reports a panic and returns the
  default array. Freestanding currently drops the new value and returns the
  original array without emitting the host panic message. Ownership is correct;
  diagnostics are not host-identical.

### Scalar arrays, ByteArray, and FloatArray storage

Audited symbols include:

- `lean_alloc_sarray`
- `lean_copy_sarray`, `lean_sarray_ensure_capacity`
- `lean_sarray_size`, `lean_sarray_capacity`, `lean_sarray_dec_eq`
- `lean_mk_empty_byte_array`
- `lean_byte_array_mk`, `lean_byte_array_data`
- `lean_byte_array_size`
- `lean_byte_array_uget`, `lean_byte_array_fget`, `lean_byte_array_get`
- `lean_byte_array_uset`, `lean_byte_array_fset`, `lean_byte_array_set`
- `lean_byte_array_push`, `lean_copy_byte_array`
- `lean_byte_array_copy_slice`
- `lean_byte_array_hash`
- `lean_mk_empty_float_array`
- `lean_float_array_mk`, `lean_float_array_data`
- `lean_float_array_size`
- `lean_float_array_uget`, `lean_float_array_fget`, `lean_float_array_get`
- `lean_float_array_uset`, `lean_float_array_fset`, `lean_float_array_set`
- `lean_float_array_push`, `lean_copy_float_array`

Status:

- Shared scalar arrays are copied before mutation.
- Exclusive scalar arrays mutate in place.
- Copying consumes the source scalar array reference.
- ByteArray conversion to/from `Array UInt8` consumes the source container as on
  the host.
- FloatArray storage helpers follow the same scalar-array COW path.

Regression coverage:

- The host-side freestanding runtime harness checks FloatArray push aliasing,
  set! aliasing, and raw/boxed size ABI agreement.

### Strings

Audited symbols include:

- `lean_mk_string_unchecked`
- `lean_mk_string_from_bytes_unchecked`
- `lean_mk_string_from_bytes`
- `lean_mk_string`
- `lean_mk_ascii_string_unchecked`
- `lean_string_push`
- `lean_string_append`
- `lean_string_length`
- `lean_string_data`
- `lean_string_validate_utf8`
- `lean_string_from_utf8_unchecked`
- `lean_string_to_utf8`
- `lean_string_dec_eq`

Status:

- `lean_string_push` consumes `s`.
- `lean_string_append` consumes `s1` and borrows `s2`.
- `lean_string_data` consumes `s` via `lean_dec_ref`, matching the host.
- `lean_string_from_utf8_unchecked` consumes the input ByteArray.
- `lean_string_to_utf8` borrows the input String.
- Repeated string construction and consuming operations are covered by the
  reclamation harness.

Unsupported or missing host string surface:

- `lean_string_mk`
- `lean_decode_lossy_utf8`
- UTF-8 indexing/navigation/extract/set helpers:
  `lean_string_utf8_get`, `lean_string_utf8_get_fast_cold`,
  `lean_string_utf8_next`, `lean_string_utf8_next_fast_cold`,
  `lean_string_utf8_prev`, `lean_string_utf8_extract`,
  `lean_string_utf8_set`, `lean_string_is_valid_pos`, and related helpers.
- String ordering/hash/memcmp/of-usize helpers:
  `lean_string_lt`, `lean_string_hash`, `lean_string_memcmp`,
  `lean_string_of_usize`.
- Slice helpers: `lean_slice_hash`, `lean_slice_dec_lt`, and related slice
  accessors.

These must be implemented or compile-time denied before arbitrary String-heavy
programs are considered supported.

### Nat, UInt, and USize

Audited symbols include:

- `lean_unsigned_to_nat`
- `lean_uint8_to_nat`, `lean_uint16_to_nat`, `lean_uint32_to_nat`,
  `lean_uint64_to_nat`, `lean_usize_to_nat`
- `lean_uint8_of_nat`, `lean_uint16_of_nat`, `lean_uint32_of_nat`,
  `lean_uint64_of_nat`, `lean_usize_of_nat`
- `lean_nat_add`, `lean_nat_sub`, `lean_nat_mul`, `lean_nat_div`,
  `lean_nat_mod`, `lean_nat_shiftr`
- `lean_nat_dec_eq`, `lean_nat_dec_le`, `lean_nat_dec_lt`
- fixed-width UInt arithmetic/comparison/conversion helpers present in
  `runtime.c`

Status:

- Small tagged Nat values are supported.
- Big Nat / GMP-backed Nat values are not supported.
- Operations that would require a big Nat panic instead of allocating one.

Freestanding policy deviation:

- This is a bounded-Nat runtime. Host Lean can allocate big Nat values; this
  runtime intentionally cannot.
- The LLVM freestanding backend rejects executable Nat literals above the
  target small-Nat cap before bitcode emission. Runtime checks still trap
  arithmetic/conversion results that exceed the cap dynamically.

Missing or unsupported host arithmetic surface:

- Big Nat operations such as `lean_nat_big_*`, `lean_big_usize_to_nat`,
  `lean_big_uint64_to_nat`, `lean_nat_overflow_mul`.
- Additional Nat operations such as `lean_nat_shiftl`, bitwise Nat operations,
  `lean_nat_pow`, `lean_nat_gcd`, and exact division helpers.
- Full MPZ-backed Int support remains open work. The implemented `lean_int_*`
  subset is bounded to scalar small-Int values and traps when a result needs a
  big-Int allocation.

### IO wrappers

Audited symbols include:

- `lean_io_result_mk_ok`
- `lean_io_result_is_ok`, `lean_io_result_is_error`
- `lean_io_mk_world`
- `lean_io_mark_end_initialization`

Status:

- Basic IO result construction and inspection are present.
- Host IO subsystems are intentionally unsupported.

Unsupported host IO/task surface:

- Task/promise/thread APIs.
- Host filesystem, process, stdin, environment, and real-time APIs.
- External/ref/thunk APIs.

The default freestanding deny-list now fail-closes these host runtime families
at Lean codegen time. The policy validates declaration names when registering
entries, so stale names do not silently become dead policy.

## Missing Host Runtime Families Requiring Policy

The following host runtime families are not part of the current freestanding
runtime. They must be either implemented or rejected by target policy before
the runtime can claim arbitrary Lean compatibility:

- Thunks: `lean_mk_thunk`, `lean_thunk_get_core`, and related helpers.
- Tasks/promises/threading: `lean_task_*`, `lean_io_promise_*`,
  `lean_io_wait_any_core`, cancellation and task-state APIs.
- External objects: `lean_alloc_external`, `lean_register_external_class`, and
  related finalizer machinery.
- MPZ/big Nat/big Int: `lean_alloc_mpz`, `lean_nat_big_*`, and big-Int paths
  beyond the scalar `lean_int_*` subset.
- Full Float/Float32 runtime: string conversion, frexp/scaleb, bit conversion,
  Float32 boxing/unboxing and conversions.
- Full String/Slice runtime listed above.
- Debug helpers and full panic diagnostics: `lean_dbg_trace`,
  `lean_dbg_sleep`, `lean_dbg_stack_trace`, and host-style panic message
  formatting.
- Object introspection helpers: `lean_object_byte_size`,
  `lean_object_data_byte_size`, and several inline host helpers not exported by
  freestanding.
- Name hashing/equality helpers beyond the currently needed subset.

## Verification

Local verification after the audit:

- `clang -std=c11 -Wall -Wextra -Wimplicit-fallthrough -fsyntax-only
  src/runtime/freestanding/runtime.c`
- `tests/freestanding_runtime/run_test.sh`
- `tests/cross_target/run_test.sh`
- `tests/freestanding_sync/run_test.sh`
- `git diff --check`

The freestanding runtime harness currently covers 25 probes:

- Array COW aliasing.
- ByteArray COW aliasing.
- FloatArray COW aliasing and size ABI.
- Exclusivity contract.
- Exclusive in-place Array push.
- Constructor reset/reuse helper field clearing.
- Repeated reclamation for arrays, ctors, strings, closures.
- Consuming string extern reclamation.
- Exact, partial, shared-fixed, scalar-erased, arity-9, and arity-17 closure
  application reclamation.
- Live-byte return after temporary allocations.
- Pointer-address and `mixHash` helpers.
- Single-threaded `ST.Ref` operations and reclamation.
- Bounded Int arithmetic and comparison helpers.

## Remaining Required Work

1. Add target-level Lean probes for Solana/WASM/kernel, not only the host C
   harness.
2. Keep the unsupported-on-target deny-list synchronized with this audit as the
   freestanding runtime grows or target runtimes add supported families.
3. Decide whether bounded boxed `UInt32`/`USize` is an acceptable permanent
   freestanding policy; if yes, document and enforce it at compile time.
4. Implement or deny the missing String/Slice helpers.
5. Implement or deny the full MPZ-backed Nat/Int surface.
6. Keep the `lean4` and `lean4-freestanding` runtime copies synchronized.
