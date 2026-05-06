/-! Probe: Nat right-shift (`>>>` / `Nat.shiftRight`). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : Nat := 0x80200
  let b : Nat := 1
  let big : Nat := 0x3FFFFFFF
  let zeroN : Nat := 0
  let ok :=
    (a >>> 0 == 0x80200) &&
    (a >>> 9 == 0x401) &&
    (a >>> 12 == 0x80) &&
    (a >>> 18 == 2) &&
    (a >>> 32 == 0) &&
    (b >>> 1 == 0) &&
    (zeroN >>> 5 == 0) &&
    (big >>> 4 == 0x3FFFFFF) &&
    (big >>> 30 == 0)
  if ok then 0 else 99
