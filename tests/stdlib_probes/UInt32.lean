/-! Probe: UInt32 arithmetic and comparisons (i32 ABI). -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt32 := 1000000
  let b : UInt32 := 7
  let ok :=
    (a + b == 1000007) &&
    (a - b == 999993) &&
    (a * b == 7000000) &&
    (b < a) &&
    (a == a)
  if ok then 0 else 99
