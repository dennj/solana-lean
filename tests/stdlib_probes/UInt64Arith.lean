/-! Probe: UInt64 arithmetic, bit ops, shifts, and comparisons. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt64 := 5
  let b : UInt64 := 3
  let c : UInt64 := 0xFF
  let d : UInt64 := 0x0F
  let one : UInt64 := 1
  let n : UInt64 := 256
  let ok :=
    (a + b == 8) &&
    (10 - 4 == (6 : UInt64)) &&
    (a * b == 15) &&
    (c ^^^ d == 0xF0) &&
    (0xF0 ||| d == 0xFF) &&
    (c &&& d == 0x0F) &&
    (one <<< 8 == n) &&
    (n >>> 4 == 16) &&
    (b < a) &&
    (a <= a)
  if ok then 0 else 99
