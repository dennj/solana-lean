/-! Probe: UInt8 arithmetic and comparisons (i8 ABI). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt8 := 10
  let b : UInt8 := 7
  let c : UInt8 := 0xFF
  let ok :=
    (a + b == 17) &&
    (a - b == 3) &&
    (a == a) &&
    (b < a) &&
    (a <= a) &&
    (c == 255)
  if ok then 0 else 99
