/-! Probe: copy-on-write semantics for shared arrays. Reading the original
after a `set!` forces codegen to emit a copy via `lean_copy_expand_array`
or `lean_array_uset`'s non-exclusive branch. The point of this probe is
that mutating one alias must not be visible through another. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let arr0 : Array UInt64 := #[10, 20, 30, 40]
  let arr1 := arr0.set! 0 999
  let arr2 := arr0.set! 3 888
  -- Re-read arr0 after both mutations to force COW on each.
  let a0_first := arr0[0]!
  let a0_last  := arr0[3]!
  let a1_first := arr1[0]!
  let a1_last  := arr1[3]!
  let a2_first := arr2[0]!
  let a2_last  := arr2[3]!
  let ok :=
    a0_first == 10  && a0_last == 40 &&
    a1_first == 999 && a1_last == 40 &&
    a2_first == 10  && a2_last == 888
  if ok then 0 else 99
