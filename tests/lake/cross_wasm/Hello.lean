import Std.Wasm

/-! Minimal WASI program exercising the `wasm_program` build path.

    Mirrors `tests/wasm/HeapStress.lean`'s entry shape (`lean_wasm_main` with
    a `UInt64 -> UInt64` signature) so the same `lake build` pipeline that
    serves real programs is exercised end-to-end here. -/

@[export lean_wasm_main]
def entry (x : UInt64) : UInt64 :=
  x ^^^ 0x77
